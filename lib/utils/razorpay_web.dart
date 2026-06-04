// Conditional import: uses dart:js on web, no-op stub everywhere else.
export 'razorpay_web_stub.dart'
    if (dart.library.js) 'razorpay_web_impl.dart';
