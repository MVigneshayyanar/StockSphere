import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:maxbillup/utils/firestore_service.dart';
import 'package:maxbillup/utils/responsive_helper.dart';
import 'package:maxbillup/Auth/SubscriptionPlanPage.dart';
import 'package:maxbillup/Colors.dart';

/// Helper class for plan permission checks - fetches fresh data from Firestore every time
class PlanPermissionHelper {
  static const String PLAN_FREE = 'Free';
  static const String PLAN_STARTER = 'Starter';
  static const String PLAN_MAXOne = 'MAX One';
  static const String PLAN_MAXPlus = 'MAX Plus';
  static const String PLAN_MAX = 'MAX Pro';

  /// Check if plan is a free/starter plan
  static bool _isPlanFree(String plan) {
    final planLower = plan.toLowerCase();
    return planLower == 'free' || planLower == 'starter';
  }

  /// Load plan data from Firestore (fresh fetch every time)
  static Future<String> _loadPlanData() async {
    try {
      final storeDoc = await FirestoreService().getCurrentStoreDoc();

      if (storeDoc == null || !storeDoc.exists) {
        return PLAN_FREE;
      }

      final data = storeDoc.data() as Map<String, dynamic>?;
      String? planValue = data?['plan']?.toString();

      if (planValue == null || planValue.trim().isEmpty) {
        return PLAN_FREE;
      }

      final plan = planValue.trim();

      // Check expiry for paid plans (case-insensitive check)
      if (!_isPlanFree(plan)) {
        final expiryDateStr = data?['subscriptionExpiryDate']?.toString();
        if (expiryDateStr != null && expiryDateStr.isNotEmpty) {
          try {
            final expiryDate = DateTime.parse(expiryDateStr);
            if (DateTime.now().isAfter(expiryDate)) {
              debugPrint('🔍 _loadPlanData: Plan "$plan" is EXPIRED, returning Free');
              return PLAN_FREE;
            }
          } catch (e) {
            debugPrint('🔍 _loadPlanData: Error parsing expiry date: $e - continuing with plan');
            // Don't return FREE on parse error - just continue with the plan
          }
        }
      }
      debugPrint('🔍 _loadPlanData: Returning plan="$plan"');
      return plan;
    } catch (e) {
      return PLAN_FREE;
    }
  }

  static Future<String> getCurrentPlan() async {
    return await _loadPlanData();
  }

  static Future<int> getMaxStaffCount() async {
    final plan = await _loadPlanData();
    return _getMaxStaffCountForPlan(plan);
  }

  static int _getMaxStaffCountForPlan(String plan) {
    final planLower = plan.toLowerCase();
    switch (planLower) {
      case 'free':
      case 'starter':
        return 0;
      case 'max one':
      case 'max lite':
        return 1; // Admin + 1 Manager
      case 'max plus':
        return 3; // Admin + 3 Staff
      case 'max pro':
        return 15; // Admin + 15 Staff
      default:
        return 0;
    }
  }

  static Future<bool> canAccessFullBillHistory() async {
    final plan = await _loadPlanData();
    return !_isPlanFree(plan);
  }

  static Future<bool> canAccessDaybook() async {
    return true; // Daybook is FREE for everyone
  }

  static Future<bool> canAccessReports() async {
    final plan = await _loadPlanData();
    return !_isPlanFree(plan);
  }

  static Future<bool> canAccessQuotation() async {
    final plan = await _loadPlanData();
    return !_isPlanFree(plan);
  }

  static Future<bool> canAccessStaffManagement() async {
    final plan = await _loadPlanData();
    final planLower = plan.toLowerCase();
    debugPrint('🔍 canAccessStaffManagement: plan="$plan", planLower="$planLower"');
    final canAccess = planLower == 'max one' || planLower == 'max lite' || planLower == 'max plus' || planLower == 'max pro';
    debugPrint('🔍 canAccessStaffManagement: canAccess=$canAccess');
    return canAccess;
  }

  static Future<bool> canEditBill() async {
    final plan = await _loadPlanData();
    return !_isPlanFree(plan);
  }

  static Future<bool> canAccessCustomerCredit() async {
    final plan = await _loadPlanData();
    return !_isPlanFree(plan);
  }

  static Future<bool> canUseLogoOnBill() async {
    final plan = await _loadPlanData();
    return !_isPlanFree(plan);
  }

  static Future<bool> canImportContacts() async {
    final plan = await _loadPlanData();
    return !_isPlanFree(plan);
  }

  static Future<bool> canUseBulkInventory() async {
    final plan = await _loadPlanData();
    return !_isPlanFree(plan);
  }

  static Future<bool> canRemoveWatermark() async {
    final plan = await _loadPlanData();
    return !_isPlanFree(plan);
  }

  static Future<bool> canAddMoreStaff(int currentStaffCount) async {
    final maxStaff = await getMaxStaffCount();
    if (maxStaff == 0) return false;
    return currentStaffCount < maxStaff;
  }

  static Future<int> getBillHistoryDaysLimit() async {
    final plan = await _loadPlanData();
    // Free and Starter plans get 7 days, paid plans get unlimited
    return _isPlanFree(plan) ? 7 : 36500; // ~100 years (unlimited)
  }

  /// Enterprise Upgrade Dialog (Redesigned UI)
  static void showUpgradeDialog(BuildContext context, String featureName, {String? uid, String? currentPlan}) async {
    String plan = currentPlan ?? PLAN_FREE;
    if (currentPlan == null) {
      plan = await getCurrentPlan();
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: kWhite,
        shape: RoundedRectangleBorder(borderRadius: R.radius(context, 24)),
        child: Padding(
          padding: R.all(context, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // High-Density Icon
              Container(
                width: R.sp(context, 64), height: R.sp(context, 64),
                decoration: BoxDecoration(
                  color: kOrange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_rounded, color: kOrange, size: R.sp(context, 32)),
              ),
              SizedBox(height: R.sp(context, 24)),
              // Header
              Text(
                "Upgrade Required",
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: R.sp(context, 16), color: kBlack87, letterSpacing: 1.0),
              ),
              SizedBox(height: R.sp(context, 12)),
              // Content
              Text(
                '$featureName is a premium feature. Upgrade to unlock advanced analytics, staff management, and professional branding.',
                textAlign: TextAlign.center,
                style: TextStyle(color: kBlack54, fontSize: R.sp(context, 13), height: 1.5, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: R.sp(context, 32)),
              // Actions
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Maybe later', style: TextStyle(color: kBlack54, fontWeight: FontWeight.w800, fontSize: R.sp(context, 11))),
                    ),
                  ),
                  SizedBox(width: R.sp(context, 12)),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        if (uid != null) {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) => SubscriptionPlanPage(
                                uid: uid,
                                currentPlan: plan,
                              ),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: R.radius(context, 12)),
                        padding: EdgeInsets.symmetric(vertical: R.sp(context, 14)),
                      ),
                      child: Text('Upgrade now', style: TextStyle(color: kWhite, fontWeight: FontWeight.w900, fontSize: R.sp(context, 11))),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}