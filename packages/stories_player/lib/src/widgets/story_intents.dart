import 'package:flutter/widgets.dart';

/// Moves to the next story item. Bound to the forward arrow key, which is
/// the left arrow in right-to-left locales.
class NextStoryIntent extends Intent {
  /// Creates the intent.
  const NextStoryIntent();
}

/// Moves to the previous story item.
class PreviousStoryIntent extends Intent {
  /// Creates the intent.
  const PreviousStoryIntent();
}

/// Pauses or resumes. Bound to Space.
class TogglePauseStoryIntent extends Intent {
  /// Creates the intent.
  const TogglePauseStoryIntent();
}

/// Asks to close the player. Bound to Escape.
class DismissStoriesIntent extends Intent {
  /// Creates the intent.
  const DismissStoriesIntent();
}
