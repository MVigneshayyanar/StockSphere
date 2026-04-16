import 'package:flutter/material.dart';

/// A reusable button that prevents double-clicks by showing a loading indicator
/// and disabling itself while an async operation is in progress.
///
/// Use this for ANY button that triggers a backend operation (save, submit, etc.)
/// to prevent duplicate submissions.
class LoadingButton extends StatefulWidget {
  final Future<void> Function() onPressed;
  final Widget child;
  final Widget? loadingChild;
  final ButtonStyle? style;
  final bool enabled;
  final double? width;
  final double? height;

  const LoadingButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.loadingChild,
    this.style,
    this.enabled = true,
    this.width,
    this.height,
  });

  @override
  State<LoadingButton> createState() => _LoadingButtonState();
}

class _LoadingButtonState extends State<LoadingButton>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handlePress() async {
    if (_isLoading || !widget.enabled) return;

    // Tap animation
    await _animController.forward();
    _animController.reverse();

    setState(() => _isLoading = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final button = ScaleTransition(
      scale: _scaleAnimation,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: ElevatedButton(
          onPressed: (_isLoading || !widget.enabled) ? null : _handlePress,
          style: widget.style,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _isLoading
                ? (widget.loadingChild ??
                    const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    ))
                : widget.child,
          ),
        ),
      ),
    );

    return button;
  }
}

/// Same concept but for OutlinedButton style
class LoadingOutlinedButton extends StatefulWidget {
  final Future<void> Function() onPressed;
  final Widget child;
  final Widget? loadingChild;
  final ButtonStyle? style;
  final bool enabled;
  final double? width;
  final double? height;

  const LoadingOutlinedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.loadingChild,
    this.style,
    this.enabled = true,
    this.width,
    this.height,
  });

  @override
  State<LoadingOutlinedButton> createState() => _LoadingOutlinedButtonState();
}

class _LoadingOutlinedButtonState extends State<LoadingOutlinedButton>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handlePress() async {
    if (_isLoading || !widget.enabled) return;

    await _animController.forward();
    _animController.reverse();

    setState(() => _isLoading = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: OutlinedButton(
          onPressed: (_isLoading || !widget.enabled) ? null : _handlePress,
          style: widget.style,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _isLoading
                ? (widget.loadingChild ??
                    const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ))
                : widget.child,
          ),
        ),
      ),
    );
  }
}

/// A loading-aware GestureDetector wrapper for custom-styled buttons (like the Bill button).
/// Wraps a child widget and prevents double-taps while showing a loading overlay.
class LoadingTapWrapper extends StatefulWidget {
  final Future<void> Function() onTap;
  final Widget child;
  final Widget? loadingChild;
  final bool enabled;

  const LoadingTapWrapper({
    super.key,
    required this.onTap,
    required this.child,
    this.loadingChild,
    this.enabled = true,
  });

  @override
  State<LoadingTapWrapper> createState() => _LoadingTapWrapperState();
}

class _LoadingTapWrapperState extends State<LoadingTapWrapper>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_isLoading || !widget.enabled) return;

    await _animController.forward();
    _animController.reverse();

    setState(() => _isLoading = true);
    try {
      await widget.onTap();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: (_isLoading || !widget.enabled) ? null : _handleTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedOpacity(
          opacity: _isLoading ? 0.7 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: _isLoading
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    widget.child,
                    const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ],
                )
              : widget.child,
        ),
      ),
    );
  }
}

