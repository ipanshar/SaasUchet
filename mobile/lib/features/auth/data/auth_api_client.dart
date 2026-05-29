import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:saas_uchet_mobile/core/config/api_config.dart';
import 'package:saas_uchet_mobile/core/network/api_exception.dart';
import 'package:saas_uchet_mobile/features/auth/domain/auth_gateway.dart';
import 'package:saas_uchet_mobile/features/auth/domain/auth_session.dart';
import 'package:saas_uchet_mobile/features/auth/domain/user_profile.dart';

class AuthApiClient extends AuthGateway {
  AuthApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  @override
  Future<AuthSession> register({
    required String fullName,
    required String phone,
    required String password,
  }) async {
    final response = await _client
        .post(
          ApiConfig.authRegisterUri,
          headers: _jsonHeaders,
          body: jsonEncode({
            'full_name': fullName,
            'phone': phone,
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 8));

    return _decodeSession(response);
  }

  @override
  Future<AuthSession> login({
    required String phone,
    required String password,
  }) async {
    final response = await _client
        .post(
          ApiConfig.authLoginUri,
          headers: _jsonHeaders,
          body: jsonEncode({
            'phone': phone,
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 8));

    return _decodeSession(response);
  }

  @override
  Future<UserProfile> fetchProfile({
    required String accessToken,
  }) async {
    final response = await _client
        .get(
          ApiConfig.profileUri,
          headers: _authorizedHeaders(accessToken),
        )
        .timeout(const Duration(seconds: 8));

    return _decodeUser(response);
  }

  @override
  Future<UserProfile> updateProfile({
    required String accessToken,
    required String fullName,
    required String phone,
    String? password,
  }) async {
    final payload = <String, dynamic>{
      'full_name': fullName,
      'phone': phone,
    };
    if (password != null && password.isNotEmpty) {
      payload['password'] = password;
    }

    final response = await _client
        .put(
          ApiConfig.profileUri,
          headers: _authorizedHeaders(accessToken),
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));

    return _decodeUser(response);
  }

  @override
  Future<void> deleteProfile({
    required String accessToken,
  }) async {
    final response = await _client
        .delete(
          ApiConfig.profileUri,
          headers: _authorizedHeaders(accessToken),
        )
        .timeout(const Duration(seconds: 8));

    if (response.statusCode == 204) {
      return;
    }

    throw _buildApiException(response);
  }

  @override
  void dispose() {
    _client.close();
  }

  AuthSession _decodeSession(http.Response response) {
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw _buildApiException(response);
    }

    return AuthSession.fromJson(_decodeJsonMap(response));
  }

  UserProfile _decodeUser(http.Response response) {
    if (response.statusCode != 200) {
      throw _buildApiException(response);
    }

    return UserProfile.fromJson(_decodeJsonMap(response));
  }

  Map<String, dynamic> _decodeJsonMap(http.Response response) {
    final decodedBody = jsonDecode(response.body);
    if (decodedBody is! Map<String, dynamic>) {
      throw const ApiException(
        message: 'API returned an unexpected response.',
        statusCode: 500,
      );
    }

    return decodedBody;
  }

  ApiException _buildApiException(http.Response response) {
    try {
      final decodedBody = _decodeJsonMap(response);
      final message = decodedBody['error'] as String? ??
          'API request failed with ${response.statusCode}.';

      return ApiException(
        message: message,
        statusCode: response.statusCode,
      );
    } catch (_) {
      return ApiException(
        message: 'API request failed with ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }
  }

  Map<String, String> _authorizedHeaders(String accessToken) {
    return {
      ..._jsonHeaders,
      'Authorization': 'Bearer $accessToken',
    };
  }
}

const Map<String, String> _jsonHeaders = {
  'Content-Type': 'application/json; charset=utf-8',
};
