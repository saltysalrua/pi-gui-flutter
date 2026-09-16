import 'package:flutter/material.dart';

import 'theme/app_tokens.dart';

/// A maintained desktop page with a stationary, possibly translucent shell.
/// AppDesktopScaffold animates the contents, never the entire route's opacity.
class AppDesktopPageRoute<T> extends PageRouteBuilder<T> {
  AppDesktopPageRoute({
    required WidgetBuilder builder,
    required bool reduceMotion,
    super.settings,
  }) : super(
         transitionDuration: reduceMotion ? Duration.zero : AppDurations.fast,
         reverseTransitionDuration: reduceMotion
             ? Duration.zero
             : AppDurations.quick,
         allowSnapshotting: false,
         pageBuilder: (context, _, _) => builder(context),
         transitionsBuilder: (_, animation, secondaryAnimation, child) =>
             Offstage(
               // At the last pop frame the previous page is visible again.
               // Do not draw this page's tint over it, even at animation == 0.
               offstage:
                   animation.isDismissed || !secondaryAnimation.isDismissed,
               child: child,
             ),
       );

  // A normal opaque route only hides its predecessor AFTER its entrance ends.
  // Hide it for the entire transition too, without disposing its state/RPC.
  // This also suppresses MaterialPageRoute's default outgoing fade/zoom.
  @override
  DelegatedTransitionBuilder get delegatedTransition => _coverPrevious;

  static Widget _coverPrevious(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) => Offstage(offstage: !secondaryAnimation.isDismissed, child: child);
}
