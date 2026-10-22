import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_service.dart';

/// An uncertain request is retried with the same amount and idempotency key,
/// including after restart. Never report bank disbursement from this response.
class PayoutRequest {
  final ApiService api;
  final FlutterSecureStorage storage;
  PayoutRequest(this.api, {this.storage = const FlutterSecureStorage()});
  String get _key => 'pending_payout_${api.userId}';
  Future<Map<String, dynamic>?> pending() async {
    final value = await storage.read(key: _key);
    return value == null
        ? null
        : Map<String, dynamic>.from(jsonDecode(value) as Map);
  }

  Future<dynamic> submit(int amountPaise) async {
    if (api.userId == null || api.accessToken == null) {
      throw const ApiException('Sign in before requesting a payout.');
    }
    var draft = await pending();
    if (draft != null && draft['amountPaise'] != amountPaise) {
      throw const ApiException(
        'Retry the pending payout with its original amount before creating another request.',
      );
    }
    draft ??= {
      'amountPaise': amountPaise,
      'idempotencyKey': List.generate(
        24,
        (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join(),
    };
    await storage.write(key: _key, value: jsonEncode(draft));
    dynamic result;
    try {
      result = await api.request('POST', '/provider/payouts', body: draft);
    } on ApiException catch (e) {
      // Definitive validation/authorization rejection cannot have created a payout.
      if ([400, 401, 403, 404, 409, 422].contains(e.status)) {
        await storage.delete(key: _key);
      }
      rethrow;
    }
    await storage.delete(key: _key);
    return result;
  }
}
