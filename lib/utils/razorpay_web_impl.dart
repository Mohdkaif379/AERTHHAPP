// Web-only implementation using dart:js to call checkout.js
import 'dart:js' as js;

void openRazorpayWeb({
  required String key,
  required String orderId,
  required int amount,
  required String phone,
  required String email,
  required Function(String paymentId) onSuccess,
  required Function(String error) onError,
}) {
  try {
    final jsOptions = js.JsObject.jsify({
      'key': key,
      'amount': amount,
      'currency': 'INR',
      'name': 'Aerthh',
      'order_id': orderId,
      'description': 'Order Payment',
      'prefill': {'contact': phone, 'email': email},
      'theme': {'color': '#D4A574'},
      'handler': js.allowInterop((dynamic response) {
        final paymentId =
            (response is js.JsObject && response.hasProperty('razorpay_payment_id'))
                ? response['razorpay_payment_id']?.toString() ?? 'Payment Successful'
                : 'Payment Successful';
        onSuccess(paymentId);
      }),
      'modal': {
        'ondismiss': js.allowInterop(() {
          onError('Payment dismissed by user');
        }),
      },
    });

    final razorpayInstance =
        js.JsObject(js.context['Razorpay'] as js.JsFunction, [jsOptions]);
    razorpayInstance.callMethod('open', []);
  } catch (e) {
    onError(e.toString());
  }
}
