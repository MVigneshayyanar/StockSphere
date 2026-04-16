import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:maxbillup/Colors.dart';

class ReferralService {
  static const String _keyFirstLaunch = 'first_launch_date';
  static const String _keyUsageCount = 'app_usage_count';
  static const String _keyLastReferralShown = 'last_referral_shown';
  static const String _keyReferralDismissed = 'referral_dismissed';

  /// Initialize referral tracking on app launch
  static Future<void> trackAppLaunch() async {
    final prefs = await SharedPreferences.getInstance();

    // Set first launch date if not set
    if (!prefs.containsKey(_keyFirstLaunch)) {
      await prefs.setString(_keyFirstLaunch, DateTime.now().toIso8601String());
      await prefs.setInt(_keyUsageCount, 1);
    } else {
      // Increment usage count
      final currentCount = prefs.getInt(_keyUsageCount) ?? 0;
      await prefs.setInt(_keyUsageCount, currentCount + 1);
    }
  }

  /// Check if referral popup should be shown
  static Future<bool> shouldShowReferral() async {
    final prefs = await SharedPreferences.getInstance();

    // Don't show if user dismissed it permanently
    if (prefs.getBool(_keyReferralDismissed) ?? false) {
      return false;
    }

    final firstLaunchStr = prefs.getString(_keyFirstLaunch);
    if (firstLaunchStr == null) return false;

    final firstLaunch = DateTime.parse(firstLaunchStr);
    final now = DateTime.now();
    final daysSinceFirstLaunch = now.difference(firstLaunch).inDays;

    final usageCount = prefs.getInt(_keyUsageCount) ?? 0;
    final lastShownStr = prefs.getString(_keyLastReferralShown);

    // Show after 30 days OR after 20 uses (whichever comes first)
    bool shouldShow = false;

    if (daysSinceFirstLaunch >= 30 && usageCount >= 10) {
      shouldShow = true;
    } else if (usageCount >= 20) {
      shouldShow = true;
    }

    // Don't show too frequently - at least 7 days between popups
    if (shouldShow && lastShownStr != null) {
      final lastShown = DateTime.parse(lastShownStr);
      final daysSinceLastShown = now.difference(lastShown).inDays;
      if (daysSinceLastShown < 7) {
        shouldShow = false;
      }
    }

    return shouldShow;
  }

  /// Mark that referral popup was shown
  static Future<void> markReferralShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastReferralShown, DateTime.now().toIso8601String());
  }

  /// Mark that user dismissed the referral popup permanently
  static Future<void> markReferralDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyReferralDismissed, true);
  }

  /// Show referral dialog
  static Future<void> showReferralDialog(BuildContext context) async {
    await markReferralShown();

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: kWhite,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: kPrimaryColor,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                const Text(
                  'Growing with MAXmybill?',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: kBlack87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Message
                const Text(
                  'Help your friends and family grow their business too! Share MAXmybill with them.',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: kBlack54,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Share Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _shareApp();
                    },
                    icon: const Icon(Icons.share_rounded, size: 20),
                    label: const Text(
                      'SHARE MAXmybill ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      foregroundColor: kWhite,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Later Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Maybe Later',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kBlack54,
                      ),
                    ),
                  ),
                ),

                // Don't show again
                // TextButton(
                //   onPressed: () async {
                //     await markReferralDismissed();
                //     Navigator.pop(context);
                //   },
                //   child: const Text(
                //     "Don't show again",
                //     style: TextStyle(
                //       fontSize: 12,
                //       fontWeight: FontWeight.w500,
                //       color: kBlack54,
                //       decoration: TextDecoration.underline,
                //     ),
                //   ),
                // ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Share the app
  static Future<void> _shareApp() async {
    const String message = '''
🌟 Grow Your Business with MAXmybill! 🌟

I've been using MAXmybill for my business and it's amazing! 

✅ Easy billing & invoicing
✅ Inventory management
✅ Customer tracking
✅ Sales reports & insights
✅ TAX compliant

Download now: www.maxmybill.com

#MAXmybill #BusinessMAX Plus #Billing
''';

    await Share.share(message, subject: 'Check out MAXmybill!');
  }

  /// Get usage statistics (for debugging)
  static Future<Map<String, dynamic>> getUsageStats() async {
    final prefs = await SharedPreferences.getInstance();
    final firstLaunchStr = prefs.getString(_keyFirstLaunch);
    final usageCount = prefs.getInt(_keyUsageCount) ?? 0;
    final isDismissed = prefs.getBool(_keyReferralDismissed) ?? false;

    return {
      'firstLaunch': firstLaunchStr,
      'usageCount': usageCount,
      'isDismissed': isDismissed,
      'daysSinceFirstLaunch': firstLaunchStr != null
          ? DateTime.now().difference(DateTime.parse(firstLaunchStr)).inDays
          : 0,
    };
  }
}

