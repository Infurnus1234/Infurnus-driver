import '../services/location_access.dart';
import '../models/provider_public_id.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import '../services/session_store.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show EditableText, FocusManager, WidgetsBinding, AppLifecycleState;
import 'package:geolocator/geolocator.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/ride_request_presentation.dart';
import '../models/onboarding_rules.dart';
import '../models/provider_status.dart';
import '../models/ride_customer_contact.dart';

class DriverSession extends ChangeNotifier {
  final ApiService api;
  final SessionStore _onboardingDraftStore;
  DriverSession({ApiService? api, SessionStore? onboardingDraftStore})
    : api = api ?? ApiService(),
      _onboardingDraftStore =
          onboardingDraftStore ?? SecureOnboardingDraftStore();
  Map<String, dynamic>? profile;
  Map<String, dynamic>? currentTrip;
  RideCustomerContact? customerContact;
  bool customerContactLoading = false;
  String? customerContactError;
  int _contactGeneration = 0;
  Future<void>? _contactRequest;
  String? _contactRideId, _contactUserId;

  RideCustomerContact? get activeCustomerContact =>
      canRequestCustomerContact &&
          customerContact?.rideId == currentTrip?['id'] &&
          _contactUserId == api.userId
      ? customerContact
      : null;

  bool get canRequestCustomerContact =>
      authenticated &&
      !isPreview &&
      api.hasDriverRole &&
      api.providerMode == 'driver' &&
      currentTrip?['id'] is String &&
      const [
        'driver_assigned',
        'driver_arriving',
        'driver_arrived',
        'in_progress',
      ].contains(currentTrip?['status']);

  void _invalidateCustomerContact() {
    _contactGeneration++;
    customerContact = null;
    customerContactError = null;
    customerContactLoading = false;
    _contactRideId = null;
    _contactUserId = null;
    _contactRequest = null;
  }

  void hideCustomerContact() {
    final contact = activeCustomerContact;
    if (contact == null && _contactRequest == null) return;
    _invalidateCustomerContact();
    if (contact != null) {
      _contactUserId = api.userId;
      customerContact = RideCustomerContact(
        rideId: contact.rideId,
        name: contact.name,
      );
    }
    _notify();
  }

  Future<void> refreshCustomerContact() {
    if (!canRequestCustomerContact) {
      _invalidateCustomerContact();
      _notify();
      return Future.value();
    }
    final id = currentTrip!['id'] as String;
    if (_contactRideId == id &&
        _contactUserId == api.userId &&
        _contactRequest != null) {
      return _contactRequest!;
    }
    if (activeCustomerContact == null) _invalidateCustomerContact();
    final generation = _contactGeneration;
    final userId = api.userId;
    _contactRideId = id;
    _contactUserId = userId;
    customerContactError = null;
    customerContactLoading = true;
    final request = _fetchCustomerContact(id, userId, generation);
    _contactRequest = request;
    _notify();
    return request;
  }

  Future<void> _fetchCustomerContact(
    String id,
    String? userId,
    int generation,
  ) async {
    try {
      final data = await api.request(
        'GET',
        '/rides/driver/rides/${Uri.encodeComponent(id)}/customer-contact',
      );
      if (_disposed ||
          generation != _contactGeneration ||
          api.userId != userId ||
          !canRequestCustomerContact ||
          currentTrip?['id'] != id) {
        return;
      }
      final next = RideCustomerContact.fromJson(data as Map, id);
      customerContact = RideCustomerContact(
        rideId: id,
        name: next.name.isEmpty ? activeCustomerContact?.name ?? '' : next.name,
        callingNumber: next.callingNumber,
      );
    } catch (e) {
      if (_disposed ||
          generation != _contactGeneration ||
          api.userId != userId ||
          currentTrip?['id'] != id) {
        return;
      }
      final saved = activeCustomerContact;
      customerContact =
          e is ApiException && const [401, 403, 404, 410].contains(e.status)
          ? null
          : saved == null
          ? null
          : RideCustomerContact(rideId: id, name: saved.name);
      customerContactError =
          'Customer contact could not be verified. Refresh or try again.';
    } finally {
      if (generation == _contactGeneration) {
        customerContactLoading = false;
        _contactRequest = null;
        _notify();
      }
    }
  }

  Future<Uri?> customerContactUri(String scheme) async {
    if (scheme != 'tel' && scheme != 'sms') return null;
    final id = currentTrip?['id'];
    // One fresh, coalesced ownership/state check before passing PII to the OS.
    await refreshCustomerContact();
    final contact = activeCustomerContact;
    if (!canRequestCustomerContact ||
        currentTrip?['id'] != id ||
        contact?.rideId != id ||
        contact?.callingNumber == null) {
      return null;
    }
    return Uri(scheme: scheme, path: contact!.callingNumber);
  }

  Map<String, dynamic>? assignedVehicle;
  bool assignedVehicleLoading = false;
  bool assignedVehicleLoaded = false;
  String? assignedVehicleError;
  Map<String, dynamic>? history;
  int historyLimit = 20;
  List<Map<String, dynamic>> rides = [];
  Position? position;
  String? challengeId;
  String? signupId;
  String? verificationContact;
  DateTime? verificationResendAt;
  bool isPreview = false;
  bool restoring = false;
  bool restorationNeedsRetry = false;

