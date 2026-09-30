import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// One step of an [AppStepProgress] row.
class AppProgressStep {
  const AppProgressStep({required this.title, this.subtitle});

  final String title;

  /// Optional supporting line, e.g. when the step happened.
  final String? subtitle;
}

/// Horizontal progress row: circle, connector, circle, connector.
///
/// Steps are laid out with [Flexible] rather than [Expanded] so a long label
/// shrinks and ellipsizes instead of pushing its neighbours off the screen, and
/// the connectors take whatever room is left. Every circle is the same fixed
/// size with its number centred, and the connector is aligned to the centre line
/// of the circles, so nothing drifts on a narrow phone.
class AppStepProgress extends StatelessWidget {
  const AppStepProgress({
    required this.steps,
    required this.currentIndex,
    this.circleSize = 30,
    super.key,
  });

  final List<AppProgressStep> steps;

  /// Index of the step the request has reached. Steps before it are done, the
  /// step itself is current, and everything after it is upcoming.
  final int currentIndex;

  /// Fixed so every circle in the row is the same size.
  final double circleSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < steps.length; index++) ...[
          Flexible(
            child: _StepColumn(
              step: steps[index],
              position: index,
              state: _stateFor(index),
              circleSize: circleSize,
            ),
          ),
          if (index < steps.length - 1)
            Expanded(
              child: _Connector(
                // The rail is drawn once the following step is reached.
                complete: index + 1 <= currentIndex,
                // Centres the line on the circles rather than on the label.
                offset: (circleSize - 2) / 2,
              ),
            ),
        ],
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

class _StepColumn extends StatelessWidget {
  const _StepColumn({
    required this.step,
    required this.position,
    required this.state,
    required this.circleSize,
  });

  final AppProgressStep step;
  final int position;
  final ProgressState state;
  final double circleSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepCircle(position: position, state: state, size: circleSize),
        const SizedBox(height: 7),
        // Bounded to two lines and ellipsized so neighbouring labels can never
        // overlap each other.
        Text(
          step.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: state == ProgressState.upcoming
                ? AppPalette.muted
                : AppPalette.ink,
            fontSize: 10.5,
            height: 1.25,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (step.subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            step.subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppPalette.faint,
              fontSize: 9.5,
              height: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.complete, required this.offset});

  final bool complete;

  /// Distance from the top of the row to the middle of the circle, so the line
  /// sits on the same axis as the circles.
  final double offset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: offset, right: 4, left: 4),
      child: Container(
        height: 2,
        decoration: BoxDecoration(
          color: complete ? AppPalette.brand : AppPalette.border,
          borderRadius: BorderRadius.circular(1),
        ),
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

    // State is spelled out for a screen reader as well as shown, so it never
    // depends on seeing the colour.
    final stateWord = switch (state) {
      ProgressState.completed => 'completed',
      ProgressState.current => 'current step',
      ProgressState.upcoming => 'not started',
    };

    return Semantics(
      label: '${isDone ? 'Done' : 'Step ${position + 1}'}, $stateWord',
      child: Container(
        key: Key('progress-step-$position'),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDone || isCurrent ? AppPalette.brand : AppPalette.border,
            width: isCurrent ? 2 : 1.4,
          ),
        ),
        // alignment centres the number or the tick in the circle exactly,
        // whatever the circle size is.
        alignment: Alignment.center,
        child: isDone
            ? Icon(Icons.check_rounded, size: size * 0.55, color: Colors.white)
            : Text(
                '${position + 1}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: foreground,
                  fontSize: size * 0.38,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}
