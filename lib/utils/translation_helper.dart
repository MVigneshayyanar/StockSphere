import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:maxbillup/utils/language_provider.dart';

/// Helper widget to display translated text
/// Usage: TranslatedText('key')
class TranslatedText extends StatelessWidget {
  final String translationKey;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const TranslatedText(
    this.translationKey, {
    Key? key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);
    return Text(
      languageProvider.translate(translationKey),
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// Extension to easily access translations in code
extension TranslationExtension on BuildContext {
  String tr(String key) {
    return Provider.of<LanguageProvider>(this, listen: false).translate(key);
  }

  LanguageProvider get lang => Provider.of<LanguageProvider>(this, listen: false);
}

