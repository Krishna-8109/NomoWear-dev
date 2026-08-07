class OtpScreenArgs {
  final String mobileNumber;
  final String customerId;
  final String userToken;
  final String? otp;

  const OtpScreenArgs({
    required this.mobileNumber,
    required this.customerId,
    required this.userToken,
    this.otp,
  });
}
