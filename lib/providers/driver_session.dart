import 'dart:async';
import 'dart:convert';

import '../services/session_store.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show EditableText, FocusManager;
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../models/onboarding_rules.dart';
import '../models/provider_status.dart';

class DriverSession extends ChangeNotifier {
  final ApiService api;
  final SessionStore _onboardingDraftStore;
  DriverSession({ApiService? api, SessionStore? onboardingDraftStore})
    : api = api ?? ApiService(),
      _onboardingDraftStore =
          onboardingDraftStore ?? SecureOnboardingDraftStore();
  Map<String, dynamic>? profile;
  Map<String, dynamic>? currentTrip;
  Map<String, dynamic>? assignedVehicle;
  Map<String, dynamic>? history;
  int historyLimit = 20;
  List<Map<String, dynamic>> rides = [];
  Position? position;
  String? challengeId;
  String? signupId;
  bool isPreview = false;
  bool restoring = false;
  bool restorationNeedsRetry = false;

  void enablePreview() {
    if (!kReleaseMode) {
      isPreview = true;
      api.accessToken = 'preview-debug-token';
      api.role = 'driver';
      api.userId = 'preview-driver-id';
      onboardingLoaded = true;
      profile ??= {
        'id': 'preview-driver-id',
        'firstName': 'Rajesh',
        'lastName': 'Kumar',
        'verificationStatus': 'APPROVED',
        'availabilityStatus': 'available',
        'licenseExpiry': '2030-12-31',
      };
      account ??= {
        'firstName': 'Rajesh',
        'lastName': 'Kumar',
        'phone': '+919876543210',
      };
      assignedVehicle ??= {
        'id': 'preview-vehicle-id',
        'plateNumber': 'BR 01 EV 9988',
        'make': 'Tata',
        'model': 'Ace EV',
        'category': 'THREE_WHEELER',
      };
      history ??= {'totalTrips': 14, 'totalEarnings': 3280};
      if (rides.isEmpty) {
        rides = [
          {
            'id': 'PREVIEW-RIDE-101',
            'pickupAddress': 'Boring Road, Patna',
            'destinationAddress': 'Patna Junction',
            'status': 'requested',
            'vehicleCategory': 'Tata Ace EV',
            'fareEstimate': 280,
          },
          {
            'id': 'PREVIEW-RIDE-102',
            'pickupAddress': 'Kankarbagh, Patna',
            'destinationAddress': 'AIIMS Patna',
            'status': 'requested',
            'vehicleCategory': 'Tata Ace EV',
            'fareEstimate': 450,
          },
        ];
      }
      _notify();
    }
  }

  void disablePreview() {
    isPreview = false;
    _pollFailures = 0;
    refreshWarning = null;
    _notify();
  }

  String? refreshWarning;
  int _pollFailures = 0;
  Map<String, dynamic>? account;
  Map<String, dynamic>? assignmentPreview;
  List<Map<String, dynamic>> documents = [];
  List<Map<String, dynamic>> partnerDocuments = [];
  Map<String, dynamic>? requirementDocument(String code) {
    final driverDocument = OnboardingRules.documentFor(code, documents);
    final candidates = <Map<String, dynamic>>[
      ?driverDocument,
      for (final doc in partnerDocuments)
        if ((doc['vehicleId'] == null ||
                doc['vehicleId'] == assignedVehicle?['id']) &&
            ((doc['metadata'] as Map?)?['documentCode'] ??
                    doc['documentType'].toString().toLowerCase()) ==
                code)
          {
            ...doc,
            'verificationStatus': doc['status'],
            'documentMetadata': {
              ...?(doc['metadata'] as Map?),
              if (doc['expiresAt'] != null) 'expiresAt': doc['expiresAt'],
            },
          },
    ];
    for (final doc in candidates) {
      if (providerStatus(doc['verificationStatus']) ==
              ProviderStatus.approved &&
          !OnboardingRules.expired(doc)) {
        return doc;
      }
    }
    return candidates.isEmpty ? null : candidates.first;
  }

