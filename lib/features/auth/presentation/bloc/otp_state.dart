import 'package:equatable/equatable.dart';

class OtpState extends Equatable {
  final String otp;
  final bool isButtonEnabled;
  final int secondsRemaining;
  final bool hasError;
  final bool isSuccess;
  final bool isLoading;
  final bool isResending;
  final String? errorMessage;
  final String? devOtp;

  const OtpState({
    this.otp = "",
    this.isButtonEnabled = false,
    this.secondsRemaining = 30,
    this.hasError = false,
    this.isSuccess = false,
    this.isLoading = false,
    this.isResending = false,
    this.errorMessage,
    this.devOtp,
  });

  OtpState copyWith({
    String? otp,
    bool? isButtonEnabled,
    int? secondsRemaining,
    bool? hasError,
    bool? isSuccess,
    bool? isLoading,
    bool? isResending,
    String? errorMessage,
    String? devOtp,
    bool clearError = false,
  }) {
    return OtpState(
      otp: otp ?? this.otp,
      isButtonEnabled: isButtonEnabled ?? this.isButtonEnabled,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      hasError: hasError ?? this.hasError,
      isSuccess: isSuccess ?? this.isSuccess,
      isLoading: isLoading ?? this.isLoading,
      isResending: isResending ?? this.isResending,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      devOtp: devOtp ?? this.devOtp,
    );
  }

  @override
  List<Object?> get props => [
        otp,
        isButtonEnabled,
        secondsRemaining,
        hasError,
        isSuccess,
        isLoading,
        isResending,
        errorMessage,
        devOtp,
      ];
}
