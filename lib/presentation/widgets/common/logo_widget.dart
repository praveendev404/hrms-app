import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Logo widget for Info Quest company
/// Displays the gradient checkmark/wave logo shape
class LogoWidget extends StatelessWidget {
  final double? width;
  final double? height;
  final bool showText;

  const LogoWidget({
    super.key,
    this.width,
    this.height,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo Image or Custom Gradient Shape
        SizedBox(
          width: width ?? 120,
          height: height ?? 120,
          child: Image.asset(
            'assets/images/hrms_logo.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // Fallback: Custom gradient checkmark shape
              return CustomPaint(
                painter: VectorEdgeLogoPainter(),
                size: Size(width ?? 120, height ?? 120),
              );
            },
          ),
        ),
        if (showText) ...[
          const SizedBox(height: 12),
          Text(
            'Info Quest',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}

/// Custom painter for Info Quest gradient logo
/// Creates a checkmark/wave shape with gradient from dark blue to teal green
class VectorEdgeLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(size.width, size.height),
        [
          const Color(0xFF1E3A5F), // Dark blue
          const Color(0xFF2A4A6F), // Medium blue
          const Color(0xFF00A88A), // Teal
          const Color(0xFF00D4AA), // Bright teal green
        ],
        [0.0, 0.3, 0.7, 1.0],
      );

    final path = Path();

    // Create checkmark/wave shape
    // Top left
    path.moveTo(size.width * 0.1, size.height * 0.1);
    
    // Top curve (wide at top)
    path.quadraticBezierTo(
      size.width * 0.3,
      size.height * 0.05,
      size.width * 0.5,
      size.height * 0.15,
    );
    
    // Left concave curve (dips down)
    path.quadraticBezierTo(
      size.width * 0.2,
      size.height * 0.4,
      size.width * 0.15,
      size.height * 0.6,
    );
    
    // Bottom left curve (rises again)
    path.quadraticBezierTo(
      size.width * 0.1,
      size.height * 0.7,
      size.width * 0.2,
      size.height * 0.85,
    );
    
    // Bottom wave
    path.quadraticBezierTo(
      size.width * 0.4,
      size.height * 0.95,
      size.width * 0.6,
      size.height * 0.9,
    );
    
    // Right side - dramatic upward curve (checkmark peak)
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.85,
      size.width * 0.85,
      size.height * 0.7,
    );
    
    // Sharp upward peak
    path.quadraticBezierTo(
      size.width * 0.9,
      size.height * 0.5,
      size.width * 0.85,
      size.height * 0.3,
    );
    
    // Top right curve
    path.quadraticBezierTo(
      size.width * 0.8,
      size.height * 0.15,
      size.width * 0.65,
      size.height * 0.1,
    );
    
    // Close path
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