  void enablePreview() {
    if (!kReleaseMode) {
      isPreview = true;
      // Preview has no access credential and cannot authorize backend requests.
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
      assignedVehicleLoaded = true;
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
  Map<String, dynamic>? providerAccount;
  String? get publicId {
    for (final record in [providerAccount, account, profile]) {
      final value = providerPublicId(record?['publicId']);
      if (value != null) return value;
    }
    return null;
  }

  Map<String, dynamic>? assignmentPreview;
  List<Map<String, dynamic>> documents = [];
  List<Map<String, dynamic>> partnerDocuments = [];
  Map<String, dynamic>? requirementDocument(String code) {
    final driverDocument = OnboardingRules.documentFor(code, documents);
    final candidates = <Map<String, dynamic>>[
      ?driverDocument,
      if (code == 'profile_photo' &&
          (profile?['photoUrl'] != null || profile?['avatarUrl'] != null))
        {
          'id': 'profile_photo',
          'verificationStatus': profile!['verificationStatus'],
        },
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

  String? locationWarning;
  Map<String, dynamic>? _navigationUpdate;
  Map<String, dynamic>? get liveNavigation =>
      _navigationUpdate?['rideId'] == currentTrip?['id']
      ? _navigationUpdate ?? currentTrip
      : currentTrip;
  Future<bool>? _activeTripRequest;
  int _tripGeneration = 0;
  String? _joinedTripId;
  bool paymentRefreshing = false;
  String? paymentRefreshError;

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
  DateTime? _lastLocationSampleSent;
  bool busy = false;
  bool _disposed = false;
  bool _sendingLocation = false;
  bool _rideEventRefreshPending = false;
  StreamSubscription<Position>? _positions;
  int _locationEpoch = 0;
  io.Socket? _socket;
  Timer? _poll;
  Timer? _expiry;
  DriverNotificationService? _notifications;
  DriverNotificationService? get notifications => _notifications;

  void dismissRideNotifications() {
    unawaited(_notifications?.cancelAll());
  }

  String? pendingNotificationRoute;
  String? driverPhotoUrl;
  String? _photoDocumentId;
  DateTime? _photoValidUntil;
  Map<String, dynamic>? todaySummary;
  String? todaySummaryError;
  Future<void> refreshTodaySummary() async {
    if (!authenticated ||
        !api.hasDriverRole ||
        api.providerMode == 'fleet_owner' ||
        isPreview) {
      return;
    }
    try {
      todaySummary = Map<String, dynamic>.from(
        await api.request('GET', '/rides/driver/today-summary') as Map,
      );
      todaySummaryError = null;
    } catch (_) {
      todaySummary = null;
      todaySummaryError = 'Today’s summary is temporarily unavailable.';
    }
  }

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
  void clearLocalDeferrals() {
    _localDeferrals.clear();
    if (_onboardingDraftStore is MemorySessionStore) {
      _onboardingDraftStore.value = '{}';
    } else {
      _onboardingDraftStore.write('{}');
    }
  }

  Set<String> get deferredSteps => {
    ...((onboardingReceipt?['deferred_codes'] as List?) ?? const [])
        .cast<String>(),
    ..._localDeferrals.where(canDefer),
  };
  bool canDefer(String code) =>
      code != 'driver_license' &&
      (['vehicle', 'fleet', 'profile_photo'].contains(code) ||
          (documentRules.any((r) => r.code == code) &&
              documentRules
                  .where((r) => r.code == code)
                  .any((r) => r.onboardingDeferrable)));
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
    if (!onboardingLoaded || profile == null) return '/onboarding';
    // Profile is loaded; direct to the checklist whether uploads are missing or not.
    return '/verification-status';
  }

  bool get online =>
      profile?['onlinePreference'] as bool? ??
      const [
        'available',
        'stale',
        'busy',
      ].contains(profile?['availabilityStatus']);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<bool> run(Future<void> Function() action) async {
    if (busy) return false;
    _tripGeneration++;
    busy = true;
    error = null;
    errorCode = null;
    _notify();
    try {
      await action();
      return true;
    } catch (e, stack) {
      developer.log(
        'Driver action failed',
        name: 'DriverSession',
        error: e,
        stackTrace: stack,
      );
      if (!assignedVehicleLoaded &&
          api.hasDriverRole &&
          api.providerMode == 'driver') {
        assignedVehicleLoading = false;
        assignedVehicleLoaded = true;
        assignedVehicleError =
            'We couldn\'t load your vehicle. Please try again.';
      }
      if (kDebugMode) {
        debugPrint(
          'Driver action failed: ${e.runtimeType}${e is ApiException ? ' status=${e.status} code=${e.code}' : ''}',
        );
        if (e is TypeError) debugPrint('Driver type failure: $e');
        debugPrintStack(stackTrace: stack, maxFrames: 6);
      }
      errorCode = e is ApiException ? e.code : null;
      if (!_accountVerified && api.accessToken != null) {
        restorationNeedsRetry = true;
      }
      error = userSafeErrorMessage(e);
      if (api.accessToken == null && _accountVerified) _clear();
      return false;
    } finally {
      busy = false;
      _notify();
      _drainRideEventRefresh();
    }
  }

  Future<bool> login(
    String identifier, [
    String? password,
    String? accountRole,
  ]) => run(() async {
    if (identifier.trim().isEmpty) {
      throw const ApiException('Enter your mobile number or email address.');
    }
    challengeId = null;
    signupId = null;
    verificationContact = null;
    verificationResendAt = null;
    challengeId = await api.login(identifier, accountRole: accountRole);
    verificationContact = identifier;
    verificationResendAt = DateTime.now().add(
      Duration(seconds: api.otpResendAfterSeconds),
    );
  });

  Future<bool> signup(Map<String, dynamic> input) => run(() async {
    final validation = OnboardingRules.validateSignup(input);
    if (validation != null) throw ApiException(validation);
    signupId = null;
    verificationContact = null;
    verificationResendAt = null;
    challengeId = null;
    verificationContact = null;
    signupId = await api.signup(input);
    verificationContact = (input['phone'] ?? input['email']) as String?;
    verificationResendAt = DateTime.now().add(
      Duration(seconds: api.otpResendAfterSeconds),
    );
  });

  Future<bool> resend() => run(() async {
    if (signupId != null) {
      signupId = await api.resendSignup(signupId!);
      verificationResendAt = DateTime.now().add(
        Duration(seconds: api.otpResendAfterSeconds),
      );
      return;
    }
    if (challengeId == null) throw const ApiException('Start login first.');
    challengeId = await api.resendLogin(challengeId!);
    verificationResendAt = DateTime.now().add(
      Duration(seconds: api.otpResendAfterSeconds),
    );
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
    verificationContact = null;
    verificationResendAt = null;
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
        onRideUpdate: (data) => handleRideEvent('ride:lifecycle_updated', data),
        onOpen: (route) {
          if (!authenticated) return;
          pendingNotificationRoute = route;
          _notify();
        },
      );
      unawaited(_notifications!.init());
    }
  }

  Future<bool>? _restoration;

  // All startup/resume/retry callers share one rotation and initialization.
  Future<bool> restore() {
    final pending = _restoration;
    if (pending != null) return pending;
    if (busy) return Future.value(false);
    return _restoration = _restoreOnce();
  }

  Future<bool> _restoreOnce() async {
    restoring = true;
    restorationNeedsRetry = false;
    try {
      final ok = await run(() async {
        for (var attempt = 0; ; attempt++) {
          try {
            if (api.accessToken != null) {
              await api.refreshSession();
              await _establishSession({});
            } else if (await api.restoreSession()) {
              await _establishSession({});
            }
            break;
          } on ApiException catch (e) {
            final recoverable =
                e.status == null ||
                e.status == 408 ||
                e.status == 429 ||
                (e.status != null && e.status! >= 500);
            if (!recoverable || attempt >= 1) rethrow;
            // Retain credentials on transport/server failures. Bound retries;
            // persistent outages return to sign-in with the retry banner.
            await Future<void>.delayed(const Duration(milliseconds: 600));
          }
        }
      });
      restorationNeedsRetry = !ok && api.accessToken != null;
      return ok;
    } finally {
      restoring = false;
      _restoration = null;
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
    if (automatic && currentTrip != null) return _refreshActiveTrip();
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
      try {
        roleEnrolment = Map<String, dynamic>.from(
          await api.request('GET', '/provider/enrolment') as Map,
        );
      } on ApiException catch (e) {
        if (e.status == 401 || e.status == 403) {
          roleEnrolment = null;
          rethrow;
        }
        roleEnrolment ??= {
          'role': api.role,
          'dashboardAccessible': false,
          'steps': ['profile_photo', 'licence', 'finish'],
          'progress': {},
        };
      }
      roleEnrolment ??= {
        'role': api.role,
        'dashboardAccessible': false,
        'steps': ['profile_photo', 'licence', 'finish'],
        'progress': {},
      };
      if (roleEnrolment?['dashboardAccessible'] != true) {
        account = Map<String, dynamic>.from(
          await api.request('GET', '/users/${api.userId}') as Map,
        );
        if (api.hasDriverRole && api.providerMode == 'driver') {
          profile = await api.fetchDriverProfile();
          if (profile != null) {
            try {
              final trip = await api.request(
                'GET',
                '/rides/driver/current-trip',
              );
              if (trip is Map) {
                _setCurrentTrip(trip);
                await _ensureCustomerContact();
                assignedVehicle = await _fetchAssignedVehicle();
                if (api.accessToken != _socket?.auth['token']) _connect();
                _joinTrip();
                if (_positions == null) await _resumeLocation();
              } else {
                _setCurrentTrip(null);
                assignedVehicle = null;
                assignedVehicleLoading = false;
                assignedVehicleLoaded = true;
                assignedVehicleError = null;
              }
            } on ApiException catch (e) {
              if (e.status != 404) rethrow;
              _setCurrentTrip(null);
              assignedVehicle = null;
              assignedVehicleLoading = false;
              assignedVehicleLoaded = true;
              assignedVehicleError = null;
            }
          } else {
            assignedVehicleLoading = false;
            assignedVehicleLoaded = true;
            assignedVehicleError = null;
          }
          try {
            final appData = await api.request('GET', '/provider/approvals');
            if (appData is List) {
              approvals = appData
                  .map((r) => Map<String, dynamic>.from(r as Map))
                  .toList();
            }
          } on ApiException catch (e) {
            if (e.status != 404) rethrow;
          }
        }
        if (documentRules.isEmpty) {
          documentRules = [
            const DocumentRule(
              'profile_photo',
              required: true,
              onboardingDeferrable: true,
            ),
            const DocumentRule(
              'driver_license',
              required: true,
              requiresExpiry: true,
            ),
          ];
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
      nextVehicle = await _fetchAssignedVehicle();
    } else {
      assignedVehicleLoading = false;
      assignedVehicleLoaded = true;
      assignedVehicleError = null;
    }
    assignedVehicle = nextVehicle;
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
            // Identity consent/authorization is separate from document necessity.
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
        collectionAuthorized: rule.collectionAuthorized,
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
    final photoDoc = OnboardingRules.documentFor(
      'profile_photo',
      nextDocuments,
    );
    final photoId = photoDoc?['id']?.toString();
    if (photoId != null &&
        (_photoDocumentId != photoId ||
            _photoValidUntil == null ||
            DateTime.now().isAfter(_photoValidUntil!))) {
      try {
        final data = await api.request(
          'GET',
          '/rides/driver/documents/${Uri.encodeComponent(photoId)}/access-url',
        ) as Map;
        driverPhotoUrl = data['accessUrl']?.toString();
        _photoDocumentId = photoId;
        _photoValidUntil = DateTime.now().add(const Duration(minutes: 4));
      } catch (_) {
        driverPhotoUrl = null;
      }
    }

    partnerDocuments = nextPartnerDocuments;
    approvals = nextApprovals;
    applications = nextApplications;
    documentRules = rules.values.map((r) {
      final existing = documentRules.firstWhere(
        (e) => e.code == r.code,
        orElse: () => r,
      );
      return DocumentRule(
        r.code,
        required: r.required,
        onboardingDeferrable:
            r.onboardingDeferrable || existing.onboardingDeferrable,
        requiresExpiry: r.requiresExpiry,
        minimumPages: r.minimumPages,
        collectionAuthorized:
            r.collectionAuthorized ?? existing.collectionAuthorized,
      );
    }).toList();
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
      _setCurrentTrip(null);
      history = null;
      return;
    }
    final nextTrip = await api.request('GET', '/rides/driver/current-trip');
    final nextHistory = await api.request(
      'GET',
      '/rides/driver/history?limit=$historyLimit',
    );
    final nextRides = await api.request('GET', '/rides/driver/available');
    _setCurrentTrip(nextTrip as Map?);
    history = Map<String, dynamic>.from(nextHistory as Map);
    rides = (nextRides as List)
        .map(
          (r) => <String, dynamic>{
            ...Map<String, dynamic>.from(r as Map),
            '_receivedAt': DateTime.now().toIso8601String(),
          },
        )
        .toList();
    await _ensureCustomerContact();
    await refreshTodaySummary();
    if (api.accessToken != _socket?.auth['token']) _connect();
    _joinTrip();
    if ((online || currentTrip != null) && _positions == null) {
      await _resumeLocation();
    }
    if (!online && currentTrip == null && _positions != null) {
      await _positions?.cancel();
      _positions = null;
    }
  }

  Future<bool> saveAccount(Map<String, dynamic> input) => run(() async {
    providerAccount = Map<String, dynamic>.from(
      await api.request('PATCH', '/provider/account', body: input) as Map,
    );
  });

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
    assignmentPreview = null;
    try {
      assignmentPreview = Map<String, dynamic>.from(
        await api.request(
          'POST',
          '/rides/driver/assignment/verify-code',
          body: {'code': code.trim()},
        ) as Map,
      );
    } on ApiException catch (e, stack) {
      developer.log(
        'Assignment code verification failed: ${e.message}',
        name: 'DriverSession',
        error: e,
        stackTrace: stack,
      );
      throw ApiException(_assignmentCodeFailure(e), e.status, e.code);
    }
  });
  Future<bool> claimAssignment(String code) => run(() async {
    dynamic receipt;
    try {
      receipt = await api.request(
        'POST',
        '/rides/driver/assignment/claim-code',
        body: {'code': code.trim()},
      );
    } on ApiException catch (e, stack) {
      developer.log(
        'Assignment code claim failed: ${e.message}',
        name: 'DriverSession',
        error: e,
        stackTrace: stack,
      );
      throw ApiException(_assignmentCodeFailure(e), e.status, e.code);
    }
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

  Future<Map<String, dynamic>?> _fetchAssignedVehicle() async {
    assignedVehicleLoading = true;
    assignedVehicleLoaded = false;
    assignedVehicleError = null;
    _notify();
    try {
      final result = await api
          .request('GET', '/rides/driver/assigned-vehicle')
          .timeout(const Duration(seconds: 30));
      return result == null ? null : Map<String, dynamic>.from(result as Map);
    } on ApiException catch (e, stack) {
      if (e.code == 'NO_ASSIGNED_VEHICLE') return null;
      developer.log(
        'Assigned vehicle lookup failed: ${e.message}',
        name: 'DriverSession',
        error: e,
        stackTrace: stack,
      );
      assignedVehicleError =
          'We couldn\'t load your vehicle. Please try again.';
      return null;
    } on TimeoutException catch (e, stack) {
      developer.log(
        'Assigned vehicle lookup timed out',
        name: 'DriverSession',
        error: e,
        stackTrace: stack,
      );
      assignedVehicleError =
          'We couldn\'t load your vehicle. Please try again.';
      return null;
    } catch (e, stack) {
      developer.log(
        'Assigned vehicle lookup failed',
        name: 'DriverSession',
        error: e,
        stackTrace: stack,
      );
      assignedVehicleError =
          'We couldn\'t load your vehicle. Please try again.';
      return null;
    } finally {
      assignedVehicleLoading = false;
      assignedVehicleLoaded = true;
      _notify();
    }
  }

  String _assignmentCodeFailure(ApiException error) {
    final details = '${error.code ?? ''} ${error.message}'.toLowerCase();
    if (details.contains('expired') || error.status == 410) {
      return 'This vehicle code has expired. Request a new code from your Fleet Owner.';
    }
    if (details.contains('already_used') ||
        details.contains('already used') ||
        details.contains('claimed') ||
        details.contains('used')) {
      return 'This vehicle code has already been used. Request a new code from your Fleet Owner.';
    }
    if (details.contains('unavailable') ||
        details.contains('not_found') ||
        error.status == 404) {
      return 'This vehicle code is unavailable. Request a new code from your Fleet Owner.';
    }
    if (details.contains('invalid') ||
        details.contains('incorrect') ||
        details.contains('code_not_valid')) {
      return 'This vehicle code is incorrect. Check it and try again.';
    }
    return 'We couldn\'t verify this vehicle code. Check it or request a new code.';
  }

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
  Future<void> _permission({bool retry = false}) async {
    final issue = await locationAccess.check(
      retry: retry,
      interactive: !restoring,
    );
    if (issue != null) throw ApiException(issue.message);
  }

  Future<void> locationAccessChanged(LocationAccessIssue? issue) async {
    if (_disposed || !authenticated || (!online && currentTrip == null)) {
      return;
    }
    if (issue != null) {
      _locationEpoch++;
      final positions = _positions;
      _positions = null;
      locationWarning = issue.message;
      _notify();
      await positions?.cancel();
      return;
    }

    final epoch = _locationEpoch;
    try {
      await _locationStart;
    } catch (_) {
      // An interrupted start can be retried once access is restored.
    }
    if (_disposed ||
        !authenticated ||
        (!online && currentTrip == null) ||
        epoch != _locationEpoch ||
        _positions != null) {
      return;
    }
    try {
      await _resumeLocation();
    } on ApiException catch (error) {
      if (api.accessToken == null) _clear();
      locationWarning = error.message;
    }
    _notify();
  }

  Future<bool> locate() => run(() async {
    await _permission(retry: true);
    position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 30),
      ),
    );
  });

