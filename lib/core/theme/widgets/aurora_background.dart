import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_theme.dart';
import '../../services/providers.dart';

/// Full-screen animated backdrop: slow-drifting gradient blobs over a night
/// gradient. Gives frosted-glass surfaces something to refract.
///
/// The drift runs in finite loops separated by idle gaps (no frames are
/// scheduled between loops), honours the system "remove animations"
/// accessibility setting, and can be paused externally - e.g. while the
/// model is streaming a reply and the GPU budget belongs to the text.
///
/// With "reduce transparency" enabled the blobs are hidden entirely,
/// leaving a calm flat gradient behind solid panels.
class AuroraBackground extends ConsumerStatefulWidget {
  const AuroraBackground({
    super.key,
    required this.child,
    this.paused = false,
  });

  final Widget child;

  /// Freezes the drift while true.
  final bool paused;

  @override
  ConsumerState<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends ConsumerState<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift;
  Timer? _restTimer;
  bool _started = false;
  bool _reducedTransparency = false;

  /// One drift loop. Wave frequencies below are integers, so the pose at
  /// t=1 equals the pose at t=0 and successive loops blend seamlessly.
  static const Duration _loopDuration = Duration(seconds: 22);

  /// Idle gap between loops during which no frames are scheduled.
  static const Duration _restDuration = Duration(seconds: 9);

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(vsync: this, duration: _loopDuration)
      ..addStatusListener(_onStatus);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _resume();
    }
  }

  @override
  void didUpdateWidget(AuroraBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.paused != oldWidget.paused) {
      if (widget.paused) {
        _restTimer?.cancel();
        _drift.stop();
      } else {
        _resume();
      }
    }
  }

  @override
  void dispose() {
    _restTimer?.cancel();
    _drift.dispose();
    super.dispose();
  }

  bool get _motionAllowed => !MediaQuery.disableAnimationsOf(context);

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _restTimer?.cancel();
    _restTimer = Timer(_restDuration, () {
      if (mounted && !widget.paused) _resume();
    });
  }

  void _resume() {
    if (!mounted || widget.paused || !_motionAllowed) return;
    // A controller parked at 1.0 must restart from 0, otherwise forward()
    // completes instantly and spams the status listener.
    _drift.forward(from: _drift.isCompleted ? 0.0 : null);
  }

  @override
  Widget build(BuildContext context) {
    final reduceTransparency = ref.watch(
      settingsControllerProvider.select((s) => s.reduceTransparency),
    );
    if (reduceTransparency != _reducedTransparency) {
      _reducedTransparency = reduceTransparency;
      // Controller start/stop is safe during build: tickers schedule frames
      // without marking any element dirty.
      if (reduceTransparency) {
        _restTimer?.cancel();
        _drift.stop();
      } else {
        _resume();
      }
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.night, Color(0xFF0C1226)],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!reduceTransparency)
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _drift,
                builder: (context, _) {
                  final t = _drift.value;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      _blob(
                        color: const Color(0xFF7C6CF0),
                        size: 420,
                        opacity: 0.32,
                        center: const Offset(0.18, 0.16) +
                            _wobble(t, freq: 1, phase: 0.0, amp: 0.05),
                      ),
                      _blob(
                        color: const Color(0xFF3ED6FF),
                        size: 360,
                        opacity: 0.22,
                        center: const Offset(0.88, 0.42) +
                            _wobble(t, freq: 2, phase: 1.3, amp: 0.04),
                      ),
                      _blob(
                        color: const Color(0xFFD36BFF),
                        size: 400,
                        opacity: 0.26,
                        center: const Offset(0.42, 0.92) +
                            _wobble(t, freq: 1, phase: 2.6, amp: 0.05),
                      ),
                    ],
                  );
                },
              ),
            ),
          widget.child,
        ],
      ),
    );
  }

  /// Smooth closed path around [center]; integer [freq] keeps the loop
  /// seamless across restarts.
  static Offset _wobble(
    double t, {
    required int freq,
    required double phase,
    required double amp,
  }) {
    final angle = 2 * math.pi * freq * t + phase;
    return Offset(math.sin(angle) * amp, math.cos(angle) * amp);
  }

  Widget _blob({
    required Color color,
    required double size,
    required double opacity,
    required Offset center,
  }) {
    return Align(
      alignment: Alignment(center.dx * 2 - 1, center.dy * 2 - 1),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
