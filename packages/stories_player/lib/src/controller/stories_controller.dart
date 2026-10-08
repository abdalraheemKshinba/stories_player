import 'dart:async';

import 'package:flutter/foundation.dart';

import '../events/story_event.dart';
import '../model/story_position.dart';
import 'pause_reason.dart';
import 'stories_value.dart';

/// The player side of a [StoriesController]. Implemented by the player's
/// state; not part of the public API.
@internal
abstract interface class StoriesControllerHost {
  /// Adds [reason] to the pause set.
  void addPauseReason(PauseReason reason);

  /// Removes [reason] from the pause set.
  void removePauseReason(PauseReason reason);

  /// Moves forward one item.
  void goNext(StoryChangeReason reason);

  /// Moves back one item.
  void goPrevious(StoryChangeReason reason);

  /// Moves to the next group's resume item.
  void goNextGroup(StoryChangeReason reason);

  /// Moves to the previous group's resume item.
  void goPreviousGroup(StoryChangeReason reason);

  /// Moves to [position].
  void goTo(StoryPosition position, StoryChangeReason reason);

  /// Turns sound on or off.
  void applyMuted(bool muted);

  /// Retries the current item after an error.
  void retry();

  /// Asks the app to close the player.
  void requestDismiss(StoriesDismissReason reason);
}

/// Controls a [StoriesPlayer] and exposes its state.
///
/// A controller is optional: without one the player creates its own.
/// Create one when you need to drive the player from outside, for example
/// to pause it while your own bottom sheet is open, or to read its state.
///
/// Whoever creates a controller disposes it. The player never disposes a
/// controller it was given.
///
/// {@tool snippet}
/// ```dart
/// class _MyScreenState extends State<MyScreen> {
///   final _controller = StoriesController();
///
///   @override
///   void dispose() {
///     _controller.dispose();
///     super.dispose();
///   }
///
///   @override
///   Widget build(BuildContext context) => StoriesPlayer(
///     groups: widget.groups,
///     controller: _controller,
///   );
/// }
/// ```
/// {@end-tool}
///
/// See also:
///
///  * [StoriesValue], the state snapshot in [value].
///  * [progress], the current item's progress, updated every frame.
class StoriesController extends ChangeNotifier
    implements ValueListenable<StoriesValue> {
  /// Creates a controller.
  StoriesController();

  StoriesValue _value = StoriesValue.detached;
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);
  final StreamController<StoryEvent> _events =
      StreamController<StoryEvent>.broadcast();
  StoriesControllerHost? _host;
  bool _isDisposed = false;

  /// The current state. Notifies listeners when it changes.
  @override
  StoriesValue get value => _value;

  /// The current item's progress, from 0 to 1, updated every frame while
  /// it plays.
  ///
  /// Kept apart from [value] so that widgets listening to state do not
  /// rebuild sixty times a second.
  ValueListenable<double> get progress => _progress;

  /// Every [StoryEvent] the player emits, as a broadcast stream.
  Stream<StoryEvent> get events => _events.stream;

  /// Whether the controller is attached to a player.
  bool get isAttached => _host != null;

  /// Resumes playback held by [reason].
  ///
  /// Playback actually resumes only when no other reason holds it, so this
  /// never overrides a pause it did not cause.
  void play([PauseReason reason = PauseReason.controller]) =>
      _withHost('play')?.removePauseReason(reason);

  /// Holds playback for [reason] until [play] is called with the same
  /// reason.
  void pause([PauseReason reason = PauseReason.controller]) =>
      _withHost('pause')?.addPauseReason(reason);

  /// Moves to the next item, the next group, or asks to dismiss after the
  /// last one.
  void next() => _withHost('next')?.goNext(StoryChangeReason.controller);

  /// Moves to the previous item, or the previous group's last item.
  void previous() =>
      _withHost('previous')?.goPrevious(StoryChangeReason.controller);

  /// Moves to the next group.
  void nextGroup() =>
      _withHost('nextGroup')?.goNextGroup(StoryChangeReason.controller);

  /// Moves to the previous group.
  void previousGroup() =>
      _withHost('previousGroup')?.goPreviousGroup(StoryChangeReason.controller);

  /// Moves to [position].
  void jumpTo(StoryPosition position) =>
      _withHost('jumpTo')?.goTo(position, StoryChangeReason.controller);

  /// Turns sound on or off for the rest of the session.
  void setMuted(bool muted) => _withHost('setMuted')?.applyMuted(muted);

  /// Reloads the current item after an error.
  void retry() => _withHost('retry')?.retry();

  /// Asks the app to close the player, as the close button does.
  void dismiss() =>
      _withHost('dismiss')?.requestDismiss(StoriesDismissReason.controller);

  StoriesControllerHost? _withHost(String method) {
    assert(
      _host != null,
      'StoriesController.$method() was called while the controller is not '
      'attached to a StoriesPlayer. Pass the controller to a StoriesPlayer '
      'and call it after the player is built.',
    );
    return _host;
  }

  /// Connects this controller to a player. Called by the player.
  @internal
  void attach(StoriesControllerHost host) {
    if (_host != null && !identical(_host, host)) {
      throw FlutterError.fromParts([
        ErrorSummary('A StoriesController was attached to two StoriesPlayers.'),
        ErrorDescription(
          'A controller drives exactly one player at a time. The second '
          'player would fight the first over pause state and position.',
        ),
        ErrorHint(
          'Create one StoriesController per StoriesPlayer, or let each '
          'player create its own by not passing a controller.',
        ),
      ]);
    }
    _host = host;
  }

  /// Disconnects this controller from [host]. Called by the player.
  @internal
  void detach(StoriesControllerHost host) {
    if (identical(_host, host)) {
      _host = null;
      _setValue(_value.copyWith(status: StoryPlaybackStatus.paused));
    }
  }

  /// Publishes a new state. Called by the player.
  @internal
  void setValue(StoriesValue value) => _setValue(value);

  /// Publishes the current item's progress. Called by the player.
  @internal
  void setProgress(double progress) {
    if (!_isDisposed) _progress.value = progress;
  }

  /// Publishes an event. Called by the player.
  @internal
  void emit(StoryEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  void _setValue(StoriesValue value) {
    if (_isDisposed || value == _value) return;
    _value = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _host = null;
    _progress.dispose();
    unawaited(_events.close());
    super.dispose();
  }
}
