import 'package:flutter/foundation.dart';

import '../models/onboarding_rules.dart';
import '../models/provider_status.dart';
import '../services/api_service.dart';

/// Uses the authenticated account's existing provider/partner contracts.
class ProviderAssets extends ChangeNotifier {
  final ApiService api;
  ProviderAssets(this.api);
  Map<String, dynamic>? partner;
  List<Map<String, dynamic>> vehicles = [],
      documents = [],
      approvals = [],
      drivers = [],
      tracking = [];
  List<Map<String, dynamic>> invitations = [];
  List<DocumentRule> rules = [];
  Map<String, dynamic>? earnings;
  bool busy = false, loaded = false, _disposed = false;
  String? error, refreshWarning;
  String get vehiclePath =>
      api.hasFleetRole && api.providerMode == 'fleet_owner'
      ? '/fleet/vehicles'
      : '/partners/vehicles';
  bool get approvedPartner =>
      providerStatus(partner?['approvalStatus']) == ProviderStatus.approved;
  bool get fleetMode => api.hasFleetRole && api.providerMode == 'fleet_owner';
  List<Map<String, dynamic>> _rows(dynamic value) =>
      (value as List).map((v) => Map<String, dynamic>.from(v as Map)).toList();
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<bool> run(Future<void> Function() action) async {
    if (busy) return false;
    busy = true;
    error = null;
    _notify();
    try {
      await action();
      return true;
    } catch (e) {
      error = e is ApiException
          ? e.message
          : 'Unable to complete the action. Please retry.';
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<bool> refresh() => run(() async {
    await load();
    refreshWarning = null;
  });
  Future<void> _reloadAfterSave() async {
    try {
      await load();
      refreshWarning = null;
    } on ApiException catch (e) {
      if (e.status == 401 || e.status == 403) rethrow;
      refreshWarning =
          'Saved on the server. Refresh to load the latest status.';
      error = refreshWarning;
    }
  }

  Future<List<Map<String, dynamic>>> _fleetPages(String path) async {
    final result = <Map<String, dynamic>>[];
    for (var offset = 0; offset <= 100000; offset += 100) {
      final page = _rows(
        await api.request('GET', '$path?limit=100&offset=$offset'),
      );
      result.addAll(page);
      if (page.length < 100) return result;
    }
    throw const ApiException('Too many Fleet records. Narrow the selection.');
  }

  Future<void> load() async {
    Map<String, dynamic>? nextPartner;
    try {
      nextPartner = Map<String, dynamic>.from(
        await api.request('GET', '/partners/me') as Map,
      );
    } on ApiException catch (e) {
      if (e.status != 404 || e.code != 'PARTNER_NOT_FOUND') rethrow;
    }
    final nextDocuments = nextPartner == null
        ? <Map<String, dynamic>>[]
        : _rows(
            await api.request(
              'GET',
              '/partners/${nextPartner['id']}/documents',
            ),
          );
    final nextApprovals = _rows(
      await api.request('GET', '/provider/approvals'),
    );
    final nextVehicles = (fleetMode || nextPartner != null)
        ? (fleetMode
              ? await _fleetPages(vehiclePath)
              : _rows(await api.request('GET', vehiclePath)))
        : <Map<String, dynamic>>[];
    final nextRules = <String, DocumentRule>{};
    // Category-specific policies are evaluated separately by the document UI.
    final policy = _rows(
      await api.request('GET', '/provider/document-requirements?category=*'),
    );
    for (final row in policy) {
      final r = DocumentRule.fromJson(row);
      nextRules[r.code] = r;
    }
    if (fleetMode && api.roleFlowEnabled) {
      invitations = _rows(await api.request('GET', '/provider/fleet-drivers'));
    }
    partner = nextPartner;
    documents = nextDocuments;
    approvals = nextApprovals;
    vehicles = nextVehicles;
    rules = nextRules.values.toList();
    if (fleetMode && approvedPartner) {
      drivers = await _fleetPages('/fleet/drivers');
      tracking = _rows(await api.request('GET', '/provider/tracking'));
    } else {
      drivers = [];
      tracking = [];
    }
    earnings = fleetMode
        ? Map<String, dynamic>.from(
            await api.request('GET', '/provider/earnings') as Map,
          )
        : null;
    loaded = true;
  }

  Future<List<DocumentRule>> vehicleRules(Map<String, dynamic> vehicle) async {
    final rows = _rows(
      await api.request(
        'GET',
        '/provider/document-requirements?category=${Uri.encodeQueryComponent(vehicle['category'] as String)}',
      ),
    );
    final merged = <String, DocumentRule>{};
    for (final row in rows) {
      final rule = DocumentRule.fromJson(row),
          old = merged[row['document_code']];
      merged[rule.code] = DocumentRule(
        rule.code,
        required: rule.required || (old?.required ?? false),
        requiresExpiry: rule.requiresExpiry || (old?.requiresExpiry ?? false),
        collectionAuthorized: rule.collectionAuthorized,
        minimumPages: rule.minimumPages > (old?.minimumPages ?? 0)
            ? rule.minimumPages
            : old!.minimumPages,
      );
    }
    merged['vehicle_front_photo'] = const DocumentRule(
      'vehicle_front_photo',
      required: false,
    );
    for (final code in [
      'vehicle_rear_photo',
      'vehicle_left_photo',
      'vehicle_right_photo',
    ]) {
      merged.putIfAbsent(code, () => DocumentRule(code));
    }
    return merged.values.toList();
  }

  Future<bool> saveBusiness(Map<String, dynamic> input) => run(() async {
    if (partner == null) {
      final saved = await api.request(
        'POST',
        '/partners',
        body: {...input, 'userId': api.userId},
      );
      if (saved is Map && saved['id'] is String) {
        partner = Map<String, dynamic>.from(saved);
      }
    } else {
      await api.request('PATCH', '/partners/${partner!['id']}', body: input);
    }
    await _reloadAfterSave();
  });
  Future<bool> saveVehicle(Map<String, dynamic> input, {String? id}) =>
      run(() async {
        final saved = await api.request(
          id == null ? 'POST' : 'PUT',
          id == null ? vehiclePath : '$vehiclePath/${Uri.encodeComponent(id)}',
          body: input,
        );
        if (saved is Map && saved['id'] is String) {
          final row = Map<String, dynamic>.from(saved);
          vehicles = [...vehicles.where((v) => v['id'] != row['id']), row];
        }
        await _reloadAfterSave();
      });
  Future<bool> requestReview(
    String targetType,
    String targetId,
    String requestType,
  ) => run(() async {
    await api.request(
      'POST',
      '/provider/approval-requests',
      body: {
        'targetType': targetType,
        'targetId': targetId,
        'requestType': requestType,
      },
    );
    await load();
  });
  Map<String, dynamic>? documentFor(String code, {String? vehicleId}) {
    for (final d in documents) {
      if (d['vehicleId'] == vehicleId &&
          ((d['metadata'] as Map?)?['documentCode'] ??
                  d['documentType'].toString().toLowerCase()) ==
              code) {
        return d;
      }
    }
    return null;
  }

  final Map<String, Map<String, dynamic>> _uploadedDrafts = {};

  Future<bool> uploadDocument(
    DocumentRule rule,
    List<DocumentFile> files,
    Map<String, String> metadata, {
    String? vehicleId,
  }) => run(() async {
    if (partner == null) {
      throw const ApiException('Save your provider/business profile first.');
    }
    final validation = OnboardingRules.validateFiles(rule, files, metadata);
    if (validation != null) throw ApiException(validation);
    const types = {
      'aadhaar': 'AADHAAR',
      'pan': 'PAN',
      'driving_licence': 'DRIVING_LICENCE',
      'profile_photo': 'PROFILE_PHOTO',
      'address_proof': 'ADDRESS_PROOF',
      'vehicle_rc': 'VEHICLE_RC',
      'vehicle_insurance': 'VEHICLE_INSURANCE',
      'vehicle_permit': 'VEHICLE_PERMIT',
      'vehicle_fitness': 'VEHICLE_FITNESS',
      'vehicle_puc': 'VEHICLE_PUC',
    };
    final type = types[rule.code] ?? 'OTHER';
    if (type.startsWith('VEHICLE_') && vehicleId == null) {
      throw const ApiException('Select the owned vehicle for this document.');
    }
    final existing = documentFor(rule.code, vehicleId: vehicleId);
    final bundle = files.length > 1;
    final path =
        '/partners/${partner!['id']}/documents/${existing == null ? 'upload' : '${existing['id']}/replace'}${bundle ? '/pages' : ''}';
    final draftKey =
        '$vehicleId:${rule.code}:${Object.hashAll(files.map((f) => Object.hash(f.name, Object.hashAll(f.bytes))))}:${metadata.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final uploaded =
        _uploadedDrafts[draftKey] ??
        await api.request(
          'POST',
          path,
          files: files,
          fileField: bundle ? 'files' : 'file',
          fields: {
            ...metadata,
            if (existing == null) 'documentType': type,
            if (existing == null && vehicleId != null) 'vehicleId': vehicleId,
            if (type == 'OTHER') 'documentCode': rule.code,
          },
        );
    _uploadedDrafts[draftKey] = Map<String, dynamic>.from(uploaded as Map);
    // SUBMITTED is an owner-permitted lifecycle transition; VERIFIED is not.
    await api.request(
      'PATCH',
      '/partners/${partner!['id']}/documents/${uploaded['id']}',
      body: {'status': 'SUBMITTED'},
    );
    await api.request(
      'POST',
      '/provider/approval-requests',
      body: {
        'targetType': 'partner_document',
        'targetId': uploaded['id'],
        'requestType': 'document_reverification',
      },
    );
    _uploadedDrafts.remove(draftKey);
    await _reloadAfterSave();
  });
  Future<Map<String, dynamic>?> assignmentCode(
    String vehicleId,
    String? driverProfileId,
  ) async {
    Map<String, dynamic>? code;
    await run(() async {
      code = Map<String, dynamic>.from(
        await api.request(
          'POST',
          '/fleet/vehicles/$vehicleId/assignment-code',
          body: {'driverProfileId': ?driverProfileId},
        ) as Map,
      );
    });
    return code;
  }

  Future<bool> unassign(String id) => run(() async {
    await api.request('POST', '/fleet/vehicles/$id/unassign');
    await load();
  });
  Future<bool> removeDraftDocument(String id) => run(() async {
    await api.request(
      'DELETE',
      '/partners/${partner!['id']}/documents/${Uri.encodeComponent(id)}',
    );
    await load();
  });
  Future<bool> operate(String id, String status) => run(() async {
    await api.request(
      'PATCH',
      '/provider/vehicles/$id/operation',
      body: {'operationalStatus': status},
    );
    await load();
  });
  Future<bool> deactivateMembership(String id) => run(() async {
    await api.request(
      'PATCH',
      '/provider/drivers/$id/membership',
      body: {'status': 'INACTIVE'},
    );
    await load();
  });
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
