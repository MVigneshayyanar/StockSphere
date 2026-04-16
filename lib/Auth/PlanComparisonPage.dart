import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:maxbillup/Colors.dart';

class PlanComparisonPage extends StatelessWidget {
  const PlanComparisonPage({super.key});

  // Feature list matching the image exactly
  static const List<Map<String, dynamic>> _features = [
    {'name': 'No. of. Users (Admin+ Users)', 'free': '1', 'lite': '1', 'plus': 'Admin +\n2 users', 'pro': 'Admin +\n9 users'},
    {'name': 'POS Billing', 'free': true, 'lite': true, 'plus': true, 'pro': true},
    {'name': 'Purchases', 'free': true, 'lite': true, 'plus': true, 'pro': true},
    {'name': 'Expenses', 'free': true, 'lite': true, 'plus': true, 'pro': true},
    {'name': 'Credit Sales', 'free': true, 'lite': true, 'plus': true, 'pro': true},
    {'name': 'Cloud Backup', 'free': true, 'lite': true, 'plus': true, 'pro': true},
    {'name': 'Unlimited Products', 'free': true, 'lite': true, 'plus': true, 'pro': true},
    {'name': 'Bill History', 'free': 'upto 15 days', 'lite': true, 'plus': true, 'pro': true},
    {'name': 'Edit Bill', 'free': false, 'lite': true, 'plus': true, 'pro': true},
    {'name': 'Reports', 'free': false, 'lite': true, 'plus': true, 'pro': true},
    {'name': 'Tax Reports', 'free': false, 'lite': true, 'plus': true, 'pro': true},
    {'name': 'Quotation / Estimation', 'free': false, 'lite': true, 'plus': true, 'pro': true},
    {'name': 'Import Customers', 'free': false, 'lite': true, 'plus': true, 'pro': true},
    {'name': 'Support', 'free': false, 'lite': true, 'plus': true, 'pro': true},
    {'name': 'Customer Dues', 'free': false, 'lite': true, 'plus': true, 'pro': true},
    {'name': 'Bulk Product Upload', 'free': false, 'lite': true, 'plus': true, 'pro': true},
    {'name': 'Logo on Bill', 'free': false, 'lite': true, 'plus': true, 'pro': true},
    {'name': 'Remove Watermark', 'free': false, 'lite': true, 'plus': true, 'pro': true},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhite,
      appBar: AppBar(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const HeroIcon(HeroIcons.arrowLeft, color: kWhite, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Plan Comparison',
          style: TextStyle(
            color: kWhite,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Sticky header with plan names
          _buildStickyHeader(),
          // Scrollable content
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: _features.length,
              itemBuilder: (context, index) {
                return _buildFeatureRow(_features[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: const BoxDecoration(
        color: kWhite,
        border: Border(bottom: BorderSide(color: kGrey200, width: 1)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 100), // Space for feature name column
          Expanded(child: _buildPlanHeader('Free', kOrange)),
          Expanded(child: _buildPlanHeader('MAX One', kPrimaryColor)),
          Expanded(child: _buildPlanHeader('MAX Plus', Colors.purple)),
          Expanded(child: _buildPlanHeader('MAX Pro', kGoogleGreen)),
        ],
      ),
    );
  }

  Widget _buildPlanHeader(String name, Color color) {
    return Text(
      name,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontWeight: FontWeight.w900,
        fontSize: 10,
        color: color,
      ),
    );
  }

  Widget _buildFeatureRow(Map<String, dynamic> feature) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      decoration: const BoxDecoration(
        color: kWhite,
        border: Border(bottom: BorderSide(color: kGrey100, width: 1)),
      ),
      child: Row(
        children: [
          // Feature name
          SizedBox(
            width: 96,
            child: Text(
              feature['name'],
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 10,
                color: kBlack87,
              ),
            ),
          ),
          // Plan columns
          Expanded(child: _buildValueCell(feature['free'])),
          Expanded(child: _buildValueCell(feature['lite'])),
          Expanded(child: _buildValueCell(feature['plus'])),
          Expanded(child: _buildValueCell(feature['pro'])),
        ],
      ),
    );
  }

  Widget _buildValueCell(dynamic value) {
    if (value is bool) {
      return Center(
        child: HeroIcon(
          value ? HeroIcons.check : HeroIcons.xMark,
          color: value ? kGoogleGreen : kErrorColor,
          size: 18,
        ),
      );
    } else {
      return Center(
        child: Text(
          value.toString(),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 9,
            color: kBlack87,
          ),
        ),
      );
    }
  }
}