  List<Map<String, dynamic>> approvals = [];
  List<Map<String, dynamic>> applications = [];
  List<DocumentRule> documentRules = [];
  final Map<String, int> documentPages = {};
  bool _accountVerified = false;
  Map<String, dynamic>? roleEnrolment;
  bool onboardingLoaded = false;
  String? error;
  String? errorCode;
  String realtimeStatus = 'Disconnected';
  DateTime? lastLocationSent;
  bool busy = false;
  bool _disposed = false;
  bool _sendingLocation = false;
  StreamSubscription<Position>? _positions;
  io.Socket? _socket;
  Timer? _poll;
  Timer? _expiry;
  DriverNotificationService? _notifications;
  String? pendingNotificationRoute;
  bool get authenticated => _accountVerified && api.accessToken != null;
  List<DocumentRule> get missingUploads => documentRules.where((rule) {
    if (!rule.required) return false;
    final doc = requirementDocument(rule.code);
    return doc == null ||
        OnboardingRules.expired(doc) ||
        (rule.requiresExpiry &&
            (doc['documentMetadata'] as Map?)?['expiresAt'] == null) ||
        (documentPages[doc['id']] ??
                ((doc['metadata'] as Map?)?['pages'] as List?)?.length ??
                1) <
            rule.minimumPages;
  }).toList();
  Map<String, dynamic>? onboardingReceipt;
  final Map<String, Object> onboardingDrafts = {};
  final Set<String> _localDeferrals = {};
  Future<void> _readLocalDeferrals() async {
    _localDeferrals.clear();
    try {
      final saved =
          jsonDecode(await _onboardingDraftStore.read() ?? '{}') as Map;
      _localDeferrals.addAll((saved[api.userId] as List? ?? []).cast<String>());
    } catch (_) {
      /* Optional drafts must not prevent authentication. */
    }
  }

  Future<void> _saveLocalDeferrals(Set<String> next) async {
    final user = api.userId;
    if (user == null) {
      throw const ApiException('Sign in before saving onboarding progress.');
    }
    final saved = jsonDecode(await _onboardingDraftStore.read() ?? '{}') as Map;
    saved[user] = next.toList();
    await _onboardingDraftStore.write(jsonEncode(saved));
    _localDeferrals
      ..clear()
      ..addAll(next);
  }

  Future<bool> resumeStep(String code) => run(() async {
    if (_localDeferrals.contains(code)) {
      await _saveLocalDeferrals({..._localDeferrals}..remove(code));
      return;
    }
    onboardingReceipt = Map<String, dynamic>.from(
      await api.request('PATCH', '/provider/onboarding', body: {'resume': code})
          as Map,
    );
  });
  Set<String> get deferredSteps => {
    ...((onboardingReceipt?['deferred_codes'] as List?) ?? const [])
        .cast<String>(),
    ..._localDeferrals.where(canDefer),
  };
  bool canDefer(String code) =>
      code != 'driver_license' &&
      (['vehicle', 'fleet'].contains(code) ||
          (code == 'profile_photo' &&
              !documentRules.any((r) => r.code == code)) ||
          (documentRules.any((r) => r.code == code) &&
              documentRules
                  .where((r) => r.code == code)
                  .every((r) => r.onboardingDeferrable)));
  Future<bool> deferStep(String code) => run(() async {
    if (!canDefer(code)) {
      throw const ApiException('This required step cannot be skipped.');
    }
    try {
      onboardingReceipt = Map<String, dynamic>.from(
        await api.request(
          'PATCH',
          '/provider/onboarding',
          body: {'defer': code},
        ) as Map,
      );
    } on ApiException catch (e) {
      if (e.status != 404) rethrow;
      await _saveLocalDeferrals({..._localDeferrals, code});
    }
  });
  bool get dashboardAllowed =>
      (authenticated && api.hasDriverRole && currentTrip != null) ||
      (roleEnrolment?['dashboardAccessible'] == true &&
          api.hasDriverRole &&
          api.providerMode == 'driver') ||
      operationalAllowed ||
      (authenticated &&
          onboardingLoaded &&
          api.hasDriverRole &&
          api.providerMode == 'driver' &&
          onboardingReceipt?['dashboardAccessible'] == true);
  bool get operationalAllowed {
    if (roleEnrolment != null &&
        roleEnrolment?['dashboardAccessible'] != true) {
      return false;
    }
    if (api.isTestOnboarding) return false;
    if (isPreview) return true;
    if (!api.hasDriverRole ||
        api.providerMode != 'driver' ||
        !authenticated ||
        !onboardingLoaded ||
        providerStatus(profile?['verificationStatus']) !=
            ProviderStatus.approved) {
      return false;
    }
    final expiry = profile?['licenseExpiry'] as String?;
    if (expiry == null ||
        !OnboardingRules.validDate(expiry) ||
        DateTime.parse('${expiry}T00:00:00Z')
            .isBefore(DateTime.parse('${OnboardingRules.today()}T00:00:00Z'))) {
      return false;
    }
    if (missingUploads.isNotEmpty) return false;
    for (final rule in documentRules.where((r) => r.required)) {
      if (providerStatus(
            requirementDocument(rule.code)?['verificationStatus'],
          ) !=
          ProviderStatus.approved) {
        return false;
      }
    }
    if (applications.isNotEmpty &&
        !['APPROVED', 'CANCELLED'].contains(applications.first['status'])) {
      return false;
    }
    return true;
  }

