import 'package:maxbillup/services/currency_service.dart';

/// Utility class for consistent amount/decimal formatting across the app
/// This ensures no rounding of decimal values - displays exact values as stored

class AmountFormatter {
  /// Formats amount with full decimal precision (no rounding)
  /// If the number has decimals, shows them all (up to 4 decimal places)
  /// If the number is whole, shows without decimals
  static String format(dynamic value, {int maxDecimals = 4}) {
    if (value == null) return '0';

    double amount;
    if (value is int) {
      amount = value.toDouble();
    } else if (value is double) {
      amount = value;
    } else if (value is String) {
      amount = double.tryParse(value) ?? 0.0;
    } else {
      amount = 0.0;
    }

    // Check if it's a whole number
    if (amount == amount.truncateToDouble()) {
      return amount.toInt().toString();
    }

    // Format with full precision, then remove trailing zeros
    String formatted = amount.toStringAsFixed(maxDecimals);

    // Remove trailing zeros after decimal point
    if (formatted.contains('.')) {
      formatted = formatted.replaceAll(RegExp(r'0+$'), '');
      // Remove decimal point if no decimals left
      if (formatted.endsWith('.')) {
        formatted = formatted.substring(0, formatted.length - 1);
      }
    }

    return formatted;
  }

  /// Formats amount with currency symbol
  static String formatWithSymbol(dynamic value, {int maxDecimals = 4, String? symbol}) {
    final currencySymbol = symbol ?? CurrencyService().symbol;
    return '$currencySymbol${format(value, maxDecimals: maxDecimals)}';
  }

  /// Formats amount with currency prefix
  static String formatWithRs(dynamic value, {int maxDecimals = 4}) {
    return '${CurrencyService().symbolWithSpace}${format(value, maxDecimals: maxDecimals)}';
  }

  /// Formats for display in lists (compact format)
  /// Shows 2 decimal places if there are decimals, otherwise whole number
  static String formatCompact(dynamic value) {
    if (value == null) return '0';

    double amount;
    if (value is int) {
      amount = value.toDouble();
    } else if (value is double) {
      amount = value;
    } else if (value is String) {
      amount = double.tryParse(value) ?? 0.0;
    } else {
      amount = 0.0;
    }

    // Check if it's a whole number
    if (amount == amount.truncateToDouble()) {
      return amount.toInt().toString();
    }

    // Show with 2 decimal places, removing trailing zeros
    String formatted = amount.toStringAsFixed(2);
    if (formatted.endsWith('0')) {
      formatted = formatted.substring(0, formatted.length - 1);
    }
    if (formatted.endsWith('.0')) {
      formatted = formatted.substring(0, formatted.length - 2);
    }

    return formatted;
  }

  /// Parse string to double safely
  static double parse(String? value) {
    if (value == null || value.isEmpty) return 0.0;
    return double.tryParse(value) ?? 0.0;
  }
}

/// Extension on double for easy formatting
extension AmountExtension on double {
  /// Format with full precision (no rounding)
  String toAmount({int maxDecimals = 4}) => AmountFormatter.format(this, maxDecimals: maxDecimals);

  /// Format with Rs prefix
  String toAmountRs({int maxDecimals = 4}) => AmountFormatter.formatWithRs(this, maxDecimals: maxDecimals);

  /// Format with ₹ symbol
  String toAmountSymbol({int maxDecimals = 4}) => AmountFormatter.formatWithSymbol(this, maxDecimals: maxDecimals);

  /// Format compact (for lists)
  String toAmountCompact() => AmountFormatter.formatCompact(this);
}

/// Extension on num for easy formatting
extension NumAmountExtension on num {
  /// Format with full precision (no rounding)
  String toAmount({int maxDecimals = 4}) => AmountFormatter.format(this, maxDecimals: maxDecimals);

  /// Format with Rs prefix
  String toAmountRs({int maxDecimals = 4}) => AmountFormatter.formatWithRs(this, maxDecimals: maxDecimals);

  /// Format with ₹ symbol
  String toAmountSymbol({int maxDecimals = 4}) => AmountFormatter.formatWithSymbol(this, maxDecimals: maxDecimals);
}

