import 'package:equatable/equatable.dart';
import 'package:nomowear/features/auth/data/models/login_session.dart';

class LoginState extends Equatable {
  final String mobileNumber;
  final bool isButtonEnabled;
  final bool isLoading;
  final String? errorMessage;
  final LoginSession? otpSession;

  const LoginState({
    this.mobileNumber = "",
    this.isButtonEnabled = false,
    this.isLoading = false,
    this.errorMessage,
    this.otpSession,
  });

  LoginState copyWith({
    String? mobileNumber,
    bool? isButtonEnabled,
    bool? isLoading,
    String? errorMessage,
    LoginSession? otpSession,
    bool clearError = false,
    bool clearOtpSession = false,
  }) {
    return LoginState(
      mobileNumber: mobileNumber ?? this.mobileNumber,
      isButtonEnabled: isButtonEnabled ?? this.isButtonEnabled,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      otpSession: clearOtpSession ? null : (otpSession ?? this.otpSession),
    );
  }

  @override
  List<Object?> get props =>
      [mobileNumber, isButtonEnabled, isLoading, errorMessage, otpSession];
}
