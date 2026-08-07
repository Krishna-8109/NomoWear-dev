import 'package:nomowear/features/auth/data/models/customer.dart';

class ProfileCompletionHelper {
  /// True when required profile fields for checkout are filled.
  static bool isProfileComplete(Customer customer) {
    final name = customer.fullName?.trim();
    if (name == null || name.isEmpty) return false;

    final email = customer.email?.trim();
    if (email == null || email.isEmpty) return false;

    final dob = customer.dob?.trim();
    if (dob == null || dob.isEmpty) return false;

    final address = customer.primaryAddress?.fullAddress?.trim();
    if (address == null || address.isEmpty) return false;

    return true;
  }
}
