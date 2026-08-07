import 'package:razorpay_flutter/razorpay_flutter.dart';

typedef PaymentSuccessHandler = void Function(PaymentSuccessResponse response);
typedef PaymentFailureHandler = void Function(PaymentFailureResponse response);

class RazorpayService {
  Razorpay? _razorpay;

  void init({
    required PaymentSuccessHandler onSuccess,
    required PaymentFailureHandler onFailure,
  }) {
    _razorpay?.clear();
    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, onSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, onFailure)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {});
  }

  void openCheckout({
    required String keyId,
    required String orderId,
    required int amount,
    required String currency,
    String? name,
    String? email,
    String? contact,
    String description = 'Nomowear wardrobe subscription',
  }) {
    final options = <String, dynamic>{
      'key': keyId,
      'amount': amount,
      'currency': currency,
      'name': 'Nomowear',
      'description': description,
      'order_id': orderId,
      'prefill': {
        if (contact != null && contact.isNotEmpty) 'contact': contact,
        if (email != null && email.isNotEmpty) 'email': email,
        if (name != null && name.isNotEmpty) 'name': name,
      },
      'theme': {'color': '#E6C27A'},
    };

    _razorpay?.open(options);
  }

  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
  }
}
