import 'package:maxbillup/utils/firestore_service.dart';

/// Centralized Currency Service
/// Provides currency symbol based on selected currency code from store settings
class CurrencyService {
  static final CurrencyService _instance = CurrencyService._internal();
  factory CurrencyService() => _instance;
  CurrencyService._internal();

  String _currencySymbol = '';
  String _currencyCode = '';
  bool _isLoaded = false;

  /// Currency code to symbol mapping
  static const Map<String, String> currencySymbols = {
    // Popular currencies
    'USD': '\$', 'EUR': '€', 'GBP': '£', 'INR': '₹', 'CNY': '¥', 'JPY': '¥',

    // Asia-Pacific
    'AED': 'د.إ', 'AFN': '؋', 'AMD': '֏', 'AUD': 'A\$', 'AZN': '₼',
    'BDT': '৳', 'BHD': '.د.ب', 'BND': 'B\$', 'BTN': 'Nu.', 'FJD': 'FJ\$',
    'GEL': '₾', 'HKD': 'HK\$', 'IDR': 'Rp', 'ILS': '₪', 'IQD': 'ع.د',
    'IRR': '﷼', 'JOD': 'د.ا', 'KHR': '៛', 'KRW': '₩', 'KWD': 'د.ك',
    'KZT': '₸', 'LAK': '₭', 'LBP': 'ل.ل', 'LKR': 'Rs', 'MMK': 'K',
    'MNT': '₮', 'MOP': 'MOP\$', 'MVR': 'Rf', 'MYR': 'RM', 'NPR': 'Rs',
    'NZD': 'NZ\$', 'OMR': 'ر.ع.', 'PHP': '₱', 'PKR': 'Rs', 'QAR': 'ر.ق',
    'SAR': '﷼', 'SGD': 'S\$', 'SYP': '£S', 'THB': '฿', 'TJS': 'ЅМ',
    'TMT': 'm', 'TRY': '₺', 'TWD': 'NT\$', 'UZS': 'so\'m', 'VND': '₫',

    // Europe
    'ALL': 'L', 'BAM': 'KM', 'BGN': 'лв', 'BYN': 'Br', 'CHF': 'Fr',
    'CZK': 'Kč', 'DKK': 'kr', 'HRK': 'kn', 'HUF': 'Ft', 'ISK': 'kr',
    'MDL': 'L', 'MKD': 'ден', 'NOK': 'kr', 'PLN': 'zł', 'RON': 'lei',
    'RSD': 'дин', 'RUB': '₽', 'SEK': 'kr', 'UAH': '₴',

    // Americas
    'ARS': '\$', 'BOB': 'Bs.', 'BRL': 'R\$', 'CAD': 'C\$', 'CLP': '\$',
    'COP': '\$', 'CRC': '₡', 'CUP': '\$', 'DOP': 'RD\$', 'GTQ': 'Q',
    'HNL': 'L', 'HTG': 'G', 'JMD': 'J\$', 'MXN': 'Mex\$', 'NIO': 'C\$',
    'PAB': 'B/.', 'PEN': 'S/', 'PYG': '₲', 'TTD': 'TT\$', 'UYU': '\$U',
    'VES': 'Bs.S',

    // Africa
    'DZD': 'د.ج', 'EGP': 'E£', 'ETB': 'Br', 'GHS': 'GH₵', 'KES': 'KSh',
    'MAD': 'د.م.', 'MUR': '₨', 'MWK': 'MK', 'NAD': 'N\$', 'NGN': '₦',
    'RWF': 'FRw', 'TND': 'د.ت', 'TZS': 'TSh', 'UGX': 'USh', 'XAF': 'Fcfa',
    'XOF': 'Cfa', 'ZAR': 'R', 'ZMW': 'ZK',
  };

  /// Get currency symbol for a given code
  /// Returns empty string if code is null/empty or not found
  static String getSymbol(String? code) {
    if (code == null || code.isEmpty) return '';
    return currencySymbols[code] ?? '';
  }

  /// Get currency symbol with trailing space (for formatting)
  static String getSymbolWithSpace(String? code) {
    final symbol = getSymbol(code);
    return symbol.isNotEmpty ? '$symbol ' : '';
  }

  /// Current currency symbol (loaded from store)
  String get symbol => _currencySymbol;

  /// Current currency symbol with space
  String get symbolWithSpace => _currencySymbol.isNotEmpty ? '$_currencySymbol ' : '';

  /// Current currency code
  String get code => _currencyCode;

  /// Check if currency is loaded
  bool get isLoaded => _isLoaded;

  /// Load currency from store settings
  Future<void> loadCurrency() async {
    try {
      final store = await FirestoreService().getCurrentStoreDoc();
      if (store != null && store.exists) {
        final data = store.data() as Map<String, dynamic>?;
        final code = data?['currency'] as String?;
        _currencyCode = code ?? '';
        _currencySymbol = getSymbol(code);
        _isLoaded = true;
      }
    } catch (e) {
      // Silent fail - keep default empty symbol
      _isLoaded = true;
    }
  }

  /// Update currency (called when user changes currency in settings)
  void updateCurrency(String? code) {
    _currencyCode = code ?? '';
    _currencySymbol = getSymbol(code);
    _isLoaded = true;
  }

  /// Format amount with currency symbol
  /// Returns just the amount if no currency is set
  String format(double amount, {int decimals = 2}) {
    final formattedAmount = amount.toStringAsFixed(decimals);
    return _currencySymbol.isNotEmpty ? '$_currencySymbol$formattedAmount' : formattedAmount;
  }

  /// Format amount with currency symbol and space
  String formatWithSpace(double amount, {int decimals = 2}) {
    final formattedAmount = amount.toStringAsFixed(decimals);
    return _currencySymbol.isNotEmpty ? '$_currencySymbol $formattedAmount' : formattedAmount;
  }
}

