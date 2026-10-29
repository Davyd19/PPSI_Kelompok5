import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/demo_profile.dart';

class DemoApi {
  DemoApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl =
          baseUrl ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'http://10.0.2.2:3000/api/v1',
          );
  final http.Client _client;
  final String baseUrl;
  Future<dynamic> _get(String path) async {
    try {
      final response = await _client
          .get(Uri.parse('${baseUrl.replaceFirst(RegExp(r'/+$'), '')}$path'))
          .timeout(const Duration(seconds: 8));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200) {
        throw DemoApiException(
          (body['error'] as Map<String, dynamic>?)?['message'] as String? ??
              'Permintaan gagal.',
        );
      }
      return body['data'];
    } on DemoApiException {
      rethrow;
    } on TimeoutException {
      throw const DemoApiException('API tidak merespons. Coba lagi.');
    } catch (_) {
      throw const DemoApiException(
        'API tidak dapat dihubungi. Periksa backend dan API_BASE_URL.',
      );
    }
  }

  Future<List<DemoProfile>> profiles() async =>
      (await _get('/demo/profiles') as List)
          .map((p) => DemoProfile.fromJson(p as Map<String, dynamic>))
          .where((p) => p.platform == 'mobile')
          .toList();
  Future<Map<String, dynamic>> dashboard(String role) async =>
      await _get('/demo/dashboard?role=${Uri.encodeQueryComponent(role)}')
          as Map<String, dynamic>;
  void close() => _client.close();
}

class DemoApiException implements Exception {
  const DemoApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
