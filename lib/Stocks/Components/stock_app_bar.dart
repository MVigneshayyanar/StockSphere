import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maxbillup/Colors.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/utils/responsive_helper.dart';
import 'package:heroicons/heroicons.dart';

class StockAppBar extends StatelessWidget {
  final String uid;
  final String? userEmail;
  final TextEditingController searchController;
  final int selectedTabIndex;
  final Function(int) onTabChanged;
  final VoidCallback onAddProduct;
  final double screenWidth;
  final double screenHeight;
  final Widget Function(HeroIcons, Color) buildActionButton;

  const StockAppBar({
    super.key,
    required this.uid,
    this.userEmail,
    required this.searchController,
    required this.selectedTabIndex,
    required this.onTabChanged,
    required this.onAddProduct,
    required this.screenWidth,
    required this.screenHeight,
    required this.buildActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final double tabHeight = R.sp(context, 44);

    return Container(
      padding: EdgeInsets.only(top: topPadding + R.sp(context, 10), bottom: R.sp(context, 12)),
      decoration: const BoxDecoration(
        color: kWhite,
        border: Border(bottom: BorderSide(color: kGrey200, width: 1)),
      ),
      child: Column(
        children: [
          // ENTERPRISE FLAT TABS
          Container(
            padding: EdgeInsets.symmetric(horizontal: R.sp(context, 16)),
            child: Container(
              height: tabHeight + R.sp(context, 8),
              padding: R.all(context, 4),
              decoration: BoxDecoration(
                color: kGreyBg,
                borderRadius: R.radius(context, 14),
                border: Border.all(color: kPrimaryColor, width: 1),
              ),
              child: Stack(
                children: [
                  // Animated Sliding Pill
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.fastOutSlowIn,
                    alignment: Alignment(selectedTabIndex == 0 ? -1.0 : 1.0, 0),
                    child: FractionallySizedBox(
                      widthFactor: 0.5,
                      child: Container(
                        decoration: BoxDecoration(
                          color: kPrimaryColor,
                          borderRadius: R.radius(context, 10),
                          boxShadow: [
                            BoxShadow(
                              color: kPrimaryColor.withOpacity(0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Tab Labels with Real-time Counts
                  Row(
                    children: [
                      // Product Tab
                      _buildTabWithCount(
                        context,
                        label: context.tr('products'),
                        collection: 'Products',
                        index: 0,
                      ),
                      // Category Tab
                      _buildTabWithCount(
                        context,
                        label: context.tr('category'),
                        collection: 'categories',
                        index: 1,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabWithCount(BuildContext context, {required String label, required String collection, required int index}) {
    return Expanded(
      child: GestureDetector(
        onTap: () => onTabChanged(index),
        behavior: HitTestBehavior.opaque,
        child: FutureBuilder<Stream<QuerySnapshot>>(
          future: FirestoreService().getCollectionStream(collection),
          builder: (context, streamSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: streamSnapshot.data,
              builder: (context, snapshot) {
                final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
                final isSelected = selectedTabIndex == index;

                return Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: isSelected ? kWhite : kBlack54,
                          fontSize: R.sp(context, 13),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(width: R.sp(context, 6)),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: R.sp(context, 6), vertical: R.sp(context, 2)),
                        decoration: BoxDecoration(
                          color: isSelected ? kWhite.withOpacity(0.2) : kPrimaryColor.withOpacity(0.1),
                          borderRadius: R.radius(context, 6),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: isSelected ? kWhite : kPrimaryColor,
                            fontSize: R.sp(context, 9),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}