import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:maxbillup/Sales/NewSale.dart';
import 'package:maxbillup/Settings/Profile.dart' hide kPrimaryColor, kBlack54;
import 'package:maxbillup/Stocks/Stock.dart' as stock;
import 'package:maxbillup/Reports/Reports.dart' hide kPrimaryColor;
import 'package:maxbillup/Menu/Menu.dart' hide kWhite, kPrimaryColor;
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/utils/responsive_helper.dart';
import 'package:maxbillup/Colors.dart';

class CommonBottomNav extends StatelessWidget {
  final String uid;
  final String? userEmail;
  final int currentIndex;
  final double screenWidth;

  const CommonBottomNav({
    super.key,
    required this.uid,
    this.userEmail,
    required this.currentIndex,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate width for 5 items
    final itemWidth = screenWidth / 5;
    final indicatorWidth = itemWidth * 0.45; // Refined width for enterprise look

    return Container(
      decoration: BoxDecoration(
        color: kWhite,
        // Add rounded top-left and top-right corners with 24 radius
        borderRadius: BorderRadius.vertical(top: Radius.circular(R.sp(context, 24))),
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      child: SafeArea(
        child: Container(
          height: R.sp(context, 68),
          padding: EdgeInsets.only(bottom: R.sp(context, 4)),
          child: Stack(
            children: [
              // Sliding animated indicator bar (Flat design)
              AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                curve: Curves.fastOutSlowIn,
                alignment: Alignment(-1.0 + (currentIndex * 0.5), -1.0),
                child: Container(
                  width: itemWidth,
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: indicatorWidth,
                    height: 3, // Slimmer bar
                    decoration: BoxDecoration(
                      color: kPrimaryColor,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
              // Nav items
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(context, 0, HeroIcons.squares2x2, context.tr('menu')),
                  _buildNavItem(context, 1, HeroIcons.chartBar, context.tr('Growth+')),
                  _buildNavItem(context, 2, HeroIcons.plusCircle, context.tr('new_sale')),
                  _buildNavItem(context, 3, HeroIcons.archiveBox, context.tr("Items")),
                  _buildNavItem(context, 4, HeroIcons.cog6Tooth, context.tr('settings')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, HeroIcons icon, String label) {
    final isSelected = currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => _handleNavigation(context, index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: R.sp(context, 6)),
            HeroIcon(
              icon,
              color: isSelected ? kPrimaryColor : Colors.grey[700],
              size: R.sp(context, 26),
            ),
            SizedBox(height: R.sp(context, 4)),
            Text(
              label, // Enterprise standard uppercase
              style: TextStyle(
                fontSize: R.sp(context, 12),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? kPrimaryColor : Colors.grey[700],
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNavigation(BuildContext context, int index) {
    if (index == currentIndex) return;

    Widget targetPage;
    switch (index) {
      case 0:
        targetPage = MenuPage(uid: uid, userEmail: userEmail);
        break;
      case 1:
        targetPage = ReportsPage(uid: uid, userEmail: userEmail);
        break;
      case 2:
        targetPage = NewSalePage(uid: uid, userEmail: userEmail);
        break;
      case 3:
        targetPage = stock.StockPage(uid: uid, userEmail: userEmail);
        break;
      case 4:
        targetPage = SettingsPage(uid: uid, userEmail: userEmail);
        break;
      default:
        return;
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetPage,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }
}
