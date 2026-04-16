import 'package:flutter/material.dart';
import 'package:maxbillup/Colors.dart';

class BillPrintSettingsPage extends StatefulWidget {
  final VoidCallback onBack;

  const BillPrintSettingsPage({super.key, required this.onBack});

  @override
  State<BillPrintSettingsPage> createState() => _BillPrintSettingsPageState();
}

class _BillPrintSettingsPageState extends State<BillPrintSettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill & Print Settings'),
        backgroundColor: kPrimaryColor,
        foregroundColor: kWhite,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: widget.onBack,
        ),
      ),
      body: const Center(
        child: Text('Bill & Print Settings Page Content'),
      ),
    );
  }
}

