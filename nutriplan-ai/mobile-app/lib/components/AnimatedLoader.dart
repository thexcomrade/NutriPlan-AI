import 'package:flutter/material.dart';
import 'AppTheme.dart';

class AnimatedLoader extends StatefulWidget {
  final double size;
  final Color? color;
  final String? loadingText;

  const AnimatedLoader({
    Key? key,
    this.size = 60.0,
    this.color,
    this.loadingText,
  }) : super(key: key);

  @override
  State<AnimatedLoader> createState() => _AnimatedLoaderState();
}

class _AnimatedLoaderState extends State<AnimatedLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? AppTheme.primaryColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return CustomPaint(
                painter: _LoaderPainter(progress: _animation.value, color: color),
              );
            },
          ),
        ),
        if (widget.loadingText != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.loadingText!,
            style: AppTheme.textTheme.subtitle1?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _LoaderPainter extends CustomPainter {
  final double progress;
  final Color color;

  _LoaderPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 6.0;
    final radius = (size.width / 2) - strokeWidth;
    final center = Offset(size.width / 2, size.height / 2);

    final backgroundPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final foregroundPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw background circle
    canvas.drawCircle(center, radius, backgroundPaint);

    // Draw animated arc
    final startAngle = -math.pi / 2; // start from top
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      foregroundPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _LoaderPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
