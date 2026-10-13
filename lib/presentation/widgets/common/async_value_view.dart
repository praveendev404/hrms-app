import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/exceptions.dart';
import 'error_widget.dart';
import 'skeleton.dart';

/// Renders an [AsyncValue] with consistent loading / error(+retry) states.
/// Keeps showing the previous data while a refresh is in flight.
class AsyncValueView<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;

  /// Compact mode is for use inside dashboard cards (no centered full-page layout).
  final bool compact;

  const AsyncValueView({
    super.key,
    required this.value,
    required this.builder,
    required this.onRetry,
    this.compact = false,
  });

  static String messageOf(Object error) {
    if (error is AppException) {
      if (error.statusCode == 403) return 'You do not have access to this.';
      return error.message;
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      data: builder,
      loading: () => compact ? const SkeletonLines() : const SkeletonList(),
      error: (e, _) => compact
          ? Row(
              children: [
                Icon(Icons.cloud_off_outlined, size: 18, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(messageOf(e), maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ),
                TextButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            )
          : ErrorDisplayWidget(message: messageOf(e), onRetry: onRetry),
    );
  }
}
