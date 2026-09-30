import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_radius.dart';

/// One step of an [AppStepProgress] timeline.
class AppProgressStep {
  const AppProgressStep({required this.title, this.subtitle});

  final String title;

  /// Optional supporting line, e.g. when the step happened.
  final String? subtitle;
}

/// Vertical progress timeline.
///
/// A vertical timeline stays readable on a narrow phone: the circles keep a
/// fixed size, the number is always centred inside them, and the label sits
/// beside the rail where it has room to wrap instead of being squeezed. State
/// is carried by an icon and a word as well as by colour, so it does not depend
/// on seeing colour.
class AppStepProgress extends StatelessWidget {
  const AppStepProgress({
    required this.steps,
    required this.currentIndex,
    this.circleSize = 32,
    super.key,
  });

  final List<AppProgressStep> steps;

  /// Index of the step the request has reached. Steps before it are done, the
  /// step itself is current, and everything after it is upcoming.
  final int currentIndex;

  /// Fixed so every circle in the timeline is the same size.
  final double circleSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < steps.length; index++)
          _StepRow(
            step: steps[index],
            position: index,
            state: _stateFor(index),
            // The rail only continues when there is another step below it.
            hasConnector: index < steps.length - 1,
            connectorComplete: index + 1 <= currentIndex,
            circleSize: circleSize,
          ),
      ],
    );
  }

  ProgressState _stateFor(int index) {
    if (index < currentIndex) {
      return ProgressState.completed;
    }
    if (index == currentIndex) {
      return ProgressState.current;
    }
    return ProgressState.upcoming;
  }
}

enum ProgressState { completed, current, upcoming }

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.position,
    required this.state,
    required this.hasConnector,
    required this.connectorComplete,
    required this.circleSize,
  });

  final AppProgressStep step;
  final int position;
  final ProgressState state;
  final bool hasConnector;
  final bool connectorComplete;
  final double circleSize;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rail: circle on top, connector underneath, both the same width so
          // they line up exactly.
          SizedBox(
            width: circleSize,
            child: Column(
              children: [
                _StepCircle(position: position, state: state, size: circleSize),
                if (hasConnector)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: connectorComplete
                          ? AppPalette.brand
                          : AppPalette.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              // Nudges the first line up so it sits beside the circle rather
              // than below it.
              padding: EdgeInsets.only(top: (circleSize - 18) / 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: TextStyle(
                      color: state == ProgressState.upcoming
                          ? AppPalette.mutedStrong
                          : AppPalette.ink,
                      fontSize: 14.5,
                      fontWeight: state == ProgressState.upcoming
                          ? FontWeight.w700
                          : FontWeight.w800,
                    ),
                  ),
                  if (step.subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      step.subtitle!,
                      style: const TextStyle(
                        color: AppPalette.muted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (!hasConnector) const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _StepCircle extends StatelessWidget {
  const _StepCircle({
    required this.position,
    required this.state,
    required this.size,
  });

  final int position;
  final ProgressState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isDone = state == ProgressState.completed;
    final isCurrent = state == ProgressState.current;

    final background = isDone
        ? AppPalette.brand
        : isCurrent
        ? AppPalette.brandTint
        : AppPalette.surface;
    final foreground = isDone
        ? Colors.white
        : isCurrent
        ? AppPalette.brand
        : AppPalette.mutedStrong;

    final label = isDone ? 'Done' : 'Step ${position + 1}';

    return Semantics(
      label: '$label, ${_stateWord(state)}',
      child: Container(
        key: Key('progress-step-$position'),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: Border.all(
            color: isCurrent || isDone ? AppPalette.brand : AppPalette.border,
            width: isCurrent ? 2 : 1.4,
          ),
        ),
        // Centred rather than padded, so the number or the tick always sits in
        // the middle of the circle at any size.
        alignment: Alignment.center,
        child: isDone
            ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
            : Text(
                '${position + 1}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: foreground,
                  fontSize: size * 0.36,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }

  String _stateWord(ProgressState value) => switch (value) {
    ProgressState.completed => 'completed',
    ProgressState.current => 'current step',
    ProgressState.upcoming => 'not started',
  };
}

/// Shared corner radius for the card the timeline is usually placed in.
abstract final class AppProgressStyle {
  static final cardRadius = BorderRadius.circular(AppRadius.xl);
}
