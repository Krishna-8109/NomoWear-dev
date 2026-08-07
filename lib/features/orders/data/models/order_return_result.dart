class OrderReturnResult {
  const OrderReturnResult({
    required this.message,
    this.waitlisted = false,
  });

  final String message;
  final bool waitlisted;
}
