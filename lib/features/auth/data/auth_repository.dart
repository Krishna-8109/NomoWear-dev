import 'package:flutter/foundation.dart';
import 'package:nomowear/core/network/api_client.dart';
import 'package:nomowear/core/network/api_constants.dart';
import 'package:nomowear/core/network/api_exception.dart';
import 'package:nomowear/features/auth/data/models/customer.dart';
import 'package:nomowear/features/auth/data/models/login_session.dart';
import 'package:nomowear/features/auth/data/models/resend_otp_result.dart';
import 'package:nomowear/features/auth/data/models/verify_otp_result.dart';

class AuthRepository {
  final ApiClient _apiClient;

  AuthRepository({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<LoginSession> login(String mobileNumber) async {
    final json = await _apiClient.post(
      ApiConstants.loginPath,
      {'mobileNumber': mobileNumber},
    );

    if (json['success'] != true) {
      throw ApiException(
        json['message']?.toString() ?? 'Failed to send OTP',
      );
    }

    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const ApiException('Invalid login response');
    }

    final customerId = data['customerId']?.toString();
    final userToken = data['userToken']?.toString();
    if (customerId == null ||
        customerId.isEmpty ||
        userToken == null ||
        userToken.isEmpty) {
      throw const ApiException('Invalid login response');
    }

    return LoginSession(
      customerId: customerId,
      userToken: userToken,
      mobileNumber: mobileNumber,
    );
  }

  Future<ResendOtpResult> resendOtp(String mobileNumber) async {
    final json = await _apiClient.post(
      ApiConstants.resendOtpPath,
      {'mobileNumber': mobileNumber},
    );

    if (json['success'] != true) {
      throw ApiException(
        json['message']?.toString() ?? 'Failed to resend OTP',
      );
    }

    final data = json['data'];
    String? customerId;
    String? userToken;
    String? otp;

    if (data is Map<String, dynamic>) {
      customerId =
          data['customerId']?.toString() ?? data['customer_id']?.toString();
      userToken = data['userToken']?.toString() ?? data['user_token']?.toString();
      otp = _extractOtpFromMap(data);
    }

    otp ??= _extractOtpFromMap(json);
    otp ??= _extractOtpFromMessage(json['message']?.toString());

    if (otp != null && otp.isNotEmpty) {
      debugPrint('════════ RESEND OTP ════════');
      debugPrint('Mobile: $mobileNumber');
      debugPrint('OTP: $otp');
      debugPrint('══════════════════════════');
    }

    return ResendOtpResult(
      customerId: customerId,
      userToken: userToken,
      otp: otp,
      message: json['message']?.toString() ?? 'OTP sent successfully',
    );
  }

  String? _extractOtpFromMap(Map<String, dynamic> map) {
    for (final key in ['otp', 'OTP', 'verification_code', 'code']) {
      final value = map[key]?.toString().trim();
      if (value != null && RegExp(r'^\d{4,8}$').hasMatch(value)) {
        return value;
      }
    }
    return null;
  }

  String? _extractOtpFromMessage(String? message) {
    if (message == null || message.isEmpty) return null;
    final match = RegExp(r'\b(\d{6})\b').firstMatch(message);
    return match?.group(1);
  }

  Future<VerifyOtpResult> verifyOtp({
    required String customerId,
    required String otp,
    required String userToken,
  }) async {
    final json = await _apiClient.post(
      ApiConstants.verifyOtpPath,
      {
        'customerId': customerId,
        'otp': otp,
        'userToken': userToken,
      },
    );

    if (json['success'] != true) {
      throw ApiException(
        json['message']?.toString() ?? 'OTP verification failed',
      );
    }

    final authToken = json['authToken']?.toString();
    final customerJson = json['customer'];
    if (authToken == null ||
        authToken.isEmpty ||
        customerJson is! Map<String, dynamic>) {
      throw const ApiException('Invalid verify OTP response');
    }

    return VerifyOtpResult(
      authToken: authToken,
      customer: Customer.fromJson(customerJson),
    );
  }
}
