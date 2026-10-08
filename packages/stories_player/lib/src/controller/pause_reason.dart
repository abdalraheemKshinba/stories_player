import 'package:flutter/foundation.dart';

/// Why playback is paused.
///
/// The player keeps a set of reasons and plays only when the set is empty.
/// Every part of the system adds and removes only its own reason, so a
/// finger lifting off the screen can never resume a story that a bottom
/// sheet paused.
///
/// The built-in reasons cover gestures, lifecycle and loading. Apps can
/// define their own:
///
/// {@tool snippet}
/// ```dart
/// const cartSheet = PauseReason('cartSheet');
/// controller.pause(cartSheet);
/// // ... later
/// controller.play(cartSheet);
/// ```
/// {@end-tool}
@immutable
final class PauseReason {
  /// Creates a pause reason named [name]. Reasons with the same name are
  /// equal.
  const PauseReason(this.name);

  /// A finger is on the screen (tap in progress or hold).
  static const PauseReason pointerDown = PauseReason('pointerDown');

  /// The app is not in the foreground.
  static const PauseReason appInactive = PauseReason('appInactive');

  /// Another route covers the player, for example after a call to action.
  static const PauseReason routeCovered = PauseReason('routeCovered');

  /// The user is dragging the player down to dismiss it.
  static const PauseReason dismissDrag = PauseReason('dismissDrag');

  /// The user is swiping between groups.
  static const PauseReason groupTransition = PauseReason('groupTransition');

  /// Paused through [StoriesController.pause] without a reason.
  static const PauseReason controller = PauseReason('controller');

  /// The name of this reason, used in debugging output.
  final String name;

  @override
  bool operator ==(Object other) => other is PauseReason && other.name == name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'PauseReason($name)';
}
