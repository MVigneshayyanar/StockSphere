import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maxbillup/utils/responsive_helper.dart';

/// Helper class to optimize keyboard performance and behavior
class KeyboardHelper {
  /// Optimized TextField decoration for better keyboard performance
  static InputDecoration optimizedDecoration({
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    BorderRadius? borderRadius,
    BuildContext? context,
  }) {
    final radius = context != null
        ? R.radius(context, 8)
        : BorderRadius.circular(8);
    final padding = context != null
        ? EdgeInsets.symmetric(horizontal: R.sp(context, 16), vertical: R.sp(context, 12))
        : const EdgeInsets.symmetric(horizontal: 16, vertical: 12);

    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(borderRadius: borderRadius ?? radius),
      enabledBorder: OutlineInputBorder(borderRadius: borderRadius ?? radius),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadius ?? radius,
        borderSide: const BorderSide(color: Color(0xFF2F7CF6), width: 2),
      ),
      contentPadding: padding,
      // Disable dense mode for better performance
      isDense: false,
    );
  }

  /// Hide keyboard
  static void hideKeyboard(BuildContext context) {
    FocusScope.of(context).unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  /// Show keyboard for a specific field
  static void showKeyboard(BuildContext context, FocusNode focusNode) {
    FocusScope.of(context).requestFocus(focusNode);
  }

  /// Dismiss keyboard on tap outside
  static Widget dismissKeyboardOnTap({
    required BuildContext context,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: () => hideKeyboard(context),
      child: child,
    );
  }

  /// Optimized TextField widget with better keyboard performance
  static Widget optimizedTextField({
    required TextEditingController controller,
    String? labelText,
    String? hintText,
    TextInputType? keyboardType,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool obscureText = false,
    int? maxLines = 1,
    int? maxLength,
    ValueChanged<String>? onChanged,
    VoidCallback? onTap,
    bool readOnly = false,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
    Function(String)? onSubmitted,
  }) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final bool hasText = value.text.isNotEmpty;
        return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      maxLength: maxLength,
      onChanged: onChanged,
      onTap: onTap,
      readOnly: readOnly,
      focusNode: focusNode,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      // Optimize keyboard appearance
      enableInteractiveSelection: true,
      autocorrect: false,
      enableSuggestions: false,
      decoration: optimizedDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
    );
      },
    );
  }

  /// Wrap a form with optimized keyboard handling
  static Widget optimizedForm({
    required BuildContext context,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: () => hideKeyboard(context),
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }

  /// Optimize keyboard animation speed (call once in main or splash)
  static void configureKeyboardOptimizations() {
    // Set system UI overlay style for better keyboard transition
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );

    // Enable edge-to-edge mode for better keyboard performance
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top],
    );
  }
}

/// Mixin to add keyboard optimization to StatefulWidgets
mixin KeyboardOptimizationMixin<T extends StatefulWidget> on State<T> {
  final List<FocusNode> _focusNodes = [];

  /// Create an optimized focus node
  FocusNode createFocusNode() {
    final focusNode = FocusNode();
    _focusNodes.add(focusNode);
    return focusNode;
  }

  @override
  void dispose() {
    // Dispose all focus nodes
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  /// Hide keyboard
  void hideKeyboard() {
    KeyboardHelper.hideKeyboard(context);
  }
}