  String get landingPath {
    if (api.isTestOnboarding && authenticated) return '/onboarding';
    if (isPreview) return '/driver/dashboard';
    if (!authenticated) return '/login';
    if (api.isAdmin) return '/admin/dashboard';
    if (currentTrip != null &&
        roleEnrolment != null &&
        roleEnrolment?['dashboardAccessible'] != true) {
      return '/driver/active-trip';
    }
    if (roleEnrolment?['roleSelectionPending'] == true) {
      return '/role-selection';
    }
    if (roleEnrolment != null &&
        roleEnrolment?['dashboardAccessible'] != true) {
      return '/role-onboarding';
    }
    if (api.hasFleetRole && api.providerMode == 'fleet_owner') {
      return '/fleet/dashboard';
    }
    if (dashboardAllowed) return '/driver/dashboard';
    if (!onboardingLoaded || profile == null || missingUploads.isNotEmpty) {
      return '/onboarding';
    }
    return '/verification-status';
  }

  bool get online => profile?['availabilityStatus'] == 'available';

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<bool> run(Future<void> Function() action) async {
    if (busy) return false;
    busy = true;
    error = null;
    errorCode = null;
    _notify();
    try {
      await action();
      return true;
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint(
          'Driver action failed: ${e.runtimeType}${e is ApiException ? ' status=${e.status} code=${e.code}' : ''}',
        );
        if (e is TypeError) debugPrint('Driver type failure: $e');
        debugPrintStack(stackTrace: stack, maxFrames: 6);
      }
      errorCode = e is ApiException ? e.code : null;
      error = e is ApiException
          ? e.message
          : 'Unable to complete the action. Please retry.';
      if (api.accessToken == null && _accountVerified) _clear();
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> login(
    String identifier,
    String password, {
    String? accountRole,
  }) => run(() async {
    if (identifier.trim().isEmpty) {
      throw const ApiException('Enter your mobile number or email address.');
    }
    challengeId = null;
    signupId = null;
    challengeId = await api.login(identifier, password, accountRole);
  });

  Future<bool> signup(Map<String, dynamic> input) => run(() async {
    final validation = OnboardingRules.validateSignup(input);
    if (validation != null) throw ApiException(validation);
    signupId = null;
    challengeId = null;
    signupId = await api.signup(input);
  });

  Future<bool> resend() => run(() async {
    if (signupId != null) {
      signupId = await api.resendSignup(signupId!);
      return;
    }
    if (challengeId == null) throw const ApiException('Start login first.');
    challengeId = await api.resendLogin(challengeId!);
  });

  Future<bool> verify(String otp) => run(() async {
    if (challengeId == null && signupId == null) {
      throw const ApiException('Start signup or login first.');
    }
    final result = signupId != null
        ? await api.verifySignup(signupId!, otp)
        : await api.verifyLogin(challengeId!, otp);
    await _establishSession(result);
  });

  Future<bool> authenticateGoogle(
    String idToken, {
    bool signup = false,
    String? providerRole,
    String? accountRole,
  }) => run(() async {
    final result = await api.authenticateGoogle(
      idToken,
      signup: signup,
      providerRole: providerRole,
      accountRole: accountRole,
    );
    await _establishSession(result);
  });

  Future<bool> saveAccountNames(String firstName, String lastName) =>
      run(() async {
        await api.request(
          'PATCH',
          '/users/${Uri.encodeComponent(api.userId!)}',
          body: {'firstName': firstName.trim(), 'lastName': lastName.trim()},
        );
        await _load();
      });

  Future<bool> startTestOnboarding() => run(() async {
    _clear();
    await api.startTestOnboarding();
    await _establishSession({});
  });

  Future<bool> linkGoogle(String idToken) => run(() async {
    await api.linkGoogle(idToken);
  });

  Future<void> _establishSession(Map<String, dynamic> result) async {
    profile = result.isEmpty ? null : result;
    _accountVerified = true;
    challengeId = null;
    signupId = null;
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 20), (_) {
      final inputContext = FocusManager.instance.primaryFocus?.context;
      final editing =
          inputContext != null &&
          (inputContext.widget is EditableText ||
              inputContext.findAncestorWidgetOfExactType<EditableText>() !=
                  null);
      if (!busy && authenticated && !editing && _pollFailures < 3) {
        unawaited(refresh(automatic: true));
      }
    });
    await _readLocalDeferrals();
    try {
      await _load();
      _pollFailures = 0;
      restorationNeedsRetry = false;
    } catch (_) {
      _pollFailures = 3;
      if (api.roleFlowEnabled && api.accessToken != null) {
        restorationNeedsRetry = true;
      }
      rethrow;
    }
    if (!api.isTestOnboarding) {
      _notifications?.dispose();
      _notifications = DriverNotificationService(
        api: api,
        onOpen: (route) {
          if (!authenticated) return;
          pendingNotificationRoute = route;
          _notify();
        },
      );
      unawaited(_notifications!.init());
    }
  }

  Future<bool> restore() async {
    if (busy || restoring) return false;
    restoring = true;
    restorationNeedsRetry = false;
    try {
      final ok = await run(() async {
        if (await api.restoreSession()) await _establishSession({});
      });
      // A network/server failure is not evidence that a saved session expired.
      // Keep it in secure storage and offer retry without displaying Google login.
      restorationNeedsRetry = !ok && api.accessToken != null;
      return ok;
    } finally {
      restoring = false;
      _notify();
    }
  }

  Future<bool> switchMode(String mode) => run(() async {
    if (mode == 'driver' && !api.hasDriverRole ||
        mode == 'fleet_owner' && !api.hasFleetRole ||
        !['driver', 'fleet_owner'].contains(mode)) {
      throw const ApiException('This account does not support that mode.', 403);
    }
    if (currentTrip != null || online) {
      throw const ApiException(
        'Complete your trip and go offline before switching modes.',
      );
    }
    await api.setProviderMode(mode);
    _socket?.dispose();
    _socket = null;
    await _positions?.cancel();
    _positions = null;
    await _load();
  });

  Future<bool> refresh({bool automatic = false}) async {
    final ok = await run(_load);
    if (ok) {
      _pollFailures = 0;
      refreshWarning = null;
    } else if (automatic) {
      _pollFailures++;
    } else {
      _pollFailures = 3;
    }
    return ok;
  }

  Future<void> _reloadAfterMutation() async {
    try {
      await _load();
      refreshWarning = null;
    } on ApiException catch (e) {
      if (e.status == 401 || e.status == 403) rethrow;
      _pollFailures = 3;
      refreshWarning = 'Saved on the server. The latest status could not be loaded. Refresh status before submitting again.';
    }
  }

  Future<bool> loadMoreHistory() => run(() async {
    final nextLimit = (historyLimit + 20).clamp(20, 100);
    final result = await api.request(
      'GET',
      '/rides/driver/history?limit=$nextLimit',
    );
    history = Map<String, dynamic>.from(result as Map);
    historyLimit = nextLimit;
  });
  Future<bool> selectInitialRole(String role) => run(() async {
    await api.selectInitialRole(role);
    await _load();
  });
  Future<bool> enrolmentAction(Map<String, dynamic> input) => run(() async {
    roleEnrolment = Map<String, dynamic>.from(
      await api.request('PATCH', '/provider/enrolment', body: input) as Map,
    );
    await _load();
  });
  Future<bool> deferDashboardSetup() => enrolmentAction({'deferSetup': true});

  Future<bool> verifyOnboardingCode(String code) => run(() async {
    await api.request(
      'POST',
      '/provider/enrolment/verify-code',
      body: {'code': code.trim().toUpperCase()},
    );
    await _load();
  });
  Future<void> _load() async {
    if (api.roleFlowEnabled &&
        !api.isAdmin &&
        !isPreview &&
        !api.isTestOnboarding) {
      roleEnrolment = Map<String, dynamic>.from(
        await api.request('GET', '/provider/enrolment') as Map,
      );
      if (roleEnrolment?['dashboardAccessible'] != true) {
        account = Map<String, dynamic>.from(
          await api.request('GET', '/users/${api.userId}') as Map,
        );
        if (api.hasDriverRole && api.providerMode == 'driver') {
          profile = await api.fetchDriverProfile();
          currentTrip = null;
          if (profile != null) {
            final trip = await api.request('GET', '/rides/driver/current-trip');
            if (trip is Map) {
              currentTrip = Map<String, dynamic>.from(trip);
              final vehicle = await api.request(
                'GET',
                '/rides/driver/assigned-vehicle',
              );
              assignedVehicle = vehicle is Map
                  ? Map<String, dynamic>.from(vehicle)
                  : null;
              if (api.accessToken != _socket?.auth['token']) _connect();
              _joinTrip();
              if (_positions == null) await _startLocation();
            }
          }
        }
        onboardingLoaded = true;
        return;
      }
    }
    if (isPreview) {
      onboardingLoaded = true;
      return;
    }
    // Keep the loaded journey mounted during a refresh, including while an
    // Android picker returns its result. New sessions start unloaded in _clear.
    if (!api.hasDriverRole || api.providerMode == 'fleet_owner') {
      account = Map<String, dynamic>.from(
        await api.request('GET', '/users/${Uri.encodeComponent(api.userId!)}')
            as Map,
      );
      await api.validateProviderAccount(roleEnrolment);
      onboardingLoaded = true;
      return;
    }
    final nextProfile = await api.fetchDriverProfile();
    Map<String, dynamic>? nextVehicle;
    if (nextProfile != null) {
      try {
        final data = await api.request('GET', '/rides/driver/assigned-vehicle');
        nextVehicle = data == null
            ? null
            : Map<String, dynamic>.from(data as Map);
      } on ApiException catch (e) {
        if (e.status != 404 || e.code != 'NO_ASSIGNED_VEHICLE') rethrow;
      }
    }
    final category =
        nextVehicle?['category'] ??
        assignmentPreview?['vehicle']?['category'] ??
        '*';
    final policy = await api.request(
      'GET',
      '/provider/document-requirements?category=${Uri.encodeQueryComponent(category as String)}',
    );
    Map<String, dynamic>? nextReceipt;
    if (!api.isTestOnboarding) {
      try {
        nextReceipt = Map<String, dynamic>.from(
          await api.request('GET', '/provider/onboarding') as Map,
        );
      } on ApiException catch (e) {
        // Older deployments have no saved progress endpoint. Continue with
        // profile and document requirements; this grants no approval or access.
        if (e.status != 404) rethrow;
      }
    }
    final rules = <String, DocumentRule>{};
    for (final row
        in (nextReceipt?['requirements'] as List?) ?? policy as List) {
      final rule = DocumentRule.fromJson(Map<String, dynamic>.from(row as Map));
      final previous = rules[rule.code];
      rules[rule.code] = DocumentRule(
        rule.code,
        required:
            rule.code == 'driver_license' ||
            rule.required ||
            (previous?.required ?? false),
        onboardingDeferrable:
            rule.onboardingDeferrable &&
            (previous?.onboardingDeferrable ?? true),
        requiresExpiry:
            rule.requiresExpiry || (previous?.requiresExpiry ?? false),
        minimumPages: rule.minimumPages > (previous?.minimumPages ?? 0)
            ? rule.minimumPages
            : previous!.minimumPages,
      );
    }
    final nextDocuments = nextProfile == null
        ? <Map<String, dynamic>>[]
        : (await api.request('GET', '/rides/driver/documents') as List)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
    final nextApprovals = (await api.request(
      'GET',
      '/provider/approvals',
    ) as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
    final nextApplications = <Map<String, dynamic>>[];
    if (nextProfile != null && !api.isTestOnboarding) {
      var page = 1;
      var seen = 0;
      while (true) {
        final result = await api.request(
          'GET',
          '/driver-applications?driverProfileId=${Uri.encodeQueryComponent(nextProfile['id'] as String)}&page=$page&limit=100',
        );
        final items = (result['items'] as List)
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();
        nextApplications.addAll(
          items.where((a) => a['driverProfileId'] == nextProfile['id']),
        );
        seen += items.length;
        final total = (result['total'] as num?)?.toInt() ?? seen;
        if (seen >= total) break;
        if (items.isEmpty) {
          throw const ApiException(
            'The fleet application list is incomplete. Retry your status check.',
          );
        }
        if (page >= 50) {
          throw const ApiException(
            'Too many application pages. Contact support before retrying.',
          );
        }
        page++;
      }
    }
    final nextPartnerDocuments = <Map<String, dynamic>>[];
    if (api.userId != null && !api.isTestOnboarding) {
      try {
        final ownPartner = await api.request('GET', '/partners/me');
        nextPartnerDocuments.addAll(
          (await api.request(
            'GET',
            '/partners/${ownPartner['id']}/documents',
          ) as List).map((d) => Map<String, dynamic>.from(d as Map)),
        );
      } on ApiException catch (e) {
        if (e.status != 404 || e.code != 'PARTNER_NOT_FOUND') rethrow;
      }
    }
    final nextPages = <String, int>{};
    for (final rule in rules.values.where((r) => r.minimumPages > 1)) {
      final doc = OnboardingRules.documentFor(rule.code, nextDocuments);
      if (doc != null) {
        final pages = await api.request(
          'GET',
          '/rides/driver/documents/${Uri.encodeComponent(doc['id'] as String)}/pages/access-urls',
        );
        nextPages[doc['id'] as String] = (pages as List).length;
      }
    }
    final userId = api.userId ?? nextProfile?['userId'];
    if (userId != null) {
      account = Map<String, dynamic>.from(
        await api.request(
          'GET',
          '/users/${Uri.encodeComponent(userId as String)}',
        ) as Map,
      );
    }
    profile = nextProfile;
    assignedVehicle = nextVehicle;
    documents = nextDocuments;
    partnerDocuments = nextPartnerDocuments;
    approvals = nextApprovals;
    applications = nextApplications;
    documentRules = rules.values.toList();
    documentPages
      ..clear()
      ..addAll(nextPages);
    onboardingLoaded = true;
    if (!operationalAllowed) {
      _socket?.dispose();
      _socket = null;
      realtimeStatus = 'Disconnected';
      await _positions?.cancel();
      _positions = null;
      _expiry?.cancel();
      rides = [];
      currentTrip = null;
      history = null;
      return;
    }
    final nextTrip = await api.request('GET', '/rides/driver/current-trip');
    final nextHistory = await api.request(
      'GET',
      '/rides/driver/history?limit=$historyLimit',
    );
    final nextRides = await api.request('GET', '/rides/driver/available');
    currentTrip = nextTrip == null
        ? null
        : Map<String, dynamic>.from(nextTrip as Map);
    history = Map<String, dynamic>.from(nextHistory as Map);
    rides = (nextRides as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
    if (api.accessToken != _socket?.auth['token']) _connect();
    _joinTrip();
    if ((online || currentTrip != null) && _positions == null) {
      await _startLocation();
    }
    if (!online && currentTrip == null && _positions != null) {
      await _positions?.cancel();
      _positions = null;
    }
  }

  Future<bool> saveProfile(Map<String, dynamic> input) => run(() async {
    final validation = OnboardingRules.validateProfile(input);
    if (validation != null) throw ApiException(validation);
    const keys = [
      'licenseNumber',
      'licenseExpiry',
      'dob',
      'gender',
      'address',
      'city',
      'state',
      'pinCode',
      'emergencyContactName',
      'emergencyContactPhone',
      'emergencyContactRelationship',
      'alternateContactPhone',
    ];
    final saved = await api.request(
      'POST',
      '/rides/driver/profile',
      body: {
        for (final key in keys)
          if (input[key] != null) key: input[key],
      },
    );
    if (saved is Map && saved['id'] is String) {
      profile = Map<String, dynamic>.from(saved);
    }
    await _reloadAfterMutation();
  });

  Future<bool> uploadDocument(
    DocumentRule rule,
    List<DocumentFile> files,
    Map<String, String> metadata,
  ) => run(() async {
    if (profile == null) {
      throw const ApiException(
        'Save your personal and licence details before uploading.',
      );
    }
    final validation = OnboardingRules.validateFiles(rule, files, metadata);
    if (validation != null) throw ApiException(validation);
    final saved = await api.uploadDriverDocument(rule.uploadType, files, {
      ...metadata,
      if (rule.uploadType == 'other' && rule.code != 'other')
        'documentCode': rule.code,
    });
    if (saved is Map && saved['id'] is String) {
      final row = Map<String, dynamic>.from(saved);
      documents = [...documents.where((d) => d['id'] != row['id']), row];
    }
    await _reloadAfterMutation();
  });

  Future<bool> previewAssignment(String code) => run(() async {
    if (code.trim().isEmpty || code.trim().length > 20) {
      throw const ApiException(
        'Enter the fleet assignment code (up to 20 characters).',
      );
    }
    assignmentPreview = Map<String, dynamic>.from(
      await api.request(
        'POST',
        '/rides/driver/assignment/verify-code',
        body: {'code': code.trim()},
      ) as Map,
    );
    await _load();
  });
  Future<bool> claimAssignment(String code) => run(() async {
    final receipt = await api.request(
      'POST',
      '/rides/driver/assignment/claim-code',
      body: {'code': code.trim()},
    );
    if (receipt is Map && receipt['vehicleId'] is String) {
      assignedVehicle = {
        ...Map<String, dynamic>.from(receipt),
        'id': receipt['vehicleId'],
      };
    }
    if (api.roleFlowEnabled && roleEnrolment?['dashboardAccessible'] != true) {
      await api.request(
        'PATCH',
        '/provider/enrolment',
        body: {'deferSetup': true},
      );
    }
    assignmentPreview = null;
    await _reloadAfterMutation();
  });
  Future<bool> applyToFleet(Map<String, dynamic> input) => run(() async {
    if (profile == null) {
      throw const ApiException('Save your driver profile first.');
    }
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(input['partnerId'] as String? ?? '')) {
      throw const ApiException(
        'Enter the valid partner reference supplied by your fleet.',
      );
    }
    final category = input['requestedVehicleCategory'] as String? ?? '';
    if (category.trim().isEmpty || category.length > 50) {
      throw const ApiException(
        'Enter the fleet vehicle category (up to 50 characters).',
      );
    }
    await api.request(
      'POST',
      '/driver-applications',
      body: {
        'partnerId': input['partnerId'],
        'driverProfileId': profile!['id'],
        'requestedSector': input['requestedSector'],
        'requestedVehicleCategory': input['requestedVehicleCategory'],
        'vehicleOwnershipType': 'DRIVER_ONLY',
      },
    );
    await _load();
  });
  Future<bool> submitOnboarding() => run(() async {
    if (!onboardingLoaded || profile == null) {
      throw const ApiException(
        'Save your profile and load the document requirements first.',
      );
    }
    final validation = OnboardingRules.validateProfile(profile!);
    if (validation != null) throw ApiException(validation);
    final result = Map<String, dynamic>.from(
      await api.request(
        'POST',
        '/provider/approval-requests',
        body: {'requestType': 'onboarding_submission'},
      ) as Map,
    );
    if (result['dashboardAccessible'] != true || result['receipt_id'] == null) {
      throw const ApiException(
        'Submission was not acknowledged. Please retry.',
      );
    }
    onboardingReceipt = result;
    try {
      await _load();
    } on ApiException {
      onboardingLoaded = true;
      error = 'Submission received. Some details could not refresh; retry from Profile.';
    }
  });
  Future<void> _permission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const ApiException('Enable GPS location services on your device.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const ApiException(
        'Location permission is required. Enable it in app settings.',
      );
    }
  }

  Future<bool> locate() => run(() async {
    await _permission();
    position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 30),
      ),
    );
  });

  Future<void> _startLocation() async {
    await _permission();
    position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 30),
      ),
    );
    await _sendLocation(position!);
    await _positions?.cancel();
    _positions =
        Geolocator.getPositionStream(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
            intervalDuration: const Duration(seconds: 5),
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationTitle: 'Infurnus driver location',
              notificationText: 'Sharing your location while you are online.',
              enableWakeLock: true,
            ),
          ),
        ).listen(
          (p) {
            position = p;
            unawaited(_locationUpdate(p));
          },
          onError: (_) {
            error = 'Location tracking stopped. Check GPS and permissions.';
            _notify();
          },
        );
  }

  Future<void> _locationUpdate(Position p) async {
    if (_sendingLocation || !authenticated) return;
    _sendingLocation = true;
    try {
      await _sendLocation(p);
    } catch (e) {
      error = e is ApiException
          ? e.message
          : 'Location update could not be delivered.';
      if (api.accessToken == null) _clear();
    } finally {
      _sendingLocation = false;
      _notify();
    }
  }

  Future<void> _sendLocation(Position p) async {
    final payload = {
      'latitude': p.latitude,
      'longitude': p.longitude,
      'timestamp': p.timestamp.toUtc().toIso8601String(),
      if (p.accuracy >= 0) 'accuracy': p.accuracy,
      if (p.speed >= 0) 'speed': p.speed,
      if (p.heading >= 0 && p.heading <= 360) 'heading': p.heading,
    };
    // Send each monotonic GPS sample once. The REST endpoint also broadcasts
    // location when there is no connected ride socket.
    if (_socket?.connected == true && currentTrip != null) {
      final acknowledgement = Completer<dynamic>();
      _socket!.emitWithAck(
        'driver:location',
        {...payload, 'rideId': currentTrip!['id']},
        ack: (dynamic response) {
          if (!acknowledgement.isCompleted) acknowledgement.complete(response);
        },
      );
      final response = await acknowledgement.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () => throw const ApiException(
          'Live location acknowledgement timed out. Checking the next GPS update.',
        ),
      );
      if (response is! Map || response['success'] != true) {
        throw const ApiException(
          'The server rejected the live location update.',
        );
      }
    } else {
      await api.request('POST', '/rides/driver/location', body: payload);
    }
    lastLocationSent = DateTime.now();
  }

  Future<bool> setOnline(bool value) => run(() async {
    if (isPreview) {
      profile?['availabilityStatus'] = value ? 'available' : 'unavailable';
      return;
    }
    if (value && !operationalAllowed) {
      throw const ApiException(
        'Complete backend approval and vehicle assignment before going online.',
      );
    }
    if (value) await _startLocation();
    try {
      await api.request(
        'PATCH',
        '/rides/driver/availability',
        body: {'status': value ? 'available' : 'unavailable'},
      );
    } catch (_) {
      if (value) {
        await _positions?.cancel();
        _positions = null;
      }
      rethrow;
    }
    if (!value && currentTrip == null) {
      await _positions?.cancel();
      _positions = null;
    }
    await _load();
  });

  Future<bool> accept(String id) => run(() async {
    if (isPreview) {
      final index = rides.indexWhere((r) => r['id'] == id);
      if (index >= 0) {
        currentTrip = {...rides[index], 'status': 'accepted'};
        rides.removeAt(index);
      }
      return;
    }
    if (!operationalAllowed) {
      throw const ApiException(
        'Complete backend approval and vehicle assignment before accepting rides.',
      );
    }
    final offer = rides.where((ride) => ride['id'] == id).firstOrNull;
    if (offer == null) {
      throw const ApiException(
        'This offer is no longer available. Refresh the offers.',
      );
    }
    final expiry = DateTime.tryParse(
      offer['dispatchExpiresAt']?.toString() ?? '',
    );
    if (expiry != null && !expiry.isAfter(DateTime.now())) {
      throw const ApiException('This offer has expired. Refresh the offers.');
    }
    await api.request('POST', '/rides/${Uri.encodeComponent(id)}/accept');
    await _load();
  });
  Future<bool> decline(String id) => run(() async {
    if (isPreview) {
      rides.removeWhere((r) => r['id'] == id);
      return;
    }
    await api.request(
      'POST',
      '/rides/driver/available/${Uri.encodeComponent(id)}/decline',
    );
    await _load();
  });
  Future<bool> transition(String status, {String? pin}) => run(() async {
    if (currentTrip == null) throw const ApiException('No active trip.');
    if (isPreview) {
      if (status == 'completed') {
        currentTrip = null;
      } else {
        currentTrip?['status'] = status;
      }
      return;
    }
    final id = Uri.encodeComponent(currentTrip!['id'] as String);
    if (status == 'completed') {
      await api.request('POST', '/rides/$id/complete');
    } else if (status == 'in_progress') {
      if (currentTrip?['status'] != 'driver_arrived' ||
          pin == null ||
          !RegExp(r'^\d{4}$').hasMatch(pin)) {
        throw const ApiException(
          'Arrive at pickup and enter the passenger’s four-digit PIN.',
        );
      }
      final result = await api.request(
        'POST',
        '/rides/$id/verify-pin',
        body: {'pin': pin},
      );
      final ride = result is Map ? result['ride'] : null;
      if (ride is! Map ||
          ride['id'] != currentTrip!['id'] ||
          ride['status'] != 'in_progress' ||
          ride['pinVerified'] != true) {
        throw const ApiException(
          'Trip start was not confirmed. Refresh and contact support if this continues.',
        );
      }
      currentTrip = Map<String, dynamic>.from(ride);
    } else {
      await api.request(
        'POST',
        '/rides/$id/status',
        body: {'status': status, 'pin': ?pin},
      );
    }
    try {
      await _load();
    } catch (_) {
      if (status == 'in_progress' &&
          api.accessToken != null &&
          currentTrip?['id'] == Uri.decodeComponent(id) &&
          currentTrip?['status'] == 'in_progress') {
        error = 'Trip started. Status refresh is unavailable; retry when connected.';
        return;
      }
      rethrow;
    }
  });

  void _connect() {
    _socket?.dispose();
    _socket = io.io(
      ApiService.baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNew()
          .setAuth({'token': api.accessToken, 'providerMode': api.providerMode})
          .build(),
    );
    realtimeStatus = 'Connecting';
    _socket!.onConnect((_) {
      realtimeStatus = 'Connected';
      _joinTrip();
      _notify();
      // Reconcile missed events with the authoritative API after reconnecting.
      if (!busy && authenticated) unawaited(refresh());
    });
    _socket!.onDisconnect((_) {
      realtimeStatus = 'Disconnected';
      _notify();
    });
    _socket!.onConnectError((_) {
      realtimeStatus = 'Connection failed';
      _notify();
    });
    for (final event in [
      'ride:incoming',
      'ride:taken',
      'ride:driver_assigned',
      'ride:lifecycle_updated',
      'ride:completed',
      'ride:cancelled',
      'ride:route_updated',
    ]) {
      _socket!.on(event, (_) {
        if (!busy && authenticated) unawaited(refresh());
      });
    }
    _socket!.connect();
    _expiry?.cancel();
    // Rotate session periodically as well as on HTTP 401 so socket handshakes
    // reconnect with refreshed access tokens instead of retrying expired ones.
    _expiry = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!busy && authenticated) {
        unawaited(
          run(() async {
            await api.refreshSession();
            _connect();
            await _load();
          }),
        );
      }
    });
  }

  void _joinTrip() {
    if (currentTrip != null && _socket?.connected == true) {
      _socket!.emitWithAck(
        'ride:join',
        currentTrip!['id'],
        ack: (dynamic response) {
          if (response is Map && response['success'] == false) {
            error = 'The server denied access to the ride updates.';
            _notify();
          }
        },
      );
    }
  }

  Future<bool> logout() => run(() async {
    try {
      try {
        await _notifications?.unregister();
      } catch (_) {
        // Logout must still clear local credentials when token cleanup is offline.
      }
      if (online) {
        await api.request(
          'PATCH',
          '/rides/driver/availability',
          body: {'status': 'unavailable'},
        );
      }
    } finally {
      try {
        await api.logout();
      } finally {
        _clear();
      }
    }
  });
  void _clear({bool persist = true}) {
    _notifications?.dispose();
    _notifications = null;
    pendingNotificationRoute = null;
    _positions?.cancel();
    _positions = null;
    _poll?.cancel();
    _expiry?.cancel();
    _socket?.dispose();
    _socket = null;
    _accountVerified = false;
    onboardingLoaded = false;
    _localDeferrals.clear();
    onboardingReceipt = null;
    roleEnrolment = null;
    isPreview = false;
    _pollFailures = 0;
    refreshWarning = null;
    account = null;
    assignmentPreview = null;
    documents = [];
    partnerDocuments = [];
    approvals = [];
    applications = [];
    documentRules = [];
    documentPages.clear();
    signupId = null;
    profile = null;
    currentTrip = null;
    assignedVehicle = null;
    history = null;
    historyLimit = 20;
    rides = [];
    challengeId = null;
    position = null;
    lastLocationSent = null;
    realtimeStatus = 'Disconnected';
    api.clearSession(persist: persist);
  }

  @override
  void dispose() {
    _disposed = true;
    _clear(persist: false);
    api.dispose();
    super.dispose();
  }
}
