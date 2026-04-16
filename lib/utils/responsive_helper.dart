import 'package:flutter/material.dart';

/// Responsive utility — phone < 600, tablet 600–900, large > 900
class R {
  R._();

  // ── Screen dimensions ────────────────────────────
  static double w(BuildContext context) =>
      MediaQuery.of(context).size.width;
  static double h(BuildContext context) =>
      MediaQuery.of(context).size.height;

  // ── % of screen width / height ───────────────────
  static double wp(BuildContext context, double pct) =>
      MediaQuery.of(context).size.width * pct / 100;
  static double hp(BuildContext context, double pct) =>
      MediaQuery.of(context).size.height * pct / 100;

  // ── Scalable font size ────────────────────────────
  /// Base size is designed for a 390 px wide phone.
  static double sp(BuildContext context, double size) {
    final scale = MediaQuery.of(context).size.width / 390;
    return (size * scale).clamp(size * 0.85, size * 1.35);
  }

  // ── Scalable dimension (same formula, clearer intent) ──
  /// Use for padding, margin, SizedBox gaps, icon sizes, radius, etc.
  static double dp(BuildContext context, double size) => sp(context, size);

  // ── Scalable radius ──────────────────────────────
  static BorderRadius radius(BuildContext context, double r) =>
      BorderRadius.circular(sp(context, r));

  // ── Scalable symmetric padding shorthand ─────────
  static EdgeInsets symmetric(BuildContext context,
          {double h = 0, double v = 0}) =>
      EdgeInsets.symmetric(
          horizontal: sp(context, h), vertical: sp(context, v));

  static EdgeInsets all(BuildContext context, double value) =>
      EdgeInsets.all(sp(context, value));

  // ── Dialog / BottomSheet dimensions ──────────────
  static double dialogHeight(BuildContext context, {double pct = 70}) =>
      hp(context, pct);
  static double dialogWidth(BuildContext context, {double pct = 90}) =>
      wp(context, pct).clamp(0, 500);
  static double bottomSheetHeight(BuildContext context, {double pct = 75}) =>
      hp(context, pct);

  // ── Breakpoints ──────────────────────────────────
  static bool isPhone(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;
  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600 &&
      MediaQuery.of(context).size.width < 900;
  static bool isLarge(BuildContext context) =>
      MediaQuery.of(context).size.width >= 900;

  // ── Adaptive values ──────────────────────────────
  static T adaptive<T>(BuildContext context,
      {required T phone, T? tablet, T? large}) {
    if (isLarge(context)) return large ?? tablet ?? phone;
    if (isTablet(context)) return tablet ?? phone;
    return phone;
  }

  // ── Common adaptive sizes ─────────────────────────
  static double paddingH(BuildContext context) =>
      adaptive(context, phone: 16.0, tablet: 24.0, large: 32.0);
  static double paddingV(BuildContext context) =>
      adaptive(context, phone: 12.0, tablet: 18.0, large: 24.0);
  static double cardRadius(BuildContext context) =>
      adaptive(context, phone: 14.0, tablet: 16.0, large: 20.0);
  static double iconSize(BuildContext context) =>
      adaptive(context, phone: 20.0, tablet: 22.0, large: 24.0);
  static double appBarFontSize(BuildContext context) =>
      adaptive(context, phone: 15.0, tablet: 17.0, large: 19.0);
  static double bodyFontSize(BuildContext context) =>
      adaptive(context, phone: 13.0, tablet: 14.0, large: 15.0);
  static double titleFontSize(BuildContext context) =>
      adaptive(context, phone: 15.0, tablet: 17.0, large: 19.0);

  // ── Common font-size presets ──────────────────────
  /// Tiny labels / captions (8–9)
  static double captionSize(BuildContext context) => sp(context, 10);
  /// Section headers / overline (10–11)
  static double sectionSize(BuildContext context) => sp(context, 11);
  /// Subtitle / secondary text (12)
  static double subtitleSize(BuildContext context) => sp(context, 12);
  /// Body / default text (13–14)
  static double textSize(BuildContext context) => sp(context, 13);
  /// Heading / emphasis (16)
  static double headingSize(BuildContext context) => sp(context, 16);
  /// Large heading (18–20)
  static double largeHeadingSize(BuildContext context) => sp(context, 18);

  // ── AppBar / Section label helper ─────────────────
  static TextStyle sectionLabel(BuildContext context) => TextStyle(
        fontSize: sp(context, 10),
        fontWeight: FontWeight.w900,
        letterSpacing: 1.0,
        fontFamily: 'NotoSans',
      );

  // ── Grid columns ─────────────────────────────────
  static int gridColumns(BuildContext context) =>
      adaptive(context, phone: 2, tablet: 3, large: 4);

  // ── Max content width (for very large screens) ───
  static double maxContentWidth(BuildContext context) =>
      w(context).clamp(0, 720);

  // ── Responsive padding ───────────────────────────
  static EdgeInsets pagePadding(BuildContext context) => EdgeInsets.symmetric(
        horizontal: paddingH(context),
        vertical: paddingV(context),
      );

  // ── Bottom bar height ────────────────────────────
  static double bottomBarHeight(BuildContext context) =>
      adaptive(context, phone: 70.0, tablet: 80.0, large: 90.0);
}