  Future<void> _resumeLocation() async {
    try {
      await _startLocation();
    } catch (e) {
      // GPS is an operational capability, not proof that a restored login failed.
      // Keep authorization failures authoritative and surface local/GPS failures
      // on the authenticated trip screen with its existing retry control.
      if (e is ApiException && (e.status == 401 || e.status == 403)) rethrow;
      locationWarning = e is ApiException
          ? e.message
          : 'Location unavailable. Check GPS and permissions, then retry.';
    }
  }

  static const gpsInterval = Duration(
    milliseconds: int.fromEnvironment('GPS_SAMPLE_MS', defaultValue: 1000),
  );
  static const publishInterval = Duration(
    milliseconds: int.fromEnvironment('GPS_PUBLISH_MS', defaultValue: 1000),
  );
  DateTime? _lastPublishAttempt;

  Future<void>? _locationStart;
  Future<void> _startLocation({bool retry = false}) {
    if (_positions != null) return Future.value();
    return _locationStart ??= _startLocationOnce(retry: retry)
        .whenComplete(() => _locationStart = null);
  }

  Future<void> _startLocationOnce({required bool retry}) async {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        (lifecycle == AppLifecycleState.paused ||
            lifecycle == AppLifecycleState.detached)) {
      return;
    }

    await _permission(retry: retry);
    final epoch = _locationEpoch;
    final fix = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 30),
      ),
    );
    if (_disposed || !authenticated || epoch != _locationEpoch) {
      throw const ApiException('Location access changed. Try again.');
    }
    position = fix;
    try {
      await _sendLocation(fix, preferRest: true);
    } on ApiException catch (e) {
      if (e.status == 401 || e.status == 403) rethrow;
      // Cached fixes can survive a process restart while the server already
      // has a newer sample. A rejected/noisy initial fix must not prevent the
      // stream from delivering subsequent valid fixes, including after outages.
      _lastLocationSampleSent = position!.timestamp;
      if (e.code == 'DRIVER_LOCATION_OUT_OF_ORDER' ||
          e.code == 'DRIVER_LOCATION_STALE') {
        locationWarning = 'Waiting for a newer GPS sample.';
      } else {
        locationWarning = e.message;
      }
    }
    await _positions?.cancel();
    if (_disposed || !authenticated || epoch != _locationEpoch) {
      throw const ApiException('Location access changed. Try again.');
    }
    _positions =
        Geolocator.getPositionStream(
          locationSettings: defaultTargetPlatform == TargetPlatform.iOS
              ? AppleSettings(
                  accuracy: LocationAccuracy.high,
                  distanceFilter: 0,
                  activityType: ActivityType.automotiveNavigation,
                  pauseLocationUpdatesAutomatically: false,
                  showBackgroundLocationIndicator: true,
                  allowBackgroundLocationUpdates: true,
                )
              : AndroidSettings(
                  accuracy: LocationAccuracy.high,
                  distanceFilter: 0,
                  intervalDuration: gpsInterval,
                  foregroundNotificationConfig:
                      const ForegroundNotificationConfig(
                        notificationTitle: 'Infurnus driver location',
                        notificationText: 'Sharing your location while online or on an active ride.',
                        notificationChannelName: 'Active ride location',
                        setOngoing: true,
                        enableWakeLock: true,
                      ),
                ),
        ).listen(
          (p) {
            position = p;
            _notify();
            unawaited(_locationUpdate(p));
          },
          onError: (_) {
            final failed = _positions;
            _positions = null;
            unawaited(failed?.cancel());
            locationWarning =
                'Location tracking stopped. Check GPS and permissions.';
            _notify();
          },
        );
  }

  Future<void> _locationUpdate(Position p) async {
    // Sampling and delivery have independent clocks. A blocked delivery never queues old fixes.
    if (_sendingLocation ||
        !authenticated ||
        p.accuracy > 200 ||
        (_lastLocationSampleSent != null &&
            !p.timestamp.isAfter(_lastLocationSampleSent!))) {
      return;
    }
    final now = DateTime.now();
    if (_lastPublishAttempt != null &&
        now.difference(_lastPublishAttempt!) < publishInterval) {
      return;
    }
    _lastPublishAttempt = now;
    _sendingLocation = true;
    try {
      await _sendLocation(p);
    } catch (e) {
      locationWarning = e is ApiException ? e.message : userSafeErrorMessage(e);
      if (api.accessToken == null) _clear();
    } finally {
      _sendingLocation = false;
      _notify();
    }
  }

  Future<void> _sendLocation(Position p, {bool preferRest = false}) async {
    if (_lastLocationSampleSent != null &&
        !p.timestamp.isAfter(_lastLocationSampleSent!)) {
      return;
    }
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
    if (!preferRest && _socket?.connected == true && currentTrip != null) {
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
        final error = response is Map ? response['error'] : null;
        final code = error is Map ? error['code'] : null;
        final message = error is Map ? error['message'] : null;
        if (code == null || code == 'DRIVER_LOCATION_FORBIDDEN') {
          // Older servers collapse GPS validation errors into this generic
          // socket reply. The authenticated HTTP endpoint applies the same
          // location checks and returns the actionable reason. It also
          // broadcasts accepted fixes; never mark a rejected fix delivered.
          await api.request('POST', '/rides/driver/location', body: payload);
        } else {
          throw ApiException(
            message is String && message.isNotEmpty ? message : 'Live location was not accepted. Waiting for a fresh GPS fix.',
            null,
            code is String ? code : null,
          );
        }
      }
    } else {
      await api.request('POST', '/rides/driver/location', body: payload);
    }
    _lastLocationSampleSent = p.timestamp;
    lastLocationSent = DateTime.now();
    locationWarning = null;
  }

  Future<bool> setOnline(bool value) => run(() async {
    if (value == online) return;
    if (isPreview) {
      profile?['onlinePreference'] = value;
      profile?['availabilityStatus'] = value ? 'available' : 'unavailable';
      return;
    }
    if (value && !operationalAllowed) {
      throw const ApiException(
        'Complete backend approval and vehicle assignment before going online.',
      );
    }
    if (value) await _startLocation(retry: true);
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
    profile?['onlinePreference'] = value;
    if (!value && currentTrip == null) {
      await _positions?.cancel();
      _positions = null;
    }
    await _load();
  });

  Future<bool> accept(String id) => run(() async {
    dismissRideNotifications();
    final bridge = RideRequestBridge();
    unawaited(bridge.dismissOffer(id, invalidate: false));
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
    final received = DateTime.tryParse(offer['_receivedAt']?.toString() ?? '');
    final serverTime = DateTime.tryParse(offer['serverTime']?.toString() ?? '');
    final offerNow = received != null && serverTime != null
        ? serverTime.add(DateTime.now().difference(received))
        : DateTime.now();
    if (expiry != null && !expiry.isAfter(offerNow)) {
      throw const ApiException('This offer has expired. Refresh the offers.');
    }
    await api.request('POST', '/rides/${Uri.encodeComponent(id)}/accept');
    await bridge.dismissOffer(id);
    await _load();
  });
  Future<bool> decline(String id) => run(() async {
    dismissRideNotifications();
    final bridge = RideRequestBridge();
    unawaited(bridge.dismissOffer(id, invalidate: false));
    if (isPreview) {
      rides.removeWhere((r) => r['id'] == id);
      return;
    }
    await api.request(
      'POST',
      '/rides/driver/available/${Uri.encodeComponent(id)}/decline',
    );
    await bridge.dismissOffer(id);
    await _load();
  });
  Future<bool> transition(String status, {String? pin, String? endPin}) => run(() async {
    if (currentTrip == null) throw const ApiException('No active trip.');
    if (isPreview) {
      if (status == 'completed') {
        if (currentTrip?['sector'] == 'logistics' &&
            (endPin == null || !RegExp(r'^\d{4}$').hasMatch(endPin))) {
          throw const ApiException(
            'Enter the customer’s four-digit Delivery PIN to complete the trip.',
          );
        }
        _setCurrentTrip(null);
      } else {
        if (status == 'in_progress' &&
            currentTrip?['sector'] == 'logistics' &&
            currentTrip?['upfrontPaymentStatus'] != 'PAID_VERIFIED') {
          throw const ApiException(
            'Logistics bookings require 40% upfront payment verification (ONLINE or CASH confirmation) before starting the ride.',
          );
        }
        currentTrip?['status'] = status;
      }
      return;
    }
    final id = Uri.encodeComponent(currentTrip!['id'] as String);
    if (status == 'completed') {
      if (currentTrip?['sector'] == 'logistics' &&
          (endPin == null || !RegExp(r'^\d{4}$').hasMatch(endPin))) {
        throw const ApiException(
          'Enter the customer’s four-digit Delivery PIN to complete the trip.',
        );
      }
      await api.request(
        'POST',
        '/rides/$id/complete',
        body: endPin != null ? {'endPin': endPin} : null,
      );
    } else if (status == 'in_progress') {
      if (currentTrip?['sector'] == 'logistics' &&
          currentTrip?['upfrontPaymentStatus'] != 'PAID_VERIFIED') {
        throw const ApiException(
          'Logistics bookings require 40% upfront payment verification (ONLINE or CASH confirmation) before starting the ride.',
        );
      }
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
      _setCurrentTrip(ride);
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

  bool _setCurrentTrip(Map? snapshot) {
    final previous = currentTrip;
    final next = snapshot == null ? null : Map<String, dynamic>.from(snapshot);
    if (previous?['id'] != next?['id']) {
      _invalidateCustomerContact();
      _navigationUpdate = null;
      paymentRefreshError = null;
    } else if (next != null &&
        next['bookingId'] == null &&
        previous?['bookingId'] != null) {
      next['bookingId'] = previous!['bookingId'];
    }
    if (jsonEncode(previous) == jsonEncode(next)) return false;
    currentTrip = next;
    return true;
  }

  Future<void> _ensureCustomerContact() async {
    if (!canRequestCustomerContact) {
      _invalidateCustomerContact();
    } else if (activeCustomerContact == null) {
      await refreshCustomerContact();
    }
  }

  Future<bool> _refreshActiveTrip() {
    if (_activeTripRequest case final pending?) return pending;
    final id = currentTrip?['id'];
    if (_disposed || !authenticated || id is! String || busy) {
      return Future.value(false);
    }
    final generation = _tripGeneration;
    final request = _fetchActiveTrip(id, api.userId, generation);
    _activeTripRequest = request;
    return request;
  }

  Future<bool> _fetchActiveTrip(
    String id,
    String? userId,
    int generation,
  ) async {
    bool stillCurrent() =>
        !_disposed &&
        authenticated &&
        api.userId == userId &&
        currentTrip?['id'] == id &&
        _tripGeneration == generation;
    try {
      final snapshot = await api.request('GET', '/rides/driver/current-trip');
      if (!stillCurrent() ||
          (snapshot != null &&
              (snapshot is! Map || snapshot['id'] is! String))) {
        return false;
      }
      if (snapshot is Map && snapshot['sector'] == 'logistics') {
        final existingMethod =
            snapshot['upfrontPaymentMethod'] ??
            currentTrip?['upfrontPaymentMethod'];
        if (existingMethod != null) {
          snapshot['upfrontPaymentMethod'] = existingMethod;
        } else {
          try {
            final summary = await _logisticsPaymentSummary(
              snapshot['id'].toString(),
            );
            final payments = summary['payments'];
            if (payments is List) {
              final upfront = payments.whereType<Map>().firstWhere(
                (p) => p['paymentStage'] == 'upfront',
                orElse: () => <String, dynamic>{},
              );
              if (upfront['provider'] != null) {
                snapshot['upfrontPaymentMethod'] = upfront['provider']
                    .toString()
                    .toLowerCase();
              }
            }
          } catch (_) {}
        }
      }
      final changed = _setCurrentTrip(snapshot as Map?);
      _joinTrip();
      if (currentTrip == null && !online) {
        final positions = _positions;
        _positions = null;
        await positions?.cancel();
      }
      if (changed) _notify();
      unawaited(_ensureCustomerContact());
      return true;
    } on ApiException catch (e) {
      if (!_disposed &&
          _tripGeneration == generation &&
          api.accessToken == null &&
          _accountVerified) {
        _clear();
        _notify();
      } else if (stillCurrent() && const [401, 403].contains(e.status)) {
        _invalidateCustomerContact();
        _notify();
      }
      return false;
    } finally {
      _activeTripRequest = null;
      _drainRideEventRefresh();
    }
  }

  Future<Map> _logisticsPaymentSummary(String rideId) async {
    final id = Uri.encodeComponent(rideId);
    final summary = await api.request('GET', '/payments/rides/$id/summary');
    if (summary is! Map || summary['rideId'] != rideId) {
      throw const ApiException('Payment status could not be verified.');
    }
    return summary;
  }

  Future<bool> confirmLogisticsUpfrontCash(String rideId) => run(() async {
    if (isPreview) {
      if (currentTrip?['id'] == rideId &&
          currentTrip?['sector'] == 'logistics') {
        currentTrip?['upfrontPaymentStatus'] = 'PAID_VERIFIED';
        currentTrip?['upfrontPaymentMethod'] = 'cash';
      }
      return;
    }
    final summary = await _logisticsPaymentSummary(rideId);
    final payments = summary['payments'];
    final claim = payments is List
        ? payments
              .whereType<Map>()
              .where(
                (payment) =>
                    payment['paymentStage'] == 'upfront' &&
                    payment['provider'] == 'cash' &&
                    payment['customerClaimedAt'] != null &&
                    payment['status'] != 'CAPTURED',
              )
              .firstOrNull
        : null;
    if (claim?['id'] is! String) {
      throw const ApiException(
        'The customer must submit the cash payment claim first.',
      );
    }
    final paymentId = Uri.encodeComponent(claim!['id'] as String);
    await api.request('POST', '/payments/$paymentId/capture', body: {});
    await _load();
  });

  Future<bool> payLogisticsUpfrontOnline(String rideId) async {
    if (busy ||
        paymentRefreshing ||
        currentTrip?['id'] != rideId ||
        currentTrip?['sector'] != 'logistics') {
      return false;
    }
    if (isPreview) {
      currentTrip?['upfrontPaymentStatus'] = 'PAID_VERIFIED';
      currentTrip?['upfrontPaymentMethod'] = 'online';
      _notify();
      return true;
    }
    paymentRefreshing = true;
    paymentRefreshError = null;
    _notify();
    try {
      final updated = await _refreshActiveTrip();
      if (currentTrip?['id'] != rideId) return false;
      if (!updated) {
        paymentRefreshError = 'Could not refresh payment status. Try again.';
      } else if (currentTrip?['upfrontPaymentStatus'] != 'PAID_VERIFIED') {
        paymentRefreshError =
            'Waiting for the customer’s verified upfront payment.';
      }
      return updated && currentTrip?['upfrontPaymentStatus'] == 'PAID_VERIFIED';
    } finally {
      paymentRefreshing = false;
      _notify();
    }
  }

  static const _rideEvents = {
    'ride:incoming',
    'ride:taken',
    'ride:driver_assigned',
    'ride:lifecycle_updated',
    'ride:completed',
    'ride:cancelled',
    'ride:route_updated',
  };

  /// Socket and push messages are invalidation hints; the authenticated API
  /// remains authoritative. Coalesce events arriving during another operation.
  void handleRideEvent(String event, dynamic payload) {
    if (_disposed ||
        !authenticated ||
        !_rideEvents.contains(event) ||
        payload is! Map) {
      return;
    }
    final ride = payload['ride'];
    final id = payload['rideId'] ?? (ride is Map ? ride['id'] : null);
    if (id is! String || id.isEmpty) return;
    if (event == 'ride:route_updated') {
      final segment = currentTrip?['status'] == 'in_progress'
          ? 'destination'
          : 'pickup';
      final version = payload['routeVersion'];
      if (id == currentTrip?['id'] &&
          payload['segment'] == segment &&
          payload['route'] is Map &&
          version is num &&
          (_navigationUpdate?['segment'] != segment ||
              version > (_navigationUpdate?['routeVersion'] as num? ?? -1))) {
        _navigationUpdate = Map<String, dynamic>.from(payload);
        _notify();
      }
      return;
    }
    if (const [
      'ride:taken',
      'ride:cancelled',
      'ride:driver_assigned',
      'ride:completed',
    ].contains(event)) {
      unawaited(RideRequestBridge().dismissOffer(id));
      dismissRideNotifications();
    }
    if (currentTrip != null && id != currentTrip?['id']) return;
    if (id == currentTrip?['id'] &&
        const ['ride:cancelled', 'ride:completed'].contains(event)) {
      _invalidateCustomerContact();
      _notify();
    }
    _rideEventRefreshPending = true;
    _drainRideEventRefresh();
  }

  void _drainRideEventRefresh() {
    if (!_rideEventRefreshPending ||
        busy ||
        _activeTripRequest != null ||
        _disposed ||
        !authenticated) {
      return;
    }
    _rideEventRefreshPending = false;
    unawaited(currentTrip == null ? refresh() : _refreshActiveTrip());
  }

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
      _joinedTripId = null;
      realtimeStatus = 'Connected';
      _joinTrip();
      _notify();
      // Reconcile missed events with the authoritative API after reconnecting.
      _rideEventRefreshPending = true;
      _drainRideEventRefresh();
    });
    _socket!.onDisconnect((_) {
      realtimeStatus = 'Disconnected';
      _joinedTripId = null;
      _notify();
    });
    _socket!.onConnectError((_) {
      realtimeStatus = 'Connection failed';
      _notify();
    });
    for (final event in _rideEvents) {
      _socket!.on(event, (payload) => handleRideEvent(event, payload));
    }
    _socket!.connect();
    _expiry?.cancel();
    // Rotate session periodically as well as on HTTP 401 so socket handshakes
    // reconnect with refreshed access tokens instead of retrying expired ones.
    _expiry = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!busy && authenticated) {
        if (currentTrip != null) {
          unawaited(_renewActiveTripSocket());
          return;
        }
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

  Future<void> _renewActiveTripSocket() async {
    final generation = _tripGeneration;
    final userId = api.userId;
    try {
      await api.refreshSession();
      if (!_disposed &&
          authenticated &&
          api.userId == userId &&
          _socket?.auth['token'] != api.accessToken) {
        _connect();
      }
    } on ApiException {
      if (!_disposed &&
          generation == _tripGeneration &&
          api.accessToken == null &&
          _accountVerified) {
        _clear();
        _notify();
      }
    }
  }

  void _joinTrip() {
    final id = currentTrip?['id'];
    final socket = _socket;
    if (id is String && id != _joinedTripId && socket?.connected == true) {
      _joinedTripId = id;
      socket!.emitWithAck(
        'ride:join',
        id,
        ack: (dynamic response) {
          if (_socket == socket &&
              currentTrip?['id'] == id &&
              response is Map &&
              response['success'] == false) {
            _joinedTripId = null;
            _invalidateCustomerContact();
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
    } finally {
      try {
        await api.logout();
      } finally {
        _clear();
      }
    }
  });
  void _clear({bool persist = true}) {
    _locationEpoch++;
    todaySummary = null;
    todaySummaryError = null;
    driverPhotoUrl = null;
    _photoDocumentId = null;
    _photoValidUntil = null;
    unawaited(RideRequestBridge().clear());
    _invalidateCustomerContact();
    _notifications?.dispose();
    _notifications = null;
    pendingNotificationRoute = null;
    _rideEventRefreshPending = false;
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
    providerAccount = null;
    assignmentPreview = null;
    documents = [];
    partnerDocuments = [];
    approvals = [];
    applications = [];
    documentRules = [];
    documentPages.clear();
    signupId = null;
    verificationContact = null;
    verificationResendAt = null;
    profile = null;
    _setCurrentTrip(null);
    assignedVehicle = null;
    assignedVehicleLoading = false;
    assignedVehicleLoaded = false;
    assignedVehicleError = null;
    history = null;
    historyLimit = 20;
    rides = [];
    challengeId = null;
    position = null;
    lastLocationSent = null;
    _lastLocationSampleSent = null;
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
