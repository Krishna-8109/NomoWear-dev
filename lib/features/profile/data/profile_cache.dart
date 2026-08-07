import 'package:nomowear/features/auth/data/models/customer.dart';

/// In-memory profile cache so tab switches do not refetch every time.
class ProfileCache {
  ProfileCache._();

  static final ProfileCache instance = ProfileCache._();

  Customer? _customer;

  Customer? get customer => _customer;

  void set(Customer customer) {
    _customer = customer;
  }

  void clear() {
    _customer = null;
  }
}
