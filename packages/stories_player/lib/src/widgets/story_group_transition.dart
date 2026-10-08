import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// How one group's page moves while the user swipes to another group.
///
/// [slide] is the default: it costs nothing on low-end devices. [cube] is
/// the Instagram look, a 3D rotation that is heavier to render over video.
/// Both mirror in right-to-left locales. When the platform asks for reduced
/// motion, every transition becomes a cut.
///
/// Extend this class for your own transition.
abstract base class StoryGroupTransition {
  /// Constructor for subclasses.
  const StoryGroupTransition();

  /// Pages slide side by side. The default.
  static const StoryGroupTransition slide = _SlideTransition();

  /// Pages turn like the faces of a cube.
  static const StoryGroupTransition cube = _CubeTransition();

  /// The outgoing page fades into the incoming one.
  static const StoryGroupTransition fade = _FadeTransition();

  /// Groups change with a cut and cannot be swiped.
  static const StoryGroupTransition none = _NoTransition();

  /// Whether moving between groups is animated. When false, the player
  /// jumps and horizontal swipes are disabled.
  bool get animates => true;

  /// Wraps a group's page.
  ///
  /// [delta] is the page's distance from the centre of the screen, in
  /// pages: 0 when fully shown, -1 or 1 when fully off screen, with
  /// positive values for the page that comes next.
  Widget buildPage(
    BuildContext context,
    Widget page,
    double delta,
    TextDirection textDirection,
  );
}

final class _SlideTransition extends StoryGroupTransition {
  const _SlideTransition();

  @override
  Widget buildPage(
    BuildContext context,
    Widget page,
    double delta,
    TextDirection textDirection,
  ) => page;
}

final class _CubeTransition extends StoryGroupTransition {
  const _CubeTransition();

  @override
  Widget buildPage(
    BuildContext context,
    Widget page,
    double delta,
    TextDirection textDirection,
  ) {
    if (delta == 0 || delta.abs() >= 1) return page;
    // The incoming page hinges on its edge nearest the outgoing page.
    final towardStart = delta > 0;
    final rtl = textDirection == TextDirection.rtl;
    final hingeOnLeft = towardStart != rtl;
    final angle = delta * math.pi / 2 * (rtl ? -1 : 1);
    return Transform(
      alignment: hingeOnLeft ? Alignment.centerLeft : Alignment.centerRight,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0012)
        ..rotateY(angle),
      // Faces turning away darken, which sells the depth.
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          page,
          IgnorePointer(
            child: ColoredBox(
              color: Color.fromRGBO(0, 0, 0, delta.abs() * 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

final class _FadeTransition extends StoryGroupTransition {
  const _FadeTransition();

  @override
  Widget buildPage(
    BuildContext context,
    Widget page,
    double delta,
    TextDirection textDirection,
  ) {
    if (delta == 0) return page;
    final width = MediaQuery.sizeOf(context).width;
    final shift = delta * width * (textDirection == TextDirection.rtl ? 1 : -1);
    return Transform.translate(
      offset: Offset(shift, 0),
      child: Opacity(opacity: (1 - delta.abs()).clamp(0.0, 1.0), child: page),
    );
  }
}

final class _NoTransition extends StoryGroupTransition {
  const _NoTransition();

  @override
  bool get animates => false;

  @override
  Widget buildPage(
    BuildContext context,
    Widget page,
    double delta,
    TextDirection textDirection,
  ) => page;
}
