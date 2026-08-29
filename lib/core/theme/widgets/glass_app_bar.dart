import 'package:flutter/material.dart';

import 'glass_container.dart';

/// Glass strip used as the [Scaffold.appBar] of every tab.
///
/// Screens using it should set `extendBodyBehindAppBar: true` and reserve
/// [contentTopInset] at the top of their body so content starts below the
/// bar while the aurora backdrop keeps showing through the blur.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({super.key, required this.title, this.actions = const []});

  final String title;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  /// Top inset body content must reserve below the bar when the body
  /// extends behind it.
  static double contentTopInset(BuildContext context) =>
      kToolbarHeight + MediaQuery.paddingOf(context).top;

  /// Bottom inset body content must reserve above the floating glass
  /// navigation pill (bar height + outer margins + breathing room).
  static double bottomNavReserve(BuildContext context) =>
      64 + 12 + MediaQuery.paddingOf(context).bottom + 12;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: BorderRadius.zero,
      shadowed: false,
      blur: 14,
      fillOpacity: 0.07,
      child: AppBar(
        title: Text(title),
        actions: actions,
      ),
    );
  }
}
