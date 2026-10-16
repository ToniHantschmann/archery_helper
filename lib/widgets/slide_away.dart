import 'package:flutter/widgets.dart';

import '../core/theme/app_dimens.dart';

/// Slides [child] out of view under a clip while [hidden] — the way the
/// operator's furniture (hint rail, status chips) gets out of the picture while
/// a clock runs.
///
/// The child keeps its place in the layout instead of collapsing, so nothing
/// around it changes size and nothing is laid out again while it moves; only a
/// transform animates. [offset] is where it goes, in fractions of its own size
/// — `Offset(0, 1)` down, `Offset(0, -1)` up.
class SlideAway extends StatelessWidget {
  final bool hidden;
  final Offset offset;
  final Widget child;

  const SlideAway({
    super.key,
    required this.hidden,
    required this.offset,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedSlide(
        offset: hidden ? offset : Offset.zero,
        duration: AppMotion.slow,
        curve: AppMotion.curve,
        child: IgnorePointer(ignoring: hidden, child: child),
      ),
    );
  }
}
