class ResendOtpResult {
  final String? customerId;
  final String? userToken;
  final String? otp;
  final String message;

  const ResendOtpResult({
    this.customerId,
    this.userToken,
    this.otp,
    this.message = 'OTP sent successfully',
  });
}
