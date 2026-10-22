import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;

import 'session_store.dart';

import 'package:http_parser/http_parser.dart';

class DocumentFile {
  final String name;
  final Uint8List bytes;
  final String mimeType;
  const DocumentFile(this.name, this.bytes, this.mimeType);
}

class ApiException implements Exception {
  final String message;
  final int? status;
  final String? code;
  const ApiException(this.message, [this.status, this.code]);
  @override
  String toString() => message;
}

/// Existing production contract: root routes, JSON envelopes, bearer access
/// tokens, and refresh cookies with double-submit CSRF protection.
class ApiService {
  static const productionBaseUrl =
      'https://infurnus-api-675633214574.asia-south2.run.app';
  // Isolated physical-device testing can override only debug builds.
  static const baseUrl = kDebugMode
      ? String.fromEnvironment(
          'DRIVER_TEST_API_BASE_URL',
          defaultValue: productionBaseUrl,
        )
      : productionBaseUrl;
  final http.Client _client;
  final SessionStore _store;
  Future<void> _storeWrites = Future.value();
  bool get roleFlowEnabled => _productionClient;
  final bool _productionClient;
  String role = 'driver';
  String providerMode = 'driver';
  bool get hasDriverRole => ['driver', 'driver_fleet_owner'].contains(role);
  bool get hasFleetRole => ['fleet_owner', 'driver_fleet_owner'].contains(role);
  bool get isAdmin => ['admin', 'super_admin'].contains(role);
  final Map<String, String> _cookies = {};
  String? accessToken;
  bool isTestOnboarding = false;
  String? _csrfToken;
  String? userId;
  Future<void>? _refreshing;
  ApiService({http.Client? client, SessionStore? store})
    : _productionClient = client == null,
      _client = client ?? http.Client(),
      _store =
          store ??
          (client == null ? SecureSessionStore() : MemorySessionStore());

  Future<void> _saveSession() {
    final value = accessToken == null
        ? null
        : jsonEncode({
            'accessToken': accessToken,
            'csrfToken': _csrfToken,
            'userId': userId,
            'cookies': _cookies,
            'role': role,
            'providerMode': providerMode,
          });
    // Serialize deletion and rotation so an older write cannot restore logout.
    _storeWrites = _storeWrites
        .catchError((_) {})
        .then((_) => _store.write(value));
    return _storeWrites;
  }

  Future<bool> restoreSession() async {
    final saved = await _store.read();
    if (saved == null) return false;
    try {
      final data = jsonDecode(saved) as Map<String, dynamic>;
      accessToken = data['accessToken'] as String;
      _csrfToken = data['csrfToken'] as String?;
      userId = data['userId'] as String;
      role = data['role'] as String;
      providerMode = data['providerMode'] as String? ?? 'driver';
      _cookies.addAll(Map<String, String>.from(data['cookies'] as Map));
      // Cached role/profile never authorizes access: revalidate the server session.
      await refreshSession();
      return true;
    } on FormatException {
      clearSession();
      await _storeWrites;
      return false;
    } on TypeError {
      clearSession();
      await _storeWrites;
      return false;
    }
  }

