import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maxbillup/Stocks/Products.dart' hide AddProductPage;
import 'package:maxbillup/Stocks/Category.dart';
import 'package:maxbillup/Stocks/Components/stock_app_bar.dart';
import 'package:maxbillup/Stocks/AddProduct.dart';
import 'package:maxbillup/components/common_bottom_nav.dart';
import 'package:maxbillup/Menu/Menu.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:heroicons/heroicons.dart';

class StockPage extends StatefulWidget {
  final String uid;
  final String? userEmail;

  const StockPage({
    super.key,
    required this.uid,
    this.userEmail,
  });

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  final TextEditingController _searchController = TextEditingController();
  int _selectedTabIndex = 0;

  late String _uid;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _uid = widget.uid;
    _userEmail = widget.userEmail;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Stock AppBar Component
          StockAppBar(
            uid: _uid,
            userEmail: _userEmail,
            searchController: _searchController,
            selectedTabIndex: _selectedTabIndex,
            onTabChanged: (index) {
              setState(() {
                _selectedTabIndex = index;
              });
            },
            onAddProduct: () {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => AddProductPage(uid: _uid, userEmail: _userEmail),
                ),
              );
            },
            buildActionButton: _buildActionButton,
            screenWidth: MediaQuery.of(context).size.width,
            screenHeight: MediaQuery.of(context).size.height,
          ),

          // Content area - Show Products or Category based on selected tab
          Expanded(
            child: _selectedTabIndex == 0
                ? ProductsPage(uid: _uid, userEmail: _userEmail)
                : CategoryPage(uid: _uid, userEmail: _userEmail),
          ),

        ],

      ),
      bottomNavigationBar: CommonBottomNav(
        uid: widget.uid,
        userEmail: widget.userEmail,
        currentIndex: 3,
        screenWidth: MediaQuery.of(context).size.width,
      ),
    );
  }

  Widget _buildActionButton(HeroIcons icon, Color color) {
    return Container(
      height: 48,
      width: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: HeroIcon(icon, color: color, size: 24),
    );
  }
}
