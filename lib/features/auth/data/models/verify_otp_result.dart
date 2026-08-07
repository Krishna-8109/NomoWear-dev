import 'package:nomowear/features/auth/data/models/customer.dart';

class VerifyOtpResult {
  final String authToken;
  final Customer customer;

  const VerifyOtpResult({
    required this.authToken,
    required this.customer,
  });
}
