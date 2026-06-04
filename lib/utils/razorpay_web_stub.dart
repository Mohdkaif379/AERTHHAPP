// Stub for non-web platforms. These functions are no-ops on mobile/desktop.

void openRazorpayWeb({
  required String key,
  required String orderId,
  required int amount,
  required String phone,
  required String email,
  required Function(String paymentId) onSuccess,
  required Function(String error) onError,
}) {
  // No-op on mobile/desktop. Native Razorpay plugin handles payments there.
}
