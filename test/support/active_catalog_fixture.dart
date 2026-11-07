import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Upgrade older positive catalog fixtures to the active-selection API contract.
/// Explicit inactive/hidden flags are preserved for negative test cases.
http.Client activeCatalogClient(
  Future<http.Response> Function(http.Request) handler,
) => MockClient((request) async {
  final response = await handler(request);
  if (request.method != 'GET' ||
      !request.url.path.endsWith('/vehicle-catalog') ||
      response.statusCode < 200 ||
      response.statusCode >= 300) {
    return response;
  }
  final envelope = jsonDecode(response.body) as Map<String, dynamic>;
  final data = envelope['data'];
  if (data is! Map || data['types'] is! List) return response;
  envelope['data'] = {
    ...data,
    'selectionCatalogVersion': data['selectionCatalogVersion'] ?? 2,
    'sectors':
        data['sectors'] ?? ['passenger', 'logistics', 'service', 'premium'],
    'types': (data['types'] as List)
        .cast<Map>()
        .map(
          (type) => {
            'active': true,
            'catalogVisible': true,
            'registrationActive': true,
            ...type,
          },
        )
        .toList(),
  };
  return http.Response(
    jsonEncode(envelope),
    response.statusCode,
    headers: response.headers,
  );
});
