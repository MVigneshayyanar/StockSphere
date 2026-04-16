class CartItem {
  final String productId;
  final String name;
  double price; // Changed from final to allow editing
  double quantity; // Changed from int to double to support weights

  final double cost;

  // Multiple taxes support: [{name: 'CGST', percentage: 9.0}, {name: 'SGST', percentage: 9.0}]
  final List<Map<String, dynamic>> taxes;

  // Tax treatment (applies to all taxes on this product)
  final String? taxType; // 'Tax Included in Price', 'Add Tax at Billing', 'No Tax Applied', 'Exempt from Tax'

  // Legacy single-tax fields (derived from taxes list for backward compat)
  String? get taxName {
    if (taxes.isEmpty) return null;
    return taxes.map((t) => t['name']?.toString() ?? '').join(' + ');
  }

  double? get taxPercentage {
    if (taxes.isEmpty) return null;
    return taxes.fold<double>(0.0, (sum, t) => sum + ((t['percentage'] ?? 0.0) as num).toDouble());
  }

  CartItem({
    required this.productId,
    required this.name,
    required this.price,
    this.cost = 0.0,
    this.quantity = 1.0,
    List<Map<String, dynamic>>? taxes,
    // Legacy params — auto-migrate to taxes list
    String? taxName,
    double? taxPercentage,
    this.taxType,
  }) : taxes = taxes ?? _migrateFromLegacy(taxName, taxPercentage);

  /// Migrates old single-tax fields to taxes list
  static List<Map<String, dynamic>> _migrateFromLegacy(String? taxName, double? taxPercentage) {
    if (taxName != null && taxName.isNotEmpty && taxPercentage != null && taxPercentage > 0) {
      return [{'name': taxName, 'percentage': taxPercentage}];
    }
    return [];
  }

  double get total => price * quantity;

  // Calculate tax amount based on tax type
  double get taxAmount {
    final tp = taxPercentage;
    if (tp == null || tp == 0) return 0.0;

    if (taxType == 'Tax Included in Price' || taxType == 'Price includes Tax') {
      final taxRate = tp / 100;
      return (price * quantity) - ((price * quantity) / (1 + taxRate));
    } else if (taxType == 'Add Tax at Billing' || taxType == 'Price is without Tax') {
      return (price * quantity) * (tp / 100);
    } else {
      return 0.0;
    }
  }

  // Get base price (price without tax)
  double get basePrice {
    final tp = taxPercentage;
    if (tp == null || tp == 0) return price;

    if (taxType == 'Tax Included in Price' || taxType == 'Price includes Tax') {
      final taxRate = tp / 100;
      return price / (1 + taxRate);
    } else {
      return price;
    }
  }

  // Get per-unit price including tax
  double get priceWithTax {
    if (taxType == 'Tax Included in Price' || taxType == 'Price includes Tax') {
      return price;
    } else if (taxType == 'Add Tax at Billing' || taxType == 'Price is without Tax') {
      final taxRate = taxPercentage ?? 0;
      return price * (1 + (taxRate / 100));
    } else {
      return price;
    }
  }

  // Get total including tax
  double get totalWithTax {
    if (taxType == 'Tax Included in Price' || taxType == 'Price includes Tax') {
      return total;
    } else if (taxType == 'Add Tax at Billing' || taxType == 'Price is without Tax') {
      return total + taxAmount;
    } else {
      return total;
    }
  }

  /// Returns individual tax breakdowns: {'CGST @9%': taxAmount, 'SGST @9%': taxAmount}
  /// Keys include the tax name and rate for display in invoices/reports.
  Map<String, double> get taxBreakdown {
    if (taxes.isEmpty) return {};

    final totalTp = taxPercentage ?? 0;
    if (totalTp == 0) return {};

    final totalTaxAmt = taxAmount;
    final Map<String, double> breakdown = {};

    for (final tax in taxes) {
      final name = (tax['name'] ?? 'Tax').toString();
      final pct = ((tax['percentage'] ?? 0.0) as num).toDouble();
      final label = '$name @${pct % 1 == 0 ? pct.toInt() : pct}%';
      // Each tax's share proportional to its percentage
      breakdown[label] = (breakdown[label] ?? 0.0) + (totalTaxAmt * (pct / totalTp));
    }
    return breakdown;
  }
}