/// Converts a decimal value to a human-friendly fraction string.
///
/// Common fractions are recognized: 1/8, 1/4, 1/3, 3/8, 1/2, 5/8, 2/3, 3/4, 7/8.
/// Whole numbers are returned without a denominator.
/// Mixed numbers like 1.5 become "1 1/2".
/// Handles edge cases: 0, negative numbers, and very large numbers.
String formatQuantity(double value) {
  if (value == 0) return '0';
  if (value < 0) return '-${formatQuantity(-value)}';

  // For very large numbers, return a rounded integer to avoid confusion.
  if (value >= 10000) return value.round().toString();

  final whole = value.floor();
  final fraction = value - whole;

  final fractionStr = _fractionPart(fraction);

  if (whole == 0) {
    return fractionStr.isEmpty ? '0' : fractionStr;
  }
  if (fractionStr.isEmpty) {
    return whole.toString();
  }
  return '$whole $fractionStr';
}

/// Known fraction thresholds and their display strings.
final List<_FractionEntry> _knownFractions = [
  const _FractionEntry(0.125, '1/8'),
  const _FractionEntry(0.167, '1/6'),
  const _FractionEntry(0.2, '1/5'),
  const _FractionEntry(0.25, '1/4'),
  const _FractionEntry(0.333, '1/3'),
  const _FractionEntry(0.375, '3/8'),
  const _FractionEntry(0.4, '2/5'),
  const _FractionEntry(0.5, '1/2'),
  const _FractionEntry(0.6, '3/5'),
  const _FractionEntry(0.625, '5/8'),
  const _FractionEntry(0.667, '2/3'),
  const _FractionEntry(0.75, '3/4'),
  const _FractionEntry(0.8, '4/5'),
  const _FractionEntry(0.833, '5/6'),
  const _FractionEntry(0.875, '7/8'),
];

class _FractionEntry {
  const _FractionEntry(this.value, this.display);
  final double value;
  final String display;
}

String _fractionPart(double fraction) {
  if (fraction < 0.04) return '';

  // Check common fractions with a tolerance of 0.04.
  for (final entry in _knownFractions) {
    if ((fraction - entry.value).abs() < 0.04) {
      return entry.display;
    }
  }

  // Fall back to a single decimal place for unusual fractions.
  return fraction.toStringAsFixed(1).substring(1); // e.g. ".7"
}

/// Scales a quantity from [baseServings] to [desiredServings].
double scaleQuantity(double quantity, int baseServings, int desiredServings) {
  if (baseServings <= 0) return quantity;
  return quantity * desiredServings / baseServings;
}
