import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:heroicons/heroicons.dart';
import 'package:maxbillup/Sales/NewSale.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/Colors.dart';

class BusinessDetailsPage extends StatefulWidget {
  final String uid;
  final String? email;
  final String? displayName;

  const BusinessDetailsPage({
    super.key,
    required this.uid,
    this.email,
    this.displayName,
  });

  @override
  State<BusinessDetailsPage> createState() => _BusinessDetailsPageState();
}

class _BusinessDetailsPageState extends State<BusinessDetailsPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _businessNameCtrl = TextEditingController();
  final _businessPhoneCtrl = TextEditingController();
  final _personalPhoneCtrl = TextEditingController();
  final _taxTypeCtrl = TextEditingController();
  final _taxNumberCtrl = TextEditingController();
  final _licenseTypeCtrl = TextEditingController();
  final _licenseNumberCtrl = TextEditingController();
  final _businessLocationCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();

  bool _loading = false;
  bool _showAdvancedDetails = false;
  String _selectedCurrency = 'INR';

  // Country code data
  String _selectedCountryCode = '+91';
  String _selectedCountryFlag = '🇮🇳';

  final List<Map<String, String>> _countryCodes = [
    {'code': '+91', 'flag': '🇮🇳', 'name': 'India'},
    {'code': '+1', 'flag': '🇺🇸', 'name': 'United States'},
    {'code': '+44', 'flag': '🇬🇧', 'name': 'United Kingdom'},
    {'code': '+971', 'flag': '🇦🇪', 'name': 'Uae'},
    {'code': '+966', 'flag': '🇸🇦', 'name': 'Saudi Arabia'},
    {'code': '+974', 'flag': '🇶🇦', 'name': 'Qatar'},
    {'code': '+965', 'flag': '🇰🇼', 'name': 'Kuwait'},
    {'code': '+973', 'flag': '🇧🇭', 'name': 'Bahrain'},
    {'code': '+968', 'flag': '🇴🇲', 'name': 'Oman'},
    {'code': '+60', 'flag': '🇲🇾', 'name': 'Malaysia'},
    {'code': '+65', 'flag': '🇸🇬', 'name': 'Singapore'},
    {'code': '+92', 'flag': '🇵🇰', 'name': 'Pakistan'},
    {'code': '+880', 'flag': '🇧🇩', 'name': 'Bangladesh'},
    {'code': '+94', 'flag': '🇱🇰', 'name': 'Sri Lanka'},
    {'code': '+977', 'flag': '🇳🇵', 'name': 'Nepal'},
    {'code': '+61', 'flag': '🇦🇺', 'name': 'Australia'},
    {'code': '+64', 'flag': '🇳🇿', 'name': 'New Zealand'},
    {'code': '+49', 'flag': '🇩🇪', 'name': 'Germany'},
    {'code': '+33', 'flag': '🇫🇷', 'name': 'France'},
    {'code': '+39', 'flag': '🇮🇹', 'name': 'Italy'},
    {'code': '+34', 'flag': '🇪🇸', 'name': 'Spain'},
    {'code': '+7', 'flag': '🇷🇺', 'name': 'Russia'},
    {'code': '+81', 'flag': '🇯🇵', 'name': 'Japan'},
    {'code': '+82', 'flag': '🇰🇷', 'name': 'South Korea'},
    {'code': '+86', 'flag': '🇨🇳', 'name': 'China'},
    {'code': '+55', 'flag': '🇧🇷', 'name': 'Brazil'},
    {'code': '+52', 'flag': '🇲🇽', 'name': 'Mexico'},
    {'code': '+27', 'flag': '🇿🇦', 'name': 'South Africa'},
    {'code': '+234', 'flag': '🇳🇬', 'name': 'Nigeria'},
    {'code': '+254', 'flag': '🇰🇪', 'name': 'Kenya'},
    {'code': '+20', 'flag': '🇪🇬', 'name': 'Egypt'},
  ];

  final List<Map<String, String>> _currencies = [
    // Popular currencies first
    {'code': 'INR', 'symbol': '₹', 'name': 'Indian Rupee'},
    {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar'},
    {'code': 'EUR', 'symbol': '€', 'name': 'Euro'},
    {'code': 'GBP', 'symbol': '£', 'name': 'British Pound'},
    {'code': 'CNY', 'symbol': '¥', 'name': 'Chinese Yuan'},
    {'code': 'JPY', 'symbol': '¥', 'name': 'Japanese Yen'},
    {'code': 'AUD', 'symbol': 'A\$', 'name': 'Australian Dollar'},
    {'code': 'CAD', 'symbol': 'C\$', 'name': 'Canadian Dollar'},
    {'code': 'CHF', 'symbol': 'CHF', 'name': 'Swiss Franc'},
    {'code': 'SGD', 'symbol': 'S\$', 'name': 'Singapore Dollar'},
    {'code': 'AED', 'symbol': 'د.إ', 'name': 'UAE Dirham'},
    {'code': 'SAR', 'symbol': '﷼', 'name': 'Saudi Riyal'},

    // Asia-Pacific
    {'code': 'AFN', 'symbol': '؋', 'name': 'Afghan Afghani'},
    {'code': 'AMD', 'symbol': '֏', 'name': 'Armenian Dram'},
    {'code': 'AZN', 'symbol': '₼', 'name': 'Azerbaijani Manat'},
    {'code': 'BDT', 'symbol': '৳', 'name': 'Bangladeshi Taka'},
    {'code': 'BHD', 'symbol': '.د.ب', 'name': 'Bahraini Dinar'},
    {'code': 'BND', 'symbol': 'B\$', 'name': 'Brunei Dollar'},
    {'code': 'BTN', 'symbol': 'Nu.', 'name': 'Bhutanese Ngultrum'},
    {'code': 'FJD', 'symbol': 'FJ\$', 'name': 'Fijian Dollar'},
    {'code': 'GEL', 'symbol': '₾', 'name': 'Georgian Lari'},
    {'code': 'HKD', 'symbol': 'HK\$', 'name': 'Hong Kong Dollar'},
    {'code': 'IDR', 'symbol': 'Rp', 'name': 'Indonesian Rupiah'},
    {'code': 'ILS', 'symbol': '₪', 'name': 'Israeli New Shekel'},
    {'code': 'IQD', 'symbol': 'ع.د', 'name': 'Iraqi Dinar'},
    {'code': 'IRR', 'symbol': '﷼', 'name': 'Iranian Rial'},
    {'code': 'JOD', 'symbol': 'د.ا', 'name': 'Jordanian Dinar'},
    {'code': 'KHR', 'symbol': '៛', 'name': 'Cambodian Riel'},
    {'code': 'KRW', 'symbol': '₩', 'name': 'South Korean Won'},
    {'code': 'KWD', 'symbol': 'د.ك', 'name': 'Kuwaiti Dinar'},
    {'code': 'KZT', 'symbol': '₸', 'name': 'Kazakhstani Tenge'},
    {'code': 'KGS', 'symbol': 'с', 'name': 'Kyrgyzstani Som'},
    {'code': 'LAK', 'symbol': '₭', 'name': 'Lao Kip'},
    {'code': 'LBP', 'symbol': 'ل.ل', 'name': 'Lebanese Pound'},
    {'code': 'LKR', 'symbol': 'Rs', 'name': 'Sri Lankan Rupee'},
    {'code': 'MMK', 'symbol': 'K', 'name': 'Myanmar Kyat'},
    {'code': 'MNT', 'symbol': '₮', 'name': 'Mongolian Tugrik'},
    {'code': 'MOP', 'symbol': 'MOP\$', 'name': 'Macanese Pataca'},
    {'code': 'MVR', 'symbol': 'Rf', 'name': 'Maldivian Rufiyaa'},
    {'code': 'MYR', 'symbol': 'RM', 'name': 'Malaysian Ringgit'},
    {'code': 'NPR', 'symbol': 'Rs', 'name': 'Nepalese Rupee'},
    {'code': 'NZD', 'symbol': 'NZ\$', 'name': 'New Zealand Dollar'},
    {'code': 'OMR', 'symbol': 'ر.ع.', 'name': 'Omani Rial'},
    {'code': 'PGK', 'symbol': 'K', 'name': 'Papua New Guinean Kina'},
    {'code': 'PHP', 'symbol': '₱', 'name': 'Philippine Peso'},
    {'code': 'PKR', 'symbol': 'Rs', 'name': 'Pakistani Rupee'},
    {'code': 'QAR', 'symbol': 'ر.ق', 'name': 'Qatari Riyal'},
    {'code': 'SBD', 'symbol': 'SI\$', 'name': 'Solomon Islands Dollar'},
    {'code': 'SYP', 'symbol': '£S', 'name': 'Syrian Pound'},
    {'code': 'THB', 'symbol': '฿', 'name': 'Thai Baht'},
    {'code': 'TJS', 'symbol': 'SM', 'name': 'Tajikistani Somoni'},
    {'code': 'TMT', 'symbol': 'T', 'name': 'Turkmenistani Manat'},
    {'code': 'TOP', 'symbol': 'T\$', 'name': 'Tongan Paʻanga'},
    {'code': 'TRY', 'symbol': '₺', 'name': 'Turkish Lira'},
    {'code': 'TWD', 'symbol': 'NT\$', 'name': 'New Taiwan Dollar'},
    {'code': 'UZS', 'symbol': 'so\'m', 'name': 'Uzbekistani Som'},
    {'code': 'VND', 'symbol': '₫', 'name': 'Vietnamese Dong'},
    {'code': 'VUV', 'symbol': 'VT', 'name': 'Vanuatu Vatu'},
    {'code': 'WST', 'symbol': 'WS\$', 'name': 'Samoan Tālā'},
    {'code': 'YER', 'symbol': '﷼', 'name': 'Yemeni Rial'},

    // Americas
    {'code': 'ARS', 'symbol': '\$', 'name': 'Argentine Peso'},
    {'code': 'AWG', 'symbol': 'ƒ', 'name': 'Aruban Florin'},
    {'code': 'BBD', 'symbol': 'Bds\$', 'name': 'Barbadian Dollar'},
    {'code': 'BMD', 'symbol': 'BD\$', 'name': 'Bermudian Dollar'},
    {'code': 'BOB', 'symbol': 'Bs.', 'name': 'Bolivian Boliviano'},
    {'code': 'BRL', 'symbol': 'R\$', 'name': 'Brazilian Real'},
    {'code': 'BSD', 'symbol': 'B\$', 'name': 'Bahamian Dollar'},
    {'code': 'BZD', 'symbol': 'BZ\$', 'name': 'Belize Dollar'},
    {'code': 'CLP', 'symbol': '\$', 'name': 'Chilean Peso'},
    {'code': 'COP', 'symbol': '\$', 'name': 'Colombian Peso'},
    {'code': 'CRC', 'symbol': '₡', 'name': 'Costa Rican Colón'},
    {'code': 'CUP', 'symbol': '\$', 'name': 'Cuban Peso'},
    {'code': 'DOP', 'symbol': 'RD\$', 'name': 'Dominican Peso'},
    {'code': 'GTQ', 'symbol': 'Q', 'name': 'Guatemalan Quetzal'},
    {'code': 'GYD', 'symbol': 'G\$', 'name': 'Guyanese Dollar'},
    {'code': 'HNL', 'symbol': 'L', 'name': 'Honduran Lempira'},
    {'code': 'HTG', 'symbol': 'G', 'name': 'Haitian Gourde'},
    {'code': 'JMD', 'symbol': 'J\$', 'name': 'Jamaican Dollar'},
    {'code': 'KYD', 'symbol': 'CI\$', 'name': 'Cayman Islands Dollar'},
    {'code': 'MXN', 'symbol': '\$', 'name': 'Mexican Peso'},
    {'code': 'NIO', 'symbol': 'C\$', 'name': 'Nicaraguan Córdoba'},
    {'code': 'PAB', 'symbol': 'B/.', 'name': 'Panamanian Balboa'},
    {'code': 'PEN', 'symbol': 'S/.', 'name': 'Peruvian Sol'},
    {'code': 'PYG', 'symbol': '₲', 'name': 'Paraguayan Guaraní'},
    {'code': 'SRD', 'symbol': '\$', 'name': 'Surinamese Dollar'},
    {'code': 'TTD', 'symbol': 'TT\$', 'name': 'Trinidad and Tobago Dollar'},
    {'code': 'UYU', 'symbol': '\$U', 'name': 'Uruguayan Peso'},
    {'code': 'VES', 'symbol': 'Bs.S', 'name': 'Venezuelan Bolívar'},
    {'code': 'XCD', 'symbol': 'EC\$', 'name': 'East Caribbean Dollar'},

    // Europe
    {'code': 'ALL', 'symbol': 'L', 'name': 'Albanian Lek'},
    {'code': 'BAM', 'symbol': 'KM', 'name': 'Bosnia and Herzegovina Mark'},
    {'code': 'BGN', 'symbol': 'лв', 'name': 'Bulgarian Lev'},
    {'code': 'BYN', 'symbol': 'Br', 'name': 'Belarusian Ruble'},
    {'code': 'CZK', 'symbol': 'Kč', 'name': 'Czech Koruna'},
    {'code': 'DKK', 'symbol': 'kr', 'name': 'Danish Krone'},
    {'code': 'GIP', 'symbol': '£', 'name': 'Gibraltar Pound'},
    {'code': 'HRK', 'symbol': 'kn', 'name': 'Croatian Kuna'},
    {'code': 'HUF', 'symbol': 'Ft', 'name': 'Hungarian Forint'},
    {'code': 'ISK', 'symbol': 'kr', 'name': 'Icelandic Króna'},
    {'code': 'MDL', 'symbol': 'L', 'name': 'Moldovan Leu'},
    {'code': 'MKD', 'symbol': 'ден', 'name': 'Macedonian Denar'},
    {'code': 'NOK', 'symbol': 'kr', 'name': 'Norwegian Krone'},
    {'code': 'PLN', 'symbol': 'zł', 'name': 'Polish Złoty'},
    {'code': 'RON', 'symbol': 'lei', 'name': 'Romanian Leu'},
    {'code': 'RSD', 'symbol': 'дин', 'name': 'Serbian Dinar'},
    {'code': 'RUB', 'symbol': '₽', 'name': 'Russian Ruble'},
    {'code': 'SEK', 'symbol': 'kr', 'name': 'Swedish Krona'},
    {'code': 'UAH', 'symbol': '₴', 'name': 'Ukrainian Hryvnia'},

    // Africa
    {'code': 'AOA', 'symbol': 'Kz', 'name': 'Angolan Kwanza'},
    {'code': 'BIF', 'symbol': 'Fr', 'name': 'Burundian Franc'},
    {'code': 'BWP', 'symbol': 'P', 'name': 'Botswana Pula'},
    {'code': 'CDF', 'symbol': 'FC', 'name': 'Congolese Franc'},
    {'code': 'CVE', 'symbol': '\$', 'name': 'Cape Verdean Escudo'},
    {'code': 'DJF', 'symbol': 'Fdj', 'name': 'Djiboutian Franc'},
    {'code': 'DZD', 'symbol': 'د.ج', 'name': 'Algerian Dinar'},
    {'code': 'EGP', 'symbol': '£', 'name': 'Egyptian Pound'},
    {'code': 'ERN', 'symbol': 'Nfk', 'name': 'Eritrean Nakfa'},
    {'code': 'ETB', 'symbol': 'Br', 'name': 'Ethiopian Birr'},
    {'code': 'GHS', 'symbol': '₵', 'name': 'Ghanaian Cedi'},
    {'code': 'GMD', 'symbol': 'D', 'name': 'Gambian Dalasi'},
    {'code': 'GNF', 'symbol': 'FG', 'name': 'Guinean Franc'},
    {'code': 'KES', 'symbol': 'KSh', 'name': 'Kenyan Shilling'},
    {'code': 'KMF', 'symbol': 'CF', 'name': 'Comorian Franc'},
    {'code': 'LRD', 'symbol': 'L\$', 'name': 'Liberian Dollar'},
    {'code': 'LSL', 'symbol': 'L', 'name': 'Lesotho Loti'},
    {'code': 'LYD', 'symbol': 'ل.د', 'name': 'Libyan Dinar'},
    {'code': 'MAD', 'symbol': 'د.م.', 'name': 'Moroccan Dirham'},
    {'code': 'MGA', 'symbol': 'Ar', 'name': 'Malagasy Ariary'},
    {'code': 'MRU', 'symbol': 'UM', 'name': 'Mauritanian Ouguiya'},
    {'code': 'MUR', 'symbol': '₨', 'name': 'Mauritian Rupee'},
    {'code': 'MWK', 'symbol': 'MK', 'name': 'Malawian Kwacha'},
    {'code': 'MZN', 'symbol': 'MT', 'name': 'Mozambican Metical'},
    {'code': 'NAD', 'symbol': 'N\$', 'name': 'Namibian Dollar'},
    {'code': 'NGN', 'symbol': '₦', 'name': 'Nigerian Naira'},
    {'code': 'RWF', 'symbol': 'FRw', 'name': 'Rwandan Franc'},
    {'code': 'SCR', 'symbol': '₨', 'name': 'Seychellois Rupee'},
    {'code': 'SDG', 'symbol': 'ج.س.', 'name': 'Sudanese Pound'},
    {'code': 'SLL', 'symbol': 'Le', 'name': 'Sierra Leonean Leone'},
    {'code': 'SOS', 'symbol': 'Sh', 'name': 'Somali Shilling'},
    {'code': 'SSP', 'symbol': '£', 'name': 'South Sudanese Pound'},
    {'code': 'STN', 'symbol': 'Db', 'name': 'São Tomé and Príncipe Dobra'},
    {'code': 'SZL', 'symbol': 'L', 'name': 'Swazi Lilangeni'},
    {'code': 'TND', 'symbol': 'د.ت', 'name': 'Tunisian Dinar'},
    {'code': 'TZS', 'symbol': 'TSh', 'name': 'Tanzanian Shilling'},
    {'code': 'UGX', 'symbol': 'USh', 'name': 'Ugandan Shilling'},
    {'code': 'XAF', 'symbol': 'Fcfa', 'name': 'Central African CFA Franc'},
    {'code': 'XOF', 'symbol': 'Cfa', 'name': 'West African CFA Franc'},
    {'code': 'ZAR', 'symbol': 'R', 'name': 'South African Rand'},
    {'code': 'ZMW', 'symbol': 'ZK', 'name': 'Zambian Kwacha'},
    {'code': 'ZWL', 'symbol': 'Z\$', 'name': 'Zimbabwean Dollar'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.displayName != null && widget.displayName!.isNotEmpty) {
      _ownerNameCtrl.text = widget.displayName!;
    }
  }

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _businessPhoneCtrl.dispose();
    _personalPhoneCtrl.dispose();
    _taxTypeCtrl.dispose();
    _taxNumberCtrl.dispose();
    _licenseTypeCtrl.dispose();
    _licenseNumberCtrl.dispose();
    _businessLocationCtrl.dispose();
    _ownerNameCtrl.dispose();
    super.dispose();
  }

  void _showMsg(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        backgroundColor: isError ? kErrorColor : kPrimaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<int> _getNextStoreId() async {
    final firestore = FirebaseFirestore.instance;
    final querySnapshot = await firestore
        .collection('store')
        .orderBy('storeId', descending: true)
        .limit(1)
        .get();
    if (querySnapshot.docs.isEmpty) return 100001;
    final lastStoreId = querySnapshot.docs.first.data()['storeId'] as int? ?? 10000;
    return lastStoreId + 1;
  }

  Future<void> _saveBusinessDetails() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final storeId = await _getNextStoreId();

      final taxType = '${_taxTypeCtrl.text.trim()} ${_taxNumberCtrl.text.trim()}'.trim();
      final licenseNumber = '${_licenseTypeCtrl.text.trim()} ${_licenseNumberCtrl.text.trim()}'.trim();
      final fullBusinessPhone = '$_selectedCountryCode${_businessPhoneCtrl.text.trim()}';

      final storeData = {
        'storeId': storeId,
        'businessName': _businessNameCtrl.text.trim(),
        'businessPhone': fullBusinessPhone,
        'businessPhoneCountryCode': _selectedCountryCode,
        'personalPhone': _personalPhoneCtrl.text.trim(),
        'businessLocation': _businessLocationCtrl.text.trim(),
        'gstin': taxType,
        'taxType': taxType,
        'licenseNumber': licenseNumber,
        'currency': _selectedCurrency,
        'ownerName': _ownerNameCtrl.text.trim(),
        'ownerEmail': widget.email,
        'ownerUid': widget.uid,
        'plan': 'Free',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await firestore.collection('store').doc(storeId.toString()).set(storeData);

      final userData = {
        'uid': widget.uid,
        'email': widget.email,
        'name': _ownerNameCtrl.text.trim(),
        'storeId': storeId,
        'role': 'owner',
        'isActive': true,
        'isEmailVerified': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await firestore.collection('users').doc(widget.uid).set(userData);

      if (mounted) {
        _showMsg(context.tr('business_registered_success'));
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute(
            builder: (context) => NewSalePage(uid: widget.uid, userEmail: widget.email),
          ),
        );
      }
    } catch (e) {
      _showMsg(context.tr('failed_to_save'), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        title: const Text("Business Profile",
            style: TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.0)),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildSectionLabel("Business Details"),
                    _buildModernField("Business Name *", _businessNameCtrl, HeroIcons.buildingStorefront, isMandatory: true),
                    _buildModernField("Owner Name *", _ownerNameCtrl, HeroIcons.user, isMandatory: true),
                    _buildBusinessPhoneField(),
                    _buildLocationField(),
                    _buildCurrencyField(isMandatory: true),
                    const SizedBox(height: 24),
                    _buildAdvancedDetailsToggle(),
                    if (_showAdvancedDetails) ...[
                      const SizedBox(height: 16),
                      _buildSectionLabel("Personal Contact (Optional)"),
                      _buildModernField("Personal Phone", _personalPhoneCtrl, HeroIcons.phone, type: TextInputType.phone, hint: "e.g. +91 9876543210"),
                      const SizedBox(height: 8),
                      _buildSectionLabel("Taxation (Optional)"),
                      _buildOptionalField("Tax Type", _taxTypeCtrl, HeroIcons.banknotes, hint: "e.g. VAT, GST, Sales Tax"),
                      _buildOptionalField("Tax Number", _taxNumberCtrl, HeroIcons.hashtag, hint: "Enter your tax identification number"),
                      const SizedBox(height: 16),
                      _buildSectionLabel("Additional License (Optional)"),
                      _buildOptionalField("License Type", _licenseTypeCtrl, HeroIcons.identification, hint: "e.g. Trade License, FSSAI, F&B"),
                      _buildOptionalField("License Number", _licenseNumberCtrl, HeroIcons.hashtag, hint: "Enter your license number"),
                    ],
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
          _buildBottomActionArea(),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 4),
        child: Text(
          text,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: kBlack54, letterSpacing: 1.0),
        ),
      ),
    );
  }

  /// Business phone field with country code prefix selector
  Widget _buildBusinessPhoneField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _businessPhoneCtrl,
        builder: (context, value, child) {
          final bool isFilled = value.text.isNotEmpty;
          return TextFormField(
            controller: _businessPhoneCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))],
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack87),
            decoration: InputDecoration(
              labelText: 'Business Number *',
              hintText: 'Enter business number',
              hintStyle: const TextStyle(color: kBlack54, fontSize: 13, fontWeight: FontWeight.normal),
              prefixIcon: GestureDetector(
                onTap: _showCountryCodePicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_selectedCountryFlag, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 4),
                      Text(
                        _selectedCountryCode,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isFilled ? kPrimaryColor : kBlack54,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_drop_down, size: 16, color: isFilled ? kPrimaryColor : kBlack54),
                    ],
                  ),
                ),
              ),
              filled: true,
              fillColor: kGreyBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isFilled ? kPrimaryColor : kGrey200, width: isFilled ? 1.5 : 1.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isFilled ? kPrimaryColor : kGrey200, width: isFilled ? 1.5 : 1.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kPrimaryColor, width: 2.0),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kErrorColor),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kErrorColor, width: 2.0),
              ),
              labelStyle: TextStyle(color: isFilled ? kPrimaryColor : kBlack54, fontSize: 13, fontWeight: FontWeight.w600),
              floatingLabelStyle: const TextStyle(color: kPrimaryColor, fontSize: 11, fontWeight: FontWeight.w900),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Business Number is required';
              if (v.trim().length < 5) return 'Enter a valid number';
              return null;
            },
          );
        },
      ),
    );
  }

  void _showCountryCodePicker() {
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _countryCodes.where((c) {
              if (searchQuery.isEmpty) return true;
              final q = searchQuery.toLowerCase();
              return c['name']!.toLowerCase().contains(q) || c['code']!.contains(q);
            }).toList();

            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Column(
                      children: [
                        const Text("Select Country Code",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kBlack87)),
                        const SizedBox(height: 14),
                        TextField(
                          autofocus: false,
                          decoration: InputDecoration(
                            hintText: 'Search country...',
                            hintStyle: const TextStyle(fontSize: 13, color: kGrey400),
                            prefixIcon: const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: HeroIcon(HeroIcons.magnifyingGlass, color: kPrimaryColor, size: 18),
                            ),
                            filled: true,
                            fillColor: kGreyBg,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          onChanged: (v) => setModalState(() => searchQuery = v),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: kGrey100),
                      itemBuilder: (context, i) {
                        final c = filtered[i];
                        final isSelected = c['code'] == _selectedCountryCode;
                        return ListTile(
                          onTap: () {
                            setState(() {
                              _selectedCountryCode = c['code']!;
                              _selectedCountryFlag = c['flag']!;
                            });
                            Navigator.pop(ctx);
                          },
                          leading: Text(c['flag']!, style: const TextStyle(fontSize: 24)),
                          title: Text(c['name']!,
                              style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  fontSize: 14,
                                  color: isSelected ? kPrimaryColor : kBlack87)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(c['code']!,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected ? kPrimaryColor : kBlack54)),
                              if (isSelected)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: HeroIcon(HeroIcons.checkCircle, color: kPrimaryColor, size: 20),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModernField(
      String label,
      TextEditingController ctrl,
      HeroIcons icon, {
        bool enabled = true,
        TextInputType type = TextInputType.text,
        bool isMandatory = false,
        String? hint,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: ctrl,
        builder: (context, value, child) {
          final bool isFilled = value.text.isNotEmpty;
          return TextFormField(
            controller: ctrl,
            enabled: enabled,
            keyboardType: type,
            inputFormatters: type == TextInputType.phone
                ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]'))]
                : null,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack87),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              hintStyle: const TextStyle(color: kBlack54, fontSize: 13, fontWeight: FontWeight.normal),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12.0),
                child: HeroIcon(icon, color: enabled ? (isFilled ? kPrimaryColor : kBlack54) : kGrey400, size: 18),
              ),
              filled: true,
              fillColor: kGreyBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isFilled ? kPrimaryColor : kGrey200, width: isFilled ? 1.5 : 1.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isFilled ? kPrimaryColor : kGrey200, width: isFilled ? 1.5 : 1.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kPrimaryColor, width: 2.0),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kErrorColor),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kErrorColor, width: 2.0),
              ),
              labelStyle: TextStyle(color: isFilled ? kPrimaryColor : kBlack54, fontSize: 13, fontWeight: FontWeight.w600),
              floatingLabelStyle: const TextStyle(color: kPrimaryColor, fontSize: 11, fontWeight: FontWeight.w900),
            ),
            validator: (v) {
              if (isMandatory && (v == null || v.trim().isEmpty)) return "$label is required";
              return null;
            },
          );
        },
      ),
    );
  }

  Widget _buildOptionalField(
      String label,
      TextEditingController ctrl,
      HeroIcons icon, {
        bool enabled = true,
        TextInputType type = TextInputType.text,
        String? hint,
      }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: ctrl,
        builder: (context, value, child) {
          final bool isFilled = value.text.isNotEmpty;
          return TextFormField(
            controller: ctrl,
            enabled: enabled,
            keyboardType: type,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack87),
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              hintStyle: const TextStyle(color: kBlack54, fontSize: 12, fontWeight: FontWeight.w400),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12.0),
                child: HeroIcon(icon, color: enabled ? (isFilled ? kPrimaryColor : kBlack54) : kGrey400, size: 18),
              ),
              filled: true,
              fillColor: kGreyBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isFilled ? kPrimaryColor : kGrey200, width: isFilled ? 1.5 : 1.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isFilled ? kPrimaryColor : kGrey200, width: isFilled ? 1.5 : 1.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kPrimaryColor, width: 2.0),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kErrorColor),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kErrorColor, width: 2.0),
              ),
              labelStyle: TextStyle(color: isFilled ? kPrimaryColor : kBlack54, fontSize: 13, fontWeight: FontWeight.w600),
              floatingLabelStyle: const TextStyle(color: kPrimaryColor, fontSize: 11, fontWeight: FontWeight.w900),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAdvancedDetailsToggle() {
    return InkWell(
      onTap: () => setState(() => _showAdvancedDetails = !_showAdvancedDetails),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: kGreyBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kGrey200, width: 1.0),
        ),
        child: Row(
          children: [
            HeroIcon(
              _showAdvancedDetails ? HeroIcons.chevronUp : HeroIcons.chevronDown,
              color: kPrimaryColor,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _showAdvancedDetails ? "Hide Advanced Details" : "Show Advanced Details (Optional)",
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: kPrimaryColor, letterSpacing: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _businessLocationCtrl,
        builder: (context, value, child) {
          final bool isFilled = value.text.isNotEmpty;
          return TextFormField(
            controller: _businessLocationCtrl,
            keyboardType: TextInputType.streetAddress,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kBlack87),
            maxLines: 3,
            minLines: 1,
            decoration: InputDecoration(
              labelText: "Address",
              hintText: "Enter full business address",
              hintStyle: const TextStyle(color: kBlack54, fontSize: 13, fontWeight: FontWeight.normal),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12.0),
                child: HeroIcon(HeroIcons.mapPin, color: isFilled ? kPrimaryColor : kBlack54, size: 18),
              ),
              filled: true,
              fillColor: kGreyBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isFilled ? kPrimaryColor : kGrey200, width: isFilled ? 1.5 : 1.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isFilled ? kPrimaryColor : kGrey200, width: isFilled ? 1.5 : 1.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: kPrimaryColor, width: 2.0),
              ),
              labelStyle: TextStyle(color: isFilled ? kPrimaryColor : kBlack54, fontSize: 13, fontWeight: FontWeight.w600),
              floatingLabelStyle: const TextStyle(color: kPrimaryColor, fontSize: 11, fontWeight: FontWeight.w900),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCurrencyField({bool isMandatory = false}) {
    final sel = _currencies.firstWhere((c) => c['code'] == _selectedCurrency, orElse: () => _currencies[0]);
    final hasValue = _selectedCurrency.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: _showCurrencyPicker,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kGreyBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: hasValue ? kPrimaryColor : kGrey200, width: hasValue ? 1.5 : 1.0),
          ),
          child: Row(
            children: [
              const HeroIcon(HeroIcons.banknotes, color: kPrimaryColor, size: 18),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Business Currency ${isMandatory ? '*' : ''}",
                      style: const TextStyle(fontSize: 9, color: kBlack54, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "${sel['symbol']} ${sel['code']} - ${sel['name']}",
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kBlack87),
                    ),
                  ],
                ),
              ),
              const HeroIcon(HeroIcons.chevronDown, color: kGrey400),
            ],
          ),
        ),
      ),
    );
  }

  void _showCurrencyPicker() {
    String searchQuery = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredCurrencies = _currencies.where((currency) {
              if (searchQuery.isEmpty) return true;
              final query = searchQuery.toLowerCase();
              return currency['code']!.toLowerCase().contains(query) ||
                  currency['name']!.toLowerCase().contains(query) ||
                  currency['symbol']!.toLowerCase().contains(query);
            }).toList();

            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.75,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Text("Select Currency",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kBlack87, letterSpacing: 0.5)),
                    const SizedBox(height: 20),
                    TextField(
                      autofocus: false,
                      decoration: InputDecoration(
                        hintText: 'Search currency...',
                        hintStyle: const TextStyle(fontSize: 13, color: kGrey400),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: HeroIcon(HeroIcons.magnifyingGlass, color: kPrimaryColor, size: 20),
                        ),
                        filled: true,
                        fillColor: kGreyBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (value) => setModalState(() => searchQuery = value),
                    ),
                    const SizedBox(height: 16),
                    if (searchQuery.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${filteredCurrencies.length} ${filteredCurrencies.length == 1 ? 'currency' : 'currencies'} found',
                            style: const TextStyle(fontSize: 11, color: kBlack54, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    Expanded(
                      child: filteredCurrencies.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  HeroIcon(HeroIcons.magnifyingGlass, size: 48, color: kGrey400),
                                  SizedBox(height: 12),
                                  Text('No currencies found', style: TextStyle(color: kGrey400, fontSize: 14)),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: filteredCurrencies.length,
                              separatorBuilder: (_, __) => const Divider(height: 1, color: kGrey100),
                              itemBuilder: (context, i) {
                                final c = filteredCurrencies[i];
                                final isSelected = c['code'] == _selectedCurrency;
                                return ListTile(
                                  onTap: () {
                                    setState(() => _selectedCurrency = c['code']!);
                                    Navigator.pop(ctx);
                                  },
                                  contentPadding: EdgeInsets.zero,
                                  leading: Container(
                                    width: 40, height: 40,
                                    decoration: BoxDecoration(
                                      color: isSelected ? kPrimaryColor.withValues(alpha: 0.1) : kGreyBg,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Text(c['symbol']!,
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected ? kPrimaryColor : kBlack54)),
                                    ),
                                  ),
                                  title: Text(c['name']!,
                                      style: TextStyle(
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                          fontSize: 14,
                                          color: isSelected ? kPrimaryColor : kBlack87)),
                                  subtitle: Text(c['code']!,
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: isSelected ? kPrimaryColor : kBlack54,
                                          fontWeight: FontWeight.w500)),
                                  trailing: isSelected
                                      ? const HeroIcon(HeroIcons.checkCircle, color: kPrimaryColor, size: 24)
                                      : null,
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBottomActionArea() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: kWhite,
          border: Border(top: BorderSide(color: kGrey200)),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _loading ? null : _saveBusinessDetails,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryColor,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _loading
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: kWhite))
                : const Text(
                    "Complete Registration",
                    style: TextStyle(color: kWhite, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                  ),
          ),
        ),
      ),
    );
  }
}
