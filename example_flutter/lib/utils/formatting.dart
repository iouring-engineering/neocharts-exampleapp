/// Coerces a dynamic (JSON-decoded) value into a [double], defaulting to 0.
double toDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}

/// Coerces a dynamic (JSON-decoded) value into an [int], or null if it
/// can't be parsed.
int? toInt(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value.toString());
}

/// Rounds [value] to [decimals] decimal places.
double roundTo(double value, int decimals) {
  return double.parse(value.toStringAsFixed(decimals));
}

/// Formats [dateTime] as `dd-MM-yyyy HH:mm:ss`.
String formatDateTime(DateTime dateTime) {
  String twoDigits(int value) => value.toString().padLeft(2, '0');

  return '${twoDigits(dateTime.day)}-'
      '${twoDigits(dateTime.month)}-'
      '${dateTime.year} '
      '${twoDigits(dateTime.hour)}:'
      '${twoDigits(dateTime.minute)}:'
      '${twoDigits(dateTime.second)}';
}
