/// Most lines one run may print. A runaway loop such as
/// `while (true) { print(...); }` would otherwise flood the UI.
const int kMaxOutputLines = 10000;

/// How long one run may take before it is stopped.
const Duration kDefaultRunTimeout = Duration(seconds: 60);
