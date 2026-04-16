import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:maxbillup/utils/translation_helper.dart';
import 'package:maxbillup/utils/responsive_helper.dart';
import 'package:maxbillup/Colors.dart';

class SaleAppBar extends StatelessWidget {
  final int selectedTabIndex;
  final Function(int) onTabChanged;
  final double screenWidth;
  final double screenHeight;
  final String uid;
  final String? userEmail;
  final bool hideSavedTab;
  final bool showBackButton;
  final int savedOrderCount;

  const SaleAppBar({
    super.key,
    required this.selectedTabIndex,
    required this.onTabChanged,
    required this.screenWidth,
    required this.screenHeight,
    required this.uid,
    this.userEmail,
    this.hideSavedTab = false,
    this.showBackButton = false,
    this.savedOrderCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = screenWidth * 0.04;
    final double tabHeight = R.sp(context, 44);

    // Helper to determine alignment for the sliding pill
    double getAlignment() {
      if (hideSavedTab) {
        return selectedTabIndex == 1 ? -1.0 : 1.0;
      } else {
        if (selectedTabIndex == 0) return -1.0; // saved
        if (selectedTabIndex == 1) return 0.0;  // View All
        return 1.0;                             // Quick Bill
      }
    }

    return Container(
      color: kWhite,
      padding: EdgeInsets.fromLTRB(horizontalPadding, 0, R.sp(context, 16), 8),
      child: Row(
        children: [
          if (showBackButton) ...[
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: R.all(context, 10),
                decoration: BoxDecoration(
                  color: kGreyBg,
                  borderRadius: R.radius(context, 12),
                  border: Border.all(color: kGrey200),
                ),
                child: HeroIcon(HeroIcons.arrowLeft, color: kBlack87, size: R.sp(context, 16)),
              ),
            ),
            SizedBox(width: R.sp(context, 12)),
          ],

          Expanded(
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
                    alignment: Alignment(getAlignment(), 0),
                    child: FractionallySizedBox(
                      widthFactor: hideSavedTab ? 0.5 : 0.33,
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

                  // Tab Labels
                  Row(
                    children: [
                      if (!hideSavedTab) ...[
                        _buildTab(context.tr('saved'), 0),
                      ],
                      _buildTab(context.tr('View All'), 1),
                      _buildTab(context.tr('Quick Bill'), 2),
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

  Widget _buildTab(String text, int index) {
    final isSelected = selectedTabIndex == index;
    final isSavedTab = index == 0 && !hideSavedTab;
    final showBadge = isSavedTab && savedOrderCount > 0;

    return Expanded(
      child: GestureDetector(
        onTap: () => onTabChanged(index),
        behavior: HitTestBehavior.opaque,
        child: Builder(
          builder: (context) => Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    color: isSelected ? kWhite : Colors.black,
                    fontSize: R.sp(context, 13),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                if (showBadge) ...[
                  SizedBox(width: R.sp(context, 6)),
                  Container(
                    width: R.sp(context, 18),
                    height: R.sp(context, 18),
                    decoration: BoxDecoration(
                      color: isSelected ? kWhite : kPrimaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        savedOrderCount > 99 ? '99' : savedOrderCount.toString(),
                        style: TextStyle(
                          color: isSelected ? kPrimaryColor : kWhite,
                          fontSize: R.sp(context, 9),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
