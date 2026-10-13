import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// A single shimmering placeholder block.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 8});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(radius)),
    );
  }
}

/// Wraps skeleton children in the shared shimmer animation.
class SkeletonShimmer extends StatelessWidget {
  final Widget child;
  const SkeletonShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE9EDF5),
      highlightColor: const Color(0xFFF7F9FC),
      child: child,
    );
  }
}

/// Placeholder for a dashboard card body: a few text lines.
class SkeletonLines extends StatelessWidget {
  final int lines;
  const SkeletonLines({super.key, this.lines = 3});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < lines; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: SkeletonBox(width: i == lines - 1 ? 120 : double.infinity, height: 12),
            ),
        ],
      ),
    );
  }
}

/// Placeholder for a list of cards. A plain Column (not a ListView) so it can sit
/// inside other scroll views as well as fill a screen.
class SkeletonList extends StatelessWidget {
  final int count;
  const SkeletonList({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var i = 0; i < count; i++)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: SkeletonBox(width: double.infinity, height: 78, radius: 16),
              ),
          ],
        ),
      ),
    );
  }
}
