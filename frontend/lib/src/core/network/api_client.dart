import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? status;
  const ApiException(this.message, {this.status});

  @override
  String toString() => message;
}

/// Cliente HTTP único: envia o token e converte erros em mensagens legíveis.
class ApiClient {
  ApiClient._();

  static String? token;
  static VoidCallback? onUnauthorized;
  static http.Client client = http.Client();

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (token != null) 'Authorization': 'Bearer $token',
  };

  static Future<Map<String, dynamic>> get(String url, {Map<String, String>? query}) =>
      _send(() => client.get(Uri.parse(url).replace(queryParameters: query), headers: _headers));

  static Future<Map<String, dynamic>> post(
    String url, [
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 15),
  ]) => _send(
    () => client.post(Uri.parse(url), headers: _headers, body: jsonEncode(body ?? const {})),
    timeout: timeout,
  );

  static Future<Map<String, dynamic>> put(String url, Map<String, dynamic> body) =>
      _send(() => client.put(Uri.parse(url), headers: _headers, body: jsonEncode(body)));

  static Future<Map<String, dynamic>> delete(String url) =>
      _send(() => client.delete(Uri.parse(url), headers: _headers));

  /// Envia arquivos em multipart. Usa bytes para funcionar na web e no celular.
  static Future<Map<String, dynamic>> upload(String url, List<http.MultipartFile> files) => _send(() async {
    final request = http.MultipartRequest('POST', Uri.parse(url))..files.addAll(files);
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    return http.Response.fromStream(await client.send(request));
  }, timeout: const Duration(seconds: 60));

  static Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final http.Response response;
    final Map<String, dynamic> data;
    try {
      response = await request().timeout(timeout);
      data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw const ApiException('Não foi possível falar com o servidor. Verifique sua conexão.');
    }

    if (response.statusCode >= 200 && response.statusCode < 300 && data['sucesso'] == true) {
      return data;
    }
    if (response.statusCode == 401 && token != null) onUnauthorized?.call();
    throw ApiException(data['mensagem'] as String? ?? 'Algo deu errado. Tente novamente.', status: response.statusCode);
  }
}