  void clearSession({bool persist = true}) {
    isTestOnboarding = false;
    accessToken = null;
    userId = null;
    _csrfToken = null;
    _cookies.clear();
    role = 'driver';
    providerMode = 'driver';
    if (persist) unawaited(_saveSession().catchError((_) {}));
  }

  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool retry = true,
    List<DocumentFile>? files,
    Map<String, String>? fields,
    String fileField = 'file',
  }) async {
    final requestPath =
        isTestOnboarding && !path.startsWith('/driver-test-onboarding/')
        ? '/driver-test-onboarding$path'
        : path;
    final http.BaseRequest request;
    if (files != null) {
      final multipart = http.MultipartRequest(
        method,
        Uri.parse('$baseUrl$requestPath'),
      );
      multipart.fields.addAll(fields ?? {});
      for (final file in files) {
        multipart.files.add(
          http.MultipartFile.fromBytes(
            fileField,
            file.bytes,
            filename: file.name,
            contentType: MediaType.parse(file.mimeType),
          ),
        );
      }
      request = multipart;
    } else {
      final jsonRequest = http.Request(
        method,
        Uri.parse('$baseUrl$requestPath'),
      );
      if (body != null) jsonRequest.body = jsonEncode(body);
      request = jsonRequest;
    }
    request.headers.addAll({
      'Accept': 'application/json',
      'Content-Type': ?(files == null ? 'application/json' : null),
      'X-Provider-Mode': providerMode,
      'Authorization': ?(accessToken == null ? null : 'Bearer $accessToken'),
      'X-CSRF-Token': ?_csrfToken,
      if (_cookies.isNotEmpty)
        'Cookie': _cookies.entries.map((e) => '${e.key}=${e.value}').join('; '),
    });
    http.Response response;
    try {
      response = await (() async => http.Response.fromStream(
        await _client.send(request),
      ))().timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw const ApiException('The server timed out. Please retry.');
    } on http.ClientException {
      throw const ApiException(
        'Unable to connect. Check your internet connection.',
      );
    }
    final cookieHeader = response.headers['set-cookie'];
    if (cookieHeader != null) {
      for (final cookie in cookieHeader.split(RegExp(r',(?=\s*[^;,=\s]+=)'))) {
        final pair = cookie.split(';').first.trim();
        final split = pair.indexOf('=');
        if (split > 0) {
          _cookies[pair.substring(0, split)] = pair.substring(split + 1);
        }
      }
      _csrfToken = _cookies['infurnus_csrf_token'] ?? _csrfToken;
    }
    if (response.statusCode == 401 &&
        !isTestOnboarding &&
        retry &&
        accessToken != null &&
        !path.startsWith('/auth/')) {
      try {
        await (_refreshing ??= _refresh());
      } finally {
        _refreshing = null;
      }
      return this.request(
        method,
        path,
        body: body,
        retry: false,
        files: files,
        fields: fields,
        fileField: fileField,
      );
    }
    Map<String, dynamic>? envelope;
    try {
      if (response.body.isNotEmpty) {
        envelope = jsonDecode(response.body) as Map<String, dynamic>;
      }
    } on FormatException {
      throw ApiException(
        'The server returned an invalid response.',
        response.statusCode,
      );
    } on TypeError {
      throw ApiException(
        'The server returned an invalid response.',
        response.statusCode,
      );
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        envelope?['success'] == false) {
      final error = envelope?['error'];
      if (isTestOnboarding &&
          response.statusCode == 404 &&
          error is Map &&
          error['code'] == 'NOT_FOUND') {
        clearSession();
      }
      final invalidLinkIdentity =
          path == '/auth/google/link' &&
          error is Map &&
          error['code'] == 'INVALID_GOOGLE_TOKEN';
      if (response.statusCode == 401 &&
          accessToken != null &&
          !invalidLinkIdentity) {
        clearSession();
      }
      throw ApiException(
        error is Map
            ? error['message']?.toString() ?? 'Request failed.'
            : 'Request failed (${response.statusCode}).',
        response.statusCode,
        error is Map ? error['code']?.toString() : null,
      );
    }
    if (response.statusCode == 204) return null;
    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        envelope?['success'] == true &&
        !envelope!.containsKey('data') &&
        (RegExp(r'^/fleet/vehicles/[^/]+/unassign$').hasMatch(path) ||
            (method == 'DELETE' &&
                RegExp(r'^/fleet/vehicles/[^/]+$').hasMatch(path)))) {
      return null;
    }
    if (path == '/auth/google/link' &&
        envelope?['success'] == true &&
        !envelope!.containsKey('data')) {
      return null;
    }
    if (envelope?['success'] != true || !envelope!.containsKey('data')) {
      throw const ApiException(
        'The server response does not match the API contract.',
      );
    }
    if (method == 'GET' && Uri.parse(path).path == '/driver-applications') {
      final items = envelope['data'];
      final pagination = envelope['pagination'];
      final total = pagination is Map ? pagination['total'] : null;
      if (items is! List ||
          total is! num ||
          total < 0 ||
          total != total.toInt()) {
        throw const ApiException(
          'The application list does not match the API contract.',
        );
      }
      return {'items': items, 'total': total.toInt()};
    }
    return envelope['data'];
  }

  Future<dynamic> requestAgain(
    String method,
    String path,
    Map<String, dynamic>? body,
  ) => request(method, path, body: body, retry: false);

  Future<bool> testOnboardingAvailable() async {
    if (!kDebugMode ||
        !const bool.fromEnvironment('DRIVER_TEST_ONBOARDING_ENABLED')) {
      return false;
    }
    try {
      final data = await request('GET', '/driver-test-onboarding/capabilities');
      return data is Map && data['enabled'] == true;
    } on ApiException {
      return false;
    }
  }

  Future<void> startTestOnboarding() async {
    clearSession();
    final data = await request(
      'POST',
      '/driver-test-onboarding/sessions',
      body: {},
    );
    accessToken = data['sessionToken'] as String;
    userId = data['userId'] as String;
    isTestOnboarding = true;
    // Deliberately memory-only: no login credentials, cookies, refresh or stored session.
  }

  // This protected endpoint checks the current database role and active status.
  // /users/:id is a profile projection and deliberately has neither field.
  Future<void> validateProviderAccount([
    Map<String, dynamic>? enrolment,
  ]) async {
    if (isAdmin) {
      // Preserve the separate existing reviewer session contract.
      final account = await request(
        'GET',
        '/users/${Uri.encodeComponent(userId!)}',
      );
      if (account['role'] != role || account['status'] != 'active') {
        throw const ApiException(
          'This account is not authorized.',
          403,
          'FORBIDDEN',
        );
      }
      return;
    }
    final state =
        enrolment ??
        Map<String, dynamic>.from(
          await request('GET', '/provider/enrolment') as Map,
        );
    if (state['role'] != role) {
      throw const ApiException(
        'This account is not authorized.',
        403,
        'FORBIDDEN',
      );
    }
  }

  Future<void> _refresh() async {
    try {
      final data = await request('POST', '/auth/refresh', retry: false);
      accessToken = data['accessToken'] as String;
      _csrfToken = data['csrfToken'] as String? ?? _csrfToken;
      await _saveSession();
    } on ApiException catch (e) {
      if (e.status == 401 || e.status == 403) clearSession();
      rethrow;
    }
  }

  Future<String> login(
    String identifier, [
    String password = '',
    String? accountRole,
  ]) async {
    clearSession();
    identifier = identifier.trim();
    if (identifier.isEmpty) {
      throw const ApiException('Enter your mobile number or email address.');
    }
    String? email;
    String? phone;
    if (identifier.contains('@')) {
      email = identifier;
      if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
        throw const ApiException('Enter a valid email address.');
      }
    } else {
      final digits = identifier.replaceAll(RegExp(r'[^\d+]'), '');
      if (digits.startsWith('+')) {
        phone = digits;
      } else if (digits.length == 10) {
        phone = '+91$digits';
      } else if (digits.length > 10 &&
          digits.startsWith('91') &&
          digits.length == 12) {
        phone = '+$digits';
      } else {
        phone = digits;
      }
      if (!RegExp(r'^\+?[1-9]\d{7,14}$').hasMatch(phone)) {
        throw const ApiException(
          'Enter a valid mobile number or email address.',
        );
      }
    }
    final data = await request(
      'POST',
      '/auth/login',
      body: {
        'email': ?email,
        'phone': ?phone,
        if (password.isNotEmpty) 'password': password,
        'role': ?accountRole,
      },
    );
    return data['challengeId'] as String;
  }

  Future<String> resendLogin(String challengeId) async {
    final data = await request(
      'POST',
      '/auth/login/resend',
      body: {'challengeId': challengeId},
    );
    return data['challengeId'] as String;
  }

  Future<Map<String, dynamic>> verifyLogin(
    String challengeId,
    String otp,
  ) async {
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      throw const ApiException('Enter the six-digit verification code.');
    }
    final data = await request(
      'POST',
      '/auth/login/verify',
      body: {'challengeId': challengeId, 'otp': otp},
    );
    return _acceptAuthentication(data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> _acceptAuthentication(
    Map<String, dynamic> data,
  ) async {
    final token = data['accessToken'];
    if (token is! String || token.isEmpty) {
      throw const ApiException(
        'Authentication did not return an access token.',
      );
    }
    accessToken = token;
    _csrfToken = data['csrfToken'] as String? ?? _csrfToken;
    userId = data['userId'] as String?;
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        final claims = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
        ) as Map;
        role = claims['role'] as String? ?? 'driver';
      }
    } on FormatException {
      clearSession();
      throw const ApiException('Invalid authentication response.');
    } on TypeError {
      clearSession();
      throw const ApiException('Invalid authentication response.');
    }
    if (!hasDriverRole && !hasFleetRole && !isAdmin) {
      clearSession();
      throw const ApiException(
        'A Driver or Fleet account is required.',
        403,
        'FORBIDDEN',
      );
    }
    providerMode = hasFleetRole ? 'fleet_owner' : 'driver';
    if (role == 'driver_fleet_owner' &&
        userId != null &&
        _store is ProviderModeStore) {
      final savedMode = await (_store as ProviderModeStore).readMode(userId!);
      if (savedMode == 'driver' || savedMode == 'fleet_owner') {
        providerMode = savedMode!;
      }
    }
    _csrfToken = data['csrfToken'] as String? ?? _csrfToken;
    try {
      if (!hasDriverRole || providerMode == 'fleet_owner') {
        await validateProviderAccount();
        await _saveSession();
        return {};
      }
      final profile = await fetchDriverProfile();
      await _saveSession();
      // A specific DRIVER_PROFILE_NOT_FOUND response comes after the driver's
      // server-side role guard, so an authenticated driver can complete onboarding.
      if (profile == null) return {};
      return profile;
    } catch (_) {
      try {
        await logout();
      } catch (_) {
        clearSession();
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      if (_cookies.isNotEmpty) {
        await request('POST', '/auth/logout', retry: false);
      }
    } finally {
      clearSession();
      await _storeWrites;
    }
  }

  void dispose() => _client.close();

  Future<void> setProviderMode(String mode) async {
    if ((mode == 'driver' && hasDriverRole) ||
        (mode == 'fleet_owner' && hasFleetRole)) {
      providerMode = mode;
      if (userId != null && _store is ProviderModeStore) {
        await (_store as ProviderModeStore).writeMode(userId!, mode);
      }
      await _saveSession();
      return;
    }
    throw const ApiException('This account does not support that mode.', 403);
  }

  Future<void> refreshSession() => _refresh();
  Future<void> selectInitialRole(String selected) async {
    final data = await request(
      'POST',
      '/provider/enrolment/role',
      body: {'role': selected},
    );
    accessToken = data['accessToken'] as String;
    role = data['role'] as String;
    providerMode = hasFleetRole ? 'fleet_owner' : 'driver';
    await _saveSession();
  }

  Future<Map<String, dynamic>> authenticateGoogle(
    String idToken, {
    bool signup = false,
    String? providerRole,
    String? accountRole,
  }) async {
    if (idToken.isEmpty || idToken.length > 16384) {
      throw const ApiException('Google did not return a valid ID token.');
    }
    if (providerRole != null &&
        (!signup ||
            ![
              'driver',
              'fleet_owner',
              'driver_fleet_owner',
            ].contains(providerRole))) {
      throw const ApiException('Choose a supported provider role for signup.');
    }
    clearSession();
    final data = await request(
      'POST',
      '/auth/google',
      body: {
        'idToken': idToken,
        'driverFlow': signup ? 'signup' : 'signin',
        'providerRole': ?providerRole,
        'accountRole': ?accountRole,
      },
    );
    return _acceptAuthentication(Map<String, dynamic>.from(data as Map));
  }

  Future<void> linkGoogle(String idToken) async {
    if (accessToken == null) {
      throw const ApiException(
        'Sign in to your existing Driver account before linking Google.',
      );
    }
    if (idToken.isEmpty || idToken.length > 16384) {
      throw const ApiException('Google did not return a valid ID token.');
    }
    await request('POST', '/auth/google/link', body: {'idToken': idToken});
  }

  Future<Map<String, dynamic>?> fetchDriverProfile() async {
    try {
      final data = await request('GET', '/rides/driver/profile');
      if (data is! Map<String, dynamic>) {
        throw const ApiException('Invalid driver profile response.');
      }
      return data;
    } on ApiException catch (e) {
      if (e.status == 404 && e.code == 'DRIVER_PROFILE_NOT_FOUND') return null;
      rethrow;
    }
  }

  Future<String> signup(Map<String, dynamic> input) async {
    if (![
      'driver',
      'fleet_owner',
      'driver_fleet_owner',
    ].contains(input['role'] ?? 'driver')) {
      throw const ApiException(
        'Select a supported Driver/Fleet role.',
        403,
        'FORBIDDEN',
      );
    }
    clearSession();
    const keys = [
      'firstName',
      'lastName',
      'email',
      'phone',
      'password',
      'confirmPassword',
      'licenseNumber',
      'licenseExpiry',
      'businessName',
      'onboardingLicencePending',
    ];
    final data = await request(
      'POST',
      '/auth/signup',
      body: {
        for (final key in keys)
          if (input.containsKey(key)) key: input[key],
        'role': input['role'] ?? 'driver',
      },
    );
    return data['signupId'] as String;
  }

  Future<String> resendSignup(String signupId) async {
    final data = await request(
      'POST',
      '/auth/signup/resend',
      body: {'signupId': signupId},
    );
    return data['signupId'] as String;
  }

  Future<Map<String, dynamic>> verifySignup(String signupId, String otp) async {
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      throw const ApiException('Enter the six-digit verification code.');
    }
    final data = await request(
      'POST',
      '/auth/signup/verify',
      body: {'signupId': signupId, 'otp': otp},
    );
    return _acceptAuthentication(data as Map<String, dynamic>);
  }

  Future<dynamic> uploadDriverDocument(
    String type,
    List<DocumentFile> files,
    Map<String, String> metadata,
  ) {
    final bundle = files.length > 1;
    return request(
      'POST',
      '/rides/driver/documents/${Uri.encodeComponent(type)}${bundle ? '/pages' : ''}',
      files: files,
      fields: metadata,
      fileField: bundle ? 'files' : 'file',
    );
  }
}
