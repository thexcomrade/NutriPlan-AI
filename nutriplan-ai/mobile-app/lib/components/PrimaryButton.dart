import 'package:flutter/material.dart';
import 'AppTheme.dart';

class PrimaryButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool enabled;
  final double borderRadius;
  final EdgeInsetsGeometry padding;

  const PrimaryButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.enabled = true,
    this.borderRadius = 12.0,
    this.padding = const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
  }) : super(key: key);

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnimation = _animationController.drive(
      Tween<double>(begin: 1.0, end: 0.95),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.enabled && !widget.isLoading) {
      _animationController.reverse();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.enabled && !widget.isLoading) {
      _animationController.forward();
    }
  }

  void _onTapCancel() {
    if (widget.enabled && !widget.isLoading) {
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = !widget.enabled || widget.isLoading;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: isDisabled ? null : widget.onPressed,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: widget.padding,
          decoration: BoxDecoration(
            color: isDisabled
                ? AppTheme.primaryColor.withOpacity(0.5)
                : AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: [
              if (!isDisabled)
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.5),
                  offset: const Offset(0, 5),
                  blurRadius: 12,
                ),
            ],
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    widget.text,
                    style: AppTheme.textTheme.button?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
