class CurrencyDisplay {
  // Fallback rate used when API fetch fails.
  static const double defaultEgpToKrwRate = 28.0;
  static double _egpToKrwRate = defaultEgpToKrwRate;

  static double get egpToKrwRate => _egpToKrwRate;

  static void setEgpToKrwRate(double rate) {
    if (rate <= 0) return;
    _egpToKrwRate = rate;
  }

  // Used by tests to avoid cross-test state sharing.
  static void resetRateForTest() {
    _egpToKrwRate = defaultEgpToKrwRate;
  }

  static String formatEgp(double egp, {int decimals = 0}) {
    return '${egp.toStringAsFixed(decimals)} EGP';
  }

  static String formatKrw(double egp) {
    final krw = (egp * _egpToKrwRate).round();
    return '₩${_comma(krw)}';
  }

  static String formatEgpWithKrw(double egp, {int egpDecimals = 0}) {
    return '${formatEgp(egp, decimals: egpDecimals)} (${formatKrw(egp)})';
  }

  static String _comma(int value) {
    final s = value.toString();
    final b = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final reverseIndex = s.length - i;
      b.write(s[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        b.write(',');
      }
    }
    return b.toString();
  }
}
