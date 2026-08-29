import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_theme.dart';
import '../../services/providers.dart';

/// Frosted-glass surface: backdrop blur + translucent gradient fill +
/// light-catching hairline border.
///
/// Keep at most one or two *blurred* instances visible per screen; blur is
/// the most expensive part of the effect. For items inside scrolling lists
/// pass [blurred] = false, which keeps the glass look (tint + border) while
/// skipping the [BackdropFilter].
///
/// When the user enables "reduce transparency" in settings, every instance
/// renders as a solid, high-contrast panel instead.
class GlassContainer extends ConsumerWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.blurred = true,
    this.blur = 16,
    this.fillOpacity = 0.10,
    this.tint = Colors.white,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.padding,
    this.shadowed = true,
  });

  final Widget child;

  /// Whether to blur what is behind the surface. Disable for list tiles.
  final bool blurred;

  /// Blur sigma used when [blurred] is true. Values above ~18 add cost
  /// without adding polish.
  final double blur;

  /// Base opacity of the tint fill; scaled up towards the top-left corner
  /// to fake a light source hitting the pane.
  final double fillOpacity;

  /// Color of the tint fill and of the border rim.
  final Color tint;

  final BorderRadius borderRadius;

  final EdgeInsetsGeometry? padding;

  /// Soft drop shadow. Turn off for edge-to-edge chrome (app bars).
  final bool shadowed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Selected field, so glass surfaces only rebuild when the toggle flips.
    final reduceTransparency = ref.watch(
      settingsControllerProvider.select((s) => s.reduceTransparency),
    );

    final BoxDecoration fillDecoration;
    if (reduceTransparency) {
      // Solid panel: tint folded into an opaque surface for contrast.
      fillDecoration = BoxDecoration(
        color: Color.alphaBlend(
          tint.withValues(alpha: 0.20),
          AppTheme.surfaceLifted,
        ),
        borderRadius: borderRadius,
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      );
    } else {
      fillDecoration = BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tint.withValues(alpha: fillOpacity * 1.5),
            tint.withValues(alpha: fillOpacity * 0.55),
          ],
        ),
      );
    }

    final fill = DecoratedBox(
      decoration: fillDecoration,
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadowed
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: CustomPaint(
        foregroundPainter:
            reduceTransparency ? null : GlassBorderPainter(radius: borderRadius),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: blurred && !reduceTransparency
              ? BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                  child: fill,
                )
              : fill,
        ),
      ),
    );
  }
}

/// Hairline gradient stroke that gives glass edges a rim highlight.
class GlassBorderPainter extends CustomPainter {
  const GlassBorderPainter({required this.radius});

  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.45),
          Colors.white.withValues(alpha: 0.06),
        ],
      ).createShader(rect);
    canvas.drawRRect(radius.toRRect(rect.deflate(0.5)), paint);
  }

  @override
  bool shouldRepaint(GlassBorderPainter oldDelegate) =>
      oldDelegate.radius != radius;
}
