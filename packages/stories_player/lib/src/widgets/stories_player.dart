import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../controller/pause_reason.dart';
import '../controller/stories_config.dart';
import '../controller/stories_controller.dart';
import '../controller/stories_value.dart';
import '../events/story_event.dart';
import '../media/story_media_image.dart';
import '../media/story_media_store.dart';
import '../model/story_group.dart';
import '../model/story_item.dart';
import '../model/story_media.dart';
import '../model/story_position.dart';
import '../playback/builtin_delegates.dart';
import '../playback/story_audio.dart';
import '../playback/story_clock.dart';
import '../playback/story_item_session.dart';
import '../playback/story_navigator.dart';
import '../playback/story_session_pool.dart';
import '../prefetch/story_prefetch_policy.dart';
import '../prefetch/story_prefetcher.dart';
import '../theme/stories_labels.dart';
import '../theme/stories_theme.dart';
import 'story_group_transition.dart';
import 'story_intents.dart';
import 'story_overlays.dart';

/// Called when the player moves to another item.
typedef StoryItemChangedCallback =
    void Function(StoryGroup group, StoryItem item, StoryChangeReason reason);

/// Called with a group and one of its items.
typedef StoryItemCallback = void Function(StoryGroup group, StoryItem item);

/// Called when the player asks to be closed.
typedef StoriesDismissCallback = void Function(StoriesDismissReason reason);

/// Called for every [StoryEvent].
typedef StoryEventCallback = void Function(StoryEvent event);

/// A full-screen stories player: groups of image, video and animation
/// items with a segmented progress bar, tap, hold and swipe gestures,
/// prefetching, and a byte-bounded media cache.
///
/// The simplest player needs only groups:
///
/// {@tool snippet}
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute<void>(
///     fullscreenDialog: true,
///     builder: (_) => StoriesPlayer(groups: groups),
///   ),
/// );
/// ```
/// {@end-tool}
///
/// Image and widget items work out of the box. Add delegates for other
/// item types, such as `VideoStoryDelegate` from
/// `package:stories_player_video`:
///
/// {@tool snippet}
/// ```dart
/// StoriesPlayer(
///   groups: groups,
///   initialPosition: StoryPosition.group(tappedGroupId),
///   isSeen: (group, item) => seen.contains(item.id),
///   delegates: const [VideoStoryDelegate(), LottieStoryDelegate()],
///   onItemSeen: (group, item) => seen.add(item.id),
///   onDismiss: (reason) => Navigator.of(context).pop(),
/// )
/// ```
/// {@end-tool}
///
/// ## Behaviour
///
/// * Tapping the trailing side moves forward; the leading side (30% by
///   default) moves back. In right-to-left locales the sides swap, the
///   progress bar fills from the right, and swipes mirror.
/// * Pressing pauses at once; holding hides the overlays.
/// * Dragging down closes; swiping sideways changes group.
/// * Progress follows the media: it freezes while a video buffers and
///   starts only once an image is decoded.
/// * Screen reader users get semantic actions and no auto-advance.
///
/// The player never pops routes or persists state. It reports through
/// callbacks; the app decides. When [onDismiss] is not set, closing pops
/// the current route with [Navigator.maybePop].
///
/// See also:
///
///  * [StoriesController], to drive the player from outside.
///  * [StoriesTheme], to style it.
///  * [StoryMediaStore], which caches its media.
class StoriesPlayer extends StatefulWidget {
  /// Creates a player for [groups].
  StoriesPlayer({
    super.key,
    required this.groups,
    this.controller,
    this.initialPosition = StoryPosition.firstUnseen,
    this.isSeen,
    this.delegates = const [],
    this.mediaStore,
    this.audio,
    this.prefetch = StoryPrefetchPolicy.balanced,
    this.networkSignal = const StoryNetworkSignal.measured(),
    this.playback = const StoriesPlaybackConfig(),
    this.gestures = const StoriesGestureConfig(),
    this.groupTransition = StoryGroupTransition.slide,
    this.labels = StoriesLabels.english,
    this.textDirection,
    this.onItemChanged,
    this.onItemSeen,
    this.onComplete,
    this.onDismiss,
    this.onSwipeUp,
    this.onEvent,
    this.headerBuilder = defaultHeaderBuilder,
    this.footerBuilder = defaultFooterBuilder,
    this.progressBuilder = defaultProgressBuilder,
    this.loadingBuilder = defaultLoadingBuilder,
    this.errorBuilder = defaultErrorBuilder,
    this.debugShowTapZones = false,
  }) : assert(groups.isNotEmpty, 'StoriesPlayer needs at least one group.'),
       assert(
         groups.map((group) => group.id).toSet().length == groups.length,
         'StoriesPlayer groups must have unique ids.',
       );

  /// The groups to play, in order.
  final List<StoryGroup> groups;

  /// Drives the player from outside. When null, the player creates its own.
  final StoriesController? controller;

  /// Where the player opens. Defaults to the first unseen item.
  final StoryPosition initialPosition;

  /// Whether an item was already watched; lets the player open each group
  /// at its first unseen item.
  final StorySeenTester? isSeen;

  /// Delegates for item types beyond images and widgets, such as video and
  /// Lottie. Asked in order, before the built-in ones.
  final List<StoryItemDelegate> delegates;

  /// Where media is cached. Defaults to [StoryMediaStore.instance].
  final StoryMediaStore? mediaStore;

  /// Plays music tracks. Without it, items with music play silently.
  final StoryAudioBackend? audio;

  /// How much to download ahead.
  final StoryPrefetchPolicy prefetch;

  /// How fast the network is.
  final StoryNetworkSignal networkSignal;

  /// Durations, advancing, sound and seen rules.
  final StoriesPlaybackConfig playback;

  /// Tap zones, hold, swipes and keyboard.
  final StoriesGestureConfig gestures;

  /// How pages move between groups.
  final StoryGroupTransition groupTransition;

  /// The words shown and announced.
  final StoriesLabels labels;

  /// Overrides the ambient text direction, which decides tap zones,
  /// progress direction and swipe direction.
  final TextDirection? textDirection;

  /// Called when the player moves to another item.
  final StoryItemChangedCallback? onItemChanged;

  /// Called once per item when it counts as seen, under
  /// [StoriesPlaybackConfig.seenRule]. Persist seen state here.
  final StoryItemCallback? onItemSeen;

  /// Called when the last item of the last group finishes, just before
  /// [onDismiss] with [StoriesDismissReason.completed].
  final VoidCallback? onComplete;

  /// Called when the player asks to be closed. When null, the player calls
  /// [Navigator.maybePop].
  final StoriesDismissCallback? onDismiss;

  /// Called when the user swipes up on an item. No default action.
  final StoryItemCallback? onSwipeUp;

  /// Called for every [StoryEvent], for analytics.
  final StoryEventCallback? onEvent;

  /// Builds the header under the progress bar.
  final StoryOverlayBuilder headerBuilder;

  /// Builds the footer at the bottom.
  ///
  /// The footer reaches the bottom edge of the screen, under the system
  /// navigation bar, so its background can too. Pad its content by
  /// `MediaQuery.paddingOf(context).bottom`, as [StoryCaption] does.
  final StoryOverlayBuilder footerBuilder;

  /// Builds the progress bar.
  final StoryOverlayBuilder progressBuilder;

  /// Builds what shows while media loads.
  final StoryOverlayBuilder loadingBuilder;

  /// Builds what a failed item shows.
  final StoryErrorBuilder errorBuilder;

  /// Paints the tap zones, to check them in right-to-left layouts.
  final bool debugShowTapZones;

  /// The default [headerBuilder]: a [StoryHeader].
  static Widget defaultHeaderBuilder(
    BuildContext context,
    StoryOverlayDetails details,
  ) => StoryHeader(details: details);

  /// The default [footerBuilder]: a [StoryCaption].
  static Widget defaultFooterBuilder(
    BuildContext context,
    StoryOverlayDetails details,
  ) => StoryCaption(details: details);

  /// The default [progressBuilder]: a [StoryProgressBar].
  static Widget defaultProgressBuilder(
    BuildContext context,
    StoryOverlayDetails details,
  ) => StoryProgressBar(
    count: details.group.items.length,
    index: details.itemIndex,
    progress: details.progress,
  );

  /// The default [loadingBuilder]: a small spinner.
  static Widget defaultLoadingBuilder(
    BuildContext context,
    StoryOverlayDetails details,
  ) => Center(
    child: SizedBox.square(
      dimension: 36,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: StoriesTheme.of(context).loadingColor,
      ),
    ),
  );

  /// The default [errorBuilder]: a [StoryErrorView].
  static Widget defaultErrorBuilder(
    BuildContext context,
    StoryErrorDetails details,
  ) => StoryErrorView(details: details);

  /// The controller of the nearest [StoriesPlayer] above [context].
  ///
  /// Throws if there is none. See [maybeOf].
  static StoriesController of(BuildContext context) {
    final controller = maybeOf(context);
    if (controller != null) return controller;
    throw FlutterError.fromParts([
      ErrorSummary('StoriesPlayer.of() was called outside a StoriesPlayer.'),
      ErrorDescription(
        'No StoriesPlayer ancestor was found above the widget that called '
        'StoriesPlayer.of().',
      ),
      ErrorHint(
        'Call it from inside a builder passed to StoriesPlayer, or use '
        'StoriesPlayer.maybeOf() when the player may be absent.',
      ),
      context.describeElement('The context used was'),
    ]);
  }

  /// The controller of the nearest [StoriesPlayer] above [context], or
  /// null.
  static StoriesController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_StoriesScope>()?.controller;

  @override
  State<StoriesPlayer> createState() => _StoriesPlayerState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IntProperty('groups', groups.length))
      ..add(DiagnosticsProperty('initialPosition', initialPosition))
      ..add(DiagnosticsProperty('prefetch', prefetch))
      ..add(DiagnosticsProperty('playback', playback))
      ..add(DiagnosticsProperty('gestures', gestures))
      ..add(EnumProperty('textDirection', textDirection, defaultValue: null));
  }
}

class _StoriesScope extends InheritedWidget {
  const _StoriesScope({required this.controller, required super.child});

  final StoriesController controller;

  @override
  bool updateShouldNotify(_StoriesScope oldWidget) =>
      controller != oldWidget.controller;
}

class _StoriesPlayerState extends State<StoriesPlayer>
    with TickerProviderStateMixin, WidgetsBindingObserver
    implements StoriesControllerHost {
  static const List<StoryItemDelegate> _builtInDelegates = [
    ImageStoryDelegate(),
    WidgetStoryDelegate(),
  ];
  static const ValueListenable<double> _zero = AlwaysStoppedAnimation(0);

  late StoriesController _controller;
  StoriesController? _ownedController;
  late StoryMediaStore _store;
  late StoryPrefetcher _prefetcher;
  late StoryNavigator _nav;
  late StorySessionPool _pool;
  final StoryClock _clock = StoryClock();
  late PageController _pages;
  late Ticker _ticker;
  late AnimationController _dragReset;
  // Created in initState after the controller attaches, so a rejected
  // controller leaves nothing undisposed.
  late final ValueNotifier<double> _drag;
  late final ValueNotifier<bool> _overlaysVisible;
  late final FocusNode _focusNode;

  StoryItemSession? _session;
  final Set<PauseReason> _pauseReasons = {};
  Duration? _restoreTo;
  bool _shown = false;
  bool _seen = false;
  bool _started = false;
  bool _dismissed = false;
  bool _released = false;
  bool _muted = true;
  bool _screenReader = false;
  bool _showLoading = false;
  bool _autoRetried = false;

  /// True while a failed item waits for its automatic retry; it shows as
  /// loading, never as an error.
  bool _retryPending = false;

  /// Stall watchdog: a playing video whose position stopped moving without
  /// the player reporting buffering still shows the loading indicator.
  Duration? _lastMediaPosition;
  Duration? _positionStuckSince;
  bool _stalled = false;

  /// A retry the user asked for: the error view shows progress until it
  /// succeeds, or until it fails again and [_minRetryFeedback] has passed.
  bool _userRetrying = false;
  Stopwatch? _retryFeedback;
  Timer? _retryFeedbackTimer;
  int _failures = 0;
  static const _minRetryFeedback = Duration(milliseconds: 800);
  int _itemsShown = 0;
  StoryChangeReason? _pendingReason;
  Stopwatch _sinceStart = clock.stopwatch();
  DateTime? _bufferingSince;
  Timer? _loadingTimer;
  Timer? _skipTimer;
  double _dragStartHeight = 1;
  double _dragFrom = 0;
  int _stressedFrames = 0;
  int _sampledFrames = 0;

  List<StoryGroup> get _groups => _nav.groups;

  int get _groupIndex => _nav.groupIndex;

  int get _itemIndex => _nav.itemIndex;

  StoryGroup get _group => _nav.group;

  StoryItem get _item => _nav.item;

  String _keyOf(int group, int item) => _nav.keyOf(group, item);

  int _resumeItemOf(int group) => _nav.resumeItemOf(group);

  TextDirection get _direction =>
      widget.textDirection ?? Directionality.of(context);

  bool get _animatesGroups =>
      widget.groupTransition.animates &&
      !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  // ---------------------------------------------------------- lifecycle

  @override
  void initState() {
    super.initState();
    _attachController();
    _drag = ValueNotifier<double>(0);
    _overlaysVisible = ValueNotifier<bool>(true);
    _focusNode = FocusNode(debugLabel: 'StoriesPlayer');
    _store = widget.mediaStore ?? StoryMediaStore.instance;
    unawaited(_store.purgeExpired());
    _prefetcher = StoryPrefetcher(
      store: _store,
      policy: widget.prefetch,
      signal: widget.networkSignal,
      delegateFor: _delegateFor,
    );
    _nav = StoryNavigator(
      groups: widget.groups,
      start: widget.initialPosition,
      isSeen: widget.isSeen,
      groupEnd: widget.playback.groupEnd,
    );
    _pool = StorySessionPool(onChanged: _onSessionChanged);
    _muted = widget.playback.initiallyMuted;
    _pages = PageController(initialPage: _groupIndex);
    _ticker = createTicker(_onTick);
    _dragReset =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 250),
          )
          ..addListener(() => _drag.value = _dragFrom * (1 - _dragReset.value))
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              removePauseReason(PauseReason.dismissDrag);
            }
          });
    WidgetsBinding.instance.addObserver(this);
    SchedulerBinding.instance.addTimingsCallback(_onFrameTimings);
  }

  void _attachController() {
    final given = widget.controller;
    if (given != null) {
      _controller = given;
    } else {
      _controller = _ownedController ??= StoriesController();
    }
    _controller.attach(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final covered = !TickerMode.valuesOf(context).enabled;
    if (covered) {
      _pauseReasons.add(PauseReason.routeCovered);
    } else {
      _pauseReasons.remove(PauseReason.routeCovered);
    }
    _screenReader = MediaQuery.maybeAccessibleNavigationOf(context) ?? false;
    if (!_started) {
      _started = true;
      _activate(_groupIndex, _itemIndex, StoryChangeReason.initial);
    } else {
      _sync();
    }
  }

  @override
  void didUpdateWidget(StoriesPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controller.detach(this);
      _attachController();
      _publish();
    }
    _prefetcher
      ..policy = widget.prefetch
      ..signal = widget.networkSignal;
    _nav
      ..isSeen = widget.isSeen
      ..groupEnd = widget.playback.groupEnd;
    if (!identical(oldWidget.groups, widget.groups)) {
      _reconcileGroups(widget.groups);
    }
  }

  void _reconcileGroups(List<StoryGroup> groups) {
    final previousGroup = _groupIndex;
    final position = _nav.reconcile(groups);
    if (position.group != previousGroup) {
      // Re-position the pages without scrolling them during this build: a
      // fresh controller starts on the right page; the old one is disposed
      // once the frame no longer uses it.
      final old = _pages;
      _pages = PageController(initialPage: position.group);
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    if (position.sameItem) {
      _updatePrefetch();
      _publish();
    } else {
      _activate(position.group, position.item, StoryChangeReason.controller);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_released) _restore();
        removePauseReason(PauseReason.appInactive);
      case AppLifecycleState.inactive:
        addPauseReason(PauseReason.appInactive);
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        addPauseReason(PauseReason.appInactive);
        _release();
    }
  }

  @override
  void dispose() {
    _emit(
      (g, i, gi, ii) => StoryPrefetchReport(
        groupId: g,
        itemId: i,
        groupIndex: gi,
        itemIndex: ii,
        requested: _prefetcher.requested,
        completed: _prefetcher.completed,
        cancelled: _prefetcher.cancelled,
        failed: _prefetcher.failed,
      ),
    );
    WidgetsBinding.instance.removeObserver(this);
    SchedulerBinding.instance.removeTimingsCallback(_onFrameTimings);
    _loadingTimer?.cancel();
    _skipTimer?.cancel();
    _retryFeedbackTimer?.cancel();
    _prefetcher.dispose();
    _pool.clear();
    _ticker.dispose();
    _dragReset.dispose();
    _pages.dispose();
    _drag.dispose();
    _overlaysVisible.dispose();
    _focusNode.dispose();
    _controller.detach(this);
    _ownedController?.dispose();
    // A store passed in belongs to the app, which disposes it.
    super.dispose();
  }

  // ------------------------------------------------------------ sessions

  StoryItemDelegate? _delegateFor(StoryItem item) {
    for (final delegate in widget.delegates) {
      if (delegate.canHandle(item)) return delegate;
    }
    for (final delegate in _builtInDelegates) {
      if (delegate.canHandle(item)) return delegate;
    }
    return null;
  }

  StoryItemSession _sessionFor(int group, int item) =>
      _pool.obtain(_keyOf(group, item), () => _createSession(group, item));

  StoryItemSession _createSession(int group, int item) {
    final storyItem = _groups[group].items[item];
    final delegate = _delegateFor(storyItem);
    if (delegate == null) {
      throw FlutterError.fromParts([
        ErrorSummary('No delegate can show ${storyItem.runtimeType}.'),
        ErrorDescription(
          'Item "${storyItem.id}" in group "${_groups[group].id}" is a '
          '${storyItem.runtimeType}, and none of the StoryItemDelegates '
          'passed to StoriesPlayer.delegates can handle it.',
        ),
        ErrorHint(
          'Add the delegate for this item type, for example '
          'VideoStoryDelegate() from package:stories_player_video or '
          'LottieStoryDelegate() from package:stories_player_lottie.',
        ),
      ]);
    }
    final view = View.maybeOf(context);
    final width = view == null
        ? null
        : (view.physicalSize.width).round().clamp(1, 1440);
    return delegate.createSession(
      storyItem,
      StorySessionContext(
        store: _store,
        audio: widget.audio,
        isMuted: _muted,
        preferLowQuality:
            _prefetcher.quality != StoryNetworkQuality.fast &&
            widget.prefetch.slow.preferLowQuality,
        imageDuration: widget.playback.imageDuration,
        decodeWidth: width,
      ),
    );
  }

  /// Decodes the next item's poster ahead, so it paints in the same frame
  /// the user taps. Only from a source that needs no download, so the
  /// poster is never fetched twice.
  void _precachePoster(StoryItem item) {
    final poster = item.poster;
    if (poster == null || !mounted) return;
    final path = _store.lookup(poster);
    final ready = !poster.isNetwork || path != null || !_store.supportsFiles;
    if (!ready) return;
    unawaited(
      precacheImage(
        storyImageProvider(poster, localPath: path),
        context,
        onError: (_, _) {},
      ),
    );
  }

  /// Keeps the current item, the next one (prepared ahead) and, with a
  /// budget of three, the previous one (for an instant tap back); disposes
  /// the rest so decoders are released as soon as they are not needed.
  void _trimSessions({bool prepareAhead = false}) {
    final budget = widget.playback.maxPreparedItems;
    final keep = <String>{_keyOf(_groupIndex, _itemIndex)};
    if (prepareAhead && budget > 1) {
      final next = _nav.upcoming();
      if (next != null) {
        keep.add(_keyOf(next.group, next.item));
        _sessionFor(next.group, next.item);
        _precachePoster(_groups[next.group].items[next.item]);
      }
    }
    final previous = _nav.previousInGroup();
    if (budget > 2 && previous != null) {
      keep.add(_keyOf(previous.group, previous.item));
    }
    _pool.keepOnly(keep);
  }

  void _activate(
    int group,
    int item,
    StoryChangeReason reason, {
    bool isRetry = false,
  }) {
    if (!isRetry) {
      _autoRetried = false;
      _failures = 0;
      _userRetrying = false;
      _retryFeedbackTimer?.cancel();
    }
    _retryPending = false;
    _skipTimer?.cancel();
    _session?.pause();
    _nav.moveTo(group, item);
    _dismissed = false;
    _clock.reset();
    _lastMediaPosition = null;
    _positionStuckSince = null;
    _stalled = false;
    _restoreTo = null;
    _shown = false;
    _seen = false;
    _bufferingSince = null;
    _sinceStart = clock.stopwatch()..start();
    _controller.setProgress(0);

    final session = _sessionFor(group, item)..setMuted(_muted);
    // A session kept from earlier (the previous item) starts over.
    if (!_pool.markShown(session)) session.rewind();
    _session = session;
    _trimSessions(prepareAhead: session.status == StorySessionStatus.ready);

    // An automatic retry is not a new visit: the app hears nothing of it.
    if (!isRetry) {
      _emit(
        (g, i, gi, ii) => StoryItemStarted(
          groupId: g,
          itemId: i,
          groupIndex: gi,
          itemIndex: ii,
          reason: reason,
        ),
      );
      widget.onItemChanged?.call(_group, _item, reason);
      if (widget.playback.seenRule == StorySeenRule.onStart) _markSeen();
    }

    _loadingTimer?.cancel();
    _showLoading = false;
    _loadingTimer = Timer(widget.playback.loadingIndicatorDelay, () {
      if (mounted) setState(() => _showLoading = true);
    });

    _onSessionChanged();
  }

  void _onSessionChanged() {
    final session = _session;
    if (session == null || !mounted) return;
    switch (session.status) {
      case StorySessionStatus.ready:
        _onReady(session);
      case StorySessionStatus.buffering:
        _bufferingSince ??= clock.now();
      case StorySessionStatus.completed:
        // By default the item ends with its media. With holdLastFrame, media
        // that ends before the item's set duration holds its last frame.
        final hold =
            widget.playback.mediaEnd == StoryMediaEndBehavior.holdLastFrame;
        final endsNow = !hold || _clock.onMediaCompleted(_item.duration);
        if (endsNow && !_clock.ended) _onItemEnd();
      case StorySessionStatus.error:
        _onFailed(session);
      case StorySessionStatus.idle:
      case StorySessionStatus.preparing:
        break;
    }
    _sync();
    setState(() {});
  }

  void _onReady(StoryItemSession session) {
    final bufferingSince = _bufferingSince;
    if (bufferingSince != null) {
      _bufferingSince = null;
      final stalled = clock.now().difference(bufferingSince);
      _emit(
        (g, i, gi, ii) => StoryStalled(
          groupId: g,
          itemId: i,
          groupIndex: gi,
          itemIndex: ii,
          stalledFor: stalled,
        ),
      );
    }
    if (_shown) return;
    _shown = true;
    _itemsShown++;
    _userRetrying = false;
    _retryFeedbackTimer?.cancel();
    final restoreTo = _restoreTo;
    if (restoreTo != null) {
      _restoreTo = null;
      session.seekTo(restoreTo);
    } else {
      _emit(
        (g, i, gi, ii) => StoryItemShown(
          groupId: g,
          itemId: i,
          groupIndex: gi,
          itemIndex: ii,
          timeToFirstFrame: _sinceStart.elapsed,
          cacheHit: session.cacheHit,
        ),
      );
      if (widget.playback.seenRule == StorySeenRule.onFirstFrame) _markSeen();
    }
    _trimSessions(prepareAhead: true);
    _updatePrefetch();
  }

  void _onFailed(StoryItemSession session) {
    if (_shown) return;
    if (!_autoRetried) {
      // Try once more before showing an error, after releasing every other
      // session: phones run only a few video decoders at once, and a
      // prepared neighbour can hold the one this item needs. It also rides
      // out a brief network drop.
      _autoRetried = true;
      _retryPending = true;
      _pool.keepOnly({_keyOf(_groupIndex, _itemIndex)});
      _skipTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted && identical(_session, session)) _retryCurrent();
      });
      return;
    }
    _shown = true;
    _failures++;
    _settleUserRetry();
    _emit(
      (g, i, gi, ii) => StoryItemFailed(
        groupId: g,
        itemId: i,
        groupIndex: gi,
        itemIndex: ii,
        error: session.error ?? 'Unknown error',
        stackTrace: session.stackTrace,
      ),
    );
    _updatePrefetch();
    final skipAfter = widget.playback.skipFailedItemsAfter;
    if (skipAfter != null) {
      _skipTimer = Timer(skipAfter, () {
        if (mounted && identical(_session, session)) {
          goNext(StoryChangeReason.timer);
        }
      });
    }
  }

  void _updatePrefetch() => _prefetcher.update(
    groups: _groups,
    groupIndex: _groupIndex,
    itemIndex: _itemIndex,
    resumeItemOf: _resumeItemOf,
  );

  void _release() {
    if (_released) return;
    _released = true;
    _restoreTo = _clock.elapsed;
    _pool.clear();
    _session = null;
    _ticker.stop();
  }

  void _restore() {
    if (!_released || !mounted) return;
    _released = false;
    final restoreTo = _restoreTo;
    final session = _sessionFor(_groupIndex, _itemIndex)..setMuted(_muted);
    _pool.markShown(session);
    _session = session;
    _shown = false;
    _restoreTo = restoreTo;
    _clock.reset(start: restoreTo ?? Duration.zero);
    _onSessionChanged();
  }

  // ------------------------------------------------------------- clock

  Duration _durationOf(StoryItemSession session) =>
      _item.duration ?? session.duration ?? widget.playback.imageDuration;

  void _onTick(Duration now) {
    final session = _session;
    if (session == null) return;
    final progress = _clock.tick(
      now,
      duration: _durationOf(session),
      mediaPosition: session.position,
      counting: session.status == StorySessionStatus.ready,
    );
    _controller.setProgress(progress);
    session.onTick(_clock.elapsed, progress);
    _watchForStall(now, session.position);
    if (progress >= 1 && !_clock.ended) _onItemEnd();
  }

  void _watchForStall(Duration now, Duration? position) {
    if (position == null || _clock.ended || _clock.mediaEnded) return;
    if (position != _lastMediaPosition) {
      _lastMediaPosition = position;
      _positionStuckSince = null;
      if (_stalled) {
        _stalled = false;
        setState(() {});
      }
      return;
    }
    final since = _positionStuckSince ??= now;
    if (!_stalled && now - since > const Duration(milliseconds: 1200)) {
      _stalled = true;
      setState(() {});
    }
  }

  void _onItemEnd() {
    _clock.ended = true;
    _emit(
      (g, i, gi, ii) => StoryItemCompleted(
        groupId: g,
        itemId: i,
        groupIndex: gi,
        itemIndex: ii,
      ),
    );
    if (widget.playback.seenRule == StorySeenRule.onComplete) _markSeen();
    final advance =
        widget.playback.autoAdvance &&
        (!_screenReader || widget.playback.autoAdvanceWithScreenReader);
    if (advance) {
      // Advance after this frame, so the full bar paints once.
      scheduleMicrotask(() {
        if (mounted && _clock.ended) goNext(StoryChangeReason.timer);
      });
    } else {
      _sync();
      setState(() {});
    }
  }

  void _markSeen() {
    if (_seen) return;
    _seen = true;
    _emit(
      (g, i, gi, ii) =>
          StoryItemSeen(groupId: g, itemId: i, groupIndex: gi, itemIndex: ii),
    );
    widget.onItemSeen?.call(_group, _item);
  }

  bool get _held => _pauseReasons.isNotEmpty || _dismissed;

  /// Starts or stops playback and the ticker to match the pause set, then
  /// publishes the state.
  void _sync() {
    final session = _session;
    if (storyIsPlayable(session?.status, _clock) && !_held) {
      session!.play();
      if (!_ticker.isActive) {
        _clock.resume();
        unawaited(_ticker.start());
      }
    } else {
      session?.pause();
      if (_ticker.isActive) _ticker.stop();
    }
    _publish();
  }

  void _publish() {
    final session = _session;
    _controller.setValue(
      StoriesValue(
        groupIndex: _groupIndex,
        itemIndex: _itemIndex,
        groupId: _group.id,
        itemId: _item.id,
        status: _retryPending
            ? StoryPlaybackStatus.loading
            : storyPlaybackStatus(session?.status, _clock, held: _held),
        pauseReasons: Set.unmodifiable(_pauseReasons),
        isMuted: _muted,
        itemDuration: session == null ? null : _durationOf(session),
        error: session?.status == StorySessionStatus.error && !_retryPending
            ? session?.error
            : null,
      ),
    );
  }

  void _emit(StoryEvent Function(String g, String i, int gi, int ii) create) {
    final event = create(_group.id, _item.id, _groupIndex, _itemIndex);
    _controller.emit(event);
    widget.onEvent?.call(event);
  }

  void _onFrameTimings(List<FrameTiming> timings) {
    // Back off prefetching while frames run over budget, so downloads never
    // compete with rendering on a struggling device.
    for (final timing in timings) {
      _sampledFrames++;
      if (timing.totalSpan > const Duration(milliseconds: 25)) {
        _stressedFrames++;
      }
    }
    if (_sampledFrames < 30) return;
    final stressed = _stressedFrames / _sampledFrames > 0.25;
    _sampledFrames = 0;
    _stressedFrames = 0;
    _prefetcher.setStressed(stressed);
  }

  // ------------------------------------------------- StoriesControllerHost

  @override
  void addPauseReason(PauseReason reason) {
    if (!_pauseReasons.add(reason)) return;
    if (mounted) {
      _sync();
      setState(() {});
    }
  }

  @override
  void removePauseReason(PauseReason reason) {
    if (!_pauseReasons.remove(reason)) return;
    if (mounted) {
      _sync();
      setState(() {});
    }
  }

  /// Carries out where a navigation command leads.
  void _go(StoryStep step, StoryChangeReason reason) {
    if (!mounted) return;
    switch (step) {
      case StoryStepItem(:final group, :final item):
        _activate(group, item, reason);
      case StoryStepGroup(:final group, :final animate):
        _goToGroup(group, reason, animate: animate);
      case StoryStepEnd(:final finishedAll):
        if (finishedAll) widget.onComplete?.call();
        requestDismiss(StoriesDismissReason.completed);
    }
  }

  @override
  void goNext(StoryChangeReason reason) => _go(_nav.next(), reason);

  @override
  void goPrevious(StoryChangeReason reason) => _go(_nav.previous(), reason);

  @override
  void goNextGroup(StoryChangeReason reason) => _go(_nav.nextGroup(), reason);

  @override
  void goPreviousGroup(StoryChangeReason reason) =>
      _go(_nav.previousGroup(), reason);

  @override
  void goTo(StoryPosition position, StoryChangeReason reason) =>
      _go(_nav.goTo(position), reason);

  void _goToGroup(int target, StoryChangeReason reason, {bool? animate}) {
    if (!_pages.hasClients) {
      _activate(target, _resumeItemOf(target), reason);
      return;
    }
    _pendingReason = reason;
    if (animate ?? _animatesGroups) {
      unawaited(
        _pages.animateToPage(
          target,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeInOutCubic,
        ),
      );
    } else {
      _pages.jumpToPage(target);
    }
  }

  void _onPageChanged(int index) {
    if (index == _groupIndex) return;
    final reason = _pendingReason ?? StoryChangeReason.swipe;
    _pendingReason = null;
    _activate(index, _resumeItemOf(index), reason);
  }

  @override
  void applyMuted(bool muted) {
    if (_muted == muted) return;
    _muted = muted;
    _pool.setMuted(muted);
    _publish();
    setState(() {});
  }

  @override
  void retry() {
    if (_userRetrying) return;
    _pool.remove(_keyOf(_groupIndex, _itemIndex));
    _session = null;
    // Show progress at once; the user already chose to retry, so skip the
    // silent automatic retry and report the outcome.
    _userRetrying = true;
    _autoRetried = true;
    _retryFeedback = clock.stopwatch()..start();
    _activate(
      _groupIndex,
      _itemIndex,
      StoryChangeReason.controller,
      isRetry: true,
    );
  }

  /// After a failed user retry, keeps the progress visible for at least
  /// [_minRetryFeedback], so a fast failure never looks like an ignored tap.
  void _settleUserRetry() {
    if (!_userRetrying) return;
    final elapsed = _retryFeedback?.elapsed ?? _minRetryFeedback;
    final remaining = _minRetryFeedback - elapsed;
    _retryFeedbackTimer?.cancel();
    if (remaining <= Duration.zero) {
      _userRetrying = false;
      return;
    }
    _retryFeedbackTimer = Timer(remaining, () {
      if (!mounted) return;
      setState(() => _userRetrying = false);
    });
  }

  /// Loads the current item again without counting it as a new visit.
  void _retryCurrent() {
    _pool.remove(_keyOf(_groupIndex, _itemIndex));
    _session = null;
    _activate(
      _groupIndex,
      _itemIndex,
      StoryChangeReason.controller,
      isRetry: true,
    );
  }

  @override
  void requestDismiss(StoriesDismissReason reason) {
    if (!mounted || _dismissed) return;
    _dismissed = true;
    _sync();
    _emit(
      (g, i, gi, ii) => StoriesDismissed(
        groupId: g,
        itemId: i,
        groupIndex: gi,
        itemIndex: ii,
        reason: reason,
        itemsShown: _itemsShown,
      ),
    );
    final onDismiss = widget.onDismiss;
    if (onDismiss != null) {
      onDismiss(reason);
    } else {
      unawaited(Navigator.maybePop(context));
    }
  }

  // ------------------------------------------------------------ gestures

  void _onTapUp(TapUpDetails details, double width) {
    final fraction = details.localPosition.dx / width;
    final rtl = _direction == TextDirection.rtl;
    final zone = widget.gestures.previousZoneFraction;
    final isPrevious = rtl ? fraction > 1 - zone : fraction < zone;
    if (isPrevious) {
      goPrevious(StoryChangeReason.tap);
    } else {
      goNext(StoryChangeReason.tap);
    }
  }

  void _onHoldStart() {
    if (widget.gestures.hideOverlaysWhileHolding) {
      _overlaysVisible.value = false;
    }
  }

  void _onHoldEnd() => _overlaysVisible.value = true;

  void _onDragStart(DragStartDetails details, double height) {
    _dragReset.stop();
    _dragStartHeight = height;
    addPauseReason(PauseReason.dismissDrag);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final next = _drag.value + details.delta.dy;
    final allowDown = widget.gestures.swipeDownToDismiss;
    final allowUp = widget.onSwipeUp != null;
    _drag.value = next > 0
        ? (allowDown ? next : 0)
        : (allowUp ? next.clamp(-120.0, 0.0) : 0);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dy;
    final offset = _drag.value;
    final threshold =
        _dragStartHeight * widget.gestures.dismissDistanceFraction;
    if (offset > 0 && (offset > threshold || velocity > 900)) {
      removePauseReason(PauseReason.dismissDrag);
      requestDismiss(StoriesDismissReason.swipeDown);
      return;
    }
    if (offset < 0 && (offset < -60 || velocity < -900)) {
      widget.onSwipeUp?.call(_group, _item);
    }
    _dragFrom = offset;
    unawaited(_dragReset.forward(from: 0));
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollStartNotification) {
      addPauseReason(PauseReason.groupTransition);
    } else if (notification is ScrollEndNotification) {
      removePauseReason(PauseReason.groupTransition);
    }
    return false;
  }

  void _togglePause() {
    if (_pauseReasons.contains(PauseReason.controller)) {
      removePauseReason(PauseReason.controller);
    } else {
      addPauseReason(PauseReason.controller);
    }
  }

  // ------------------------------------------------------------- build

  StoryOverlayDetails _detailsFor(
    int group,
    int item, {
    required bool current,
  }) => StoryOverlayDetails(
    group: _groups[group],
    item: _groups[group].items[item],
    groupIndex: group,
    itemIndex: item,
    progress: current ? _controller.progress : _zero,
    isCurrent: current,
    isMuted: _muted,
    labels: widget.labels,
    store: _store,
    controller: _controller,
    close: () => requestDismiss(StoriesDismissReason.closeButton),
    toggleMuted: () => applyMuted(!_muted),
  );

  @override
  Widget build(BuildContext context) {
    final theme = StoriesTheme.of(context);
    final direction = _direction;
    Widget player = NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      // Swipe between groups with a mouse too, on the web and desktop.
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(
          context,
        ).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
        child: PageView.builder(
          controller: _pages,
          itemCount: _groups.length,
          onPageChanged: _onPageChanged,
          physics: widget.gestures.swipeBetweenGroups && _animatesGroups
              ? const PageScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) => AnimatedBuilder(
            animation: _pages,
            builder: (context, child) {
              final positions = _pages.positions;
              final page =
                  positions.length == 1 && positions.first.haveDimensions
                  ? _pages.page ?? _groupIndex.toDouble()
                  : _groupIndex.toDouble();
              return widget.groupTransition.buildPage(
                context,
                child!,
                index - page,
                direction,
              );
            },
            child: _buildGroupPage(context, index, theme),
          ),
        ),
      ),
    );

    player = ValueListenableBuilder<double>(
      valueListenable: _drag,
      builder: (context, offset, child) {
        // Keep the same widgets at every offset, so the page view below is
        // never remounted mid-drag.
        final fraction = (offset / _dragStartHeight).clamp(-1.0, 1.0);
        final down = fraction > 0 ? fraction : 0.0;
        // The backdrop fades out as the story is dragged down, revealing
        // whatever is behind the player's route (open it with a route that
        // is not opaque to show the app behind it).
        return ColoredBox(
          color: theme.backgroundColor!.withValues(
            alpha: (1 - down * 1.6).clamp(0.0, 1.0),
          ),
          child: Transform.translate(
            offset: Offset(0, offset),
            child: Transform.scale(
              scale: 1 - down * 0.2,
              // The card rounds as it leaves; no clipping while at rest.
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  (down * 160).clamp(0.0, 24.0),
                ),
                clipBehavior: down > 0 ? Clip.antiAlias : Clip.none,
                child: child,
              ),
            ),
          ),
        );
      },
      child: player,
    );

    if (widget.gestures.keyboardShortcuts) {
      final rtl = direction == TextDirection.rtl;
      player = Shortcuts(
        shortcuts: {
          SingleActivator(
            rtl ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight,
          ): const NextStoryIntent(),
          SingleActivator(
            rtl ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft,
          ): const PreviousStoryIntent(),
          const SingleActivator(LogicalKeyboardKey.space):
              const TogglePauseStoryIntent(),
          const SingleActivator(LogicalKeyboardKey.escape):
              const DismissStoriesIntent(),
        },
        child: Actions(
          actions: {
            NextStoryIntent: CallbackAction<NextStoryIntent>(
              onInvoke: (_) => goNext(StoryChangeReason.keyboard),
            ),
            PreviousStoryIntent: CallbackAction<PreviousStoryIntent>(
              onInvoke: (_) => goPrevious(StoryChangeReason.keyboard),
            ),
            TogglePauseStoryIntent: CallbackAction<TogglePauseStoryIntent>(
              onInvoke: (_) => _togglePause(),
            ),
            DismissStoriesIntent: CallbackAction<DismissStoriesIntent>(
              onInvoke: (_) => requestDismiss(StoriesDismissReason.keyboard),
            ),
          },
          child: Focus(focusNode: _focusNode, autofocus: true, child: player),
        ),
      );
    }

    return _StoriesScope(
      controller: _controller,
      child: Directionality(
        textDirection: direction,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // On wide screens, show a phone-shaped 9:16 column.
            final wide =
                constraints.maxWidth > constraints.maxHeight * 0.75 &&
                constraints.maxHeight.isFinite;
            if (!wide) return player;
            return ColoredBox(
              color: theme.backgroundColor!,
              child: Center(
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: player,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// What a page shows before its media plays: the poster, or for pages
  /// revealed during a swipe, an image item's own (prefetched) image.
  StoryMedia? _previewOf(StoryItem item, {required bool current}) {
    if (item.poster != null) return item.poster;
    if (!current && item is ImageStoryItem) return item.image;
    return null;
  }

  Widget _buildGroupPage(
    BuildContext context,
    int index,
    StoriesThemeData theme,
  ) {
    final current = index == _groupIndex;
    final itemIndex = current ? _itemIndex : _resumeItemOf(index);
    final group = _groups[index];
    final item = group.items[itemIndex];
    final session = current ? _session : null;
    final details = _detailsFor(index, itemIndex, current: current);
    final status = session?.status;
    final showMedia =
        status == StorySessionStatus.ready ||
        status == StorySessionStatus.buffering ||
        status == StorySessionStatus.completed;
    final loading =
        current &&
        !_userRetrying &&
        ((_showLoading &&
                (status == null ||
                    _retryPending ||
                    status == StorySessionStatus.idle ||
                    status == StorySessionStatus.preparing)) ||
            status == StorySessionStatus.buffering ||
            _stalled);

    Widget page = Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: item.placeholderColor ?? theme.backgroundColor!),
        if (_previewOf(item, current: current) case final preview?)
          StoryMediaImage(
            preview,
            store: _store,
            priority: current
                ? StoryFetchPriority.visible
                : StoryFetchPriority.ahead,
          ),
        if (showMedia)
          RepaintBoundary(
            key: ValueKey(_keyOf(index, itemIndex)),
            // Media never takes input: platform views such as web video
            // would otherwise claim taps meant for the story.
            child: IgnorePointer(child: session!.build(context)),
          ),
        if (loading) widget.loadingBuilder(context, details),
        if (current &&
            (_userRetrying ||
                (status == StorySessionStatus.error && !_retryPending)))
          widget.errorBuilder(
            context,
            StoryErrorDetails(
              overlay: details,
              error: session?.error ?? 'Unknown error',
              retry: retry,
              skip: () => goNext(StoryChangeReason.tap),
              isRetrying: _userRetrying,
              failures: _failures < 1 ? 1 : _failures,
            ),
          ),
        ValueListenableBuilder<bool>(
          valueListenable: _overlaysVisible,
          builder: (context, visible, child) => IgnorePointer(
            ignoring: !visible,
            child: AnimatedOpacity(
              opacity: visible || !current ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: child,
            ),
          ),
          child: Column(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(gradient: theme.topScrim),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        widget.progressBuilder(context, details),
                        widget.headerBuilder(context, details),
                      ],
                    ),
                  ),
                ),
              ),
              const Spacer(),
              // Not in a safe area: the footer's gradient reaches the bottom
              // edge, under the system navigation bar. Footers pad their
              // content by MediaQuery.paddingOf(context).bottom.
              widget.footerBuilder(context, details),
            ],
          ),
        ),
        if (widget.debugShowTapZones)
          _TapZones(
            previousFraction: widget.gestures.previousZoneFraction,
            labels: widget.labels,
          ),
      ],
    );

    if (!current) return page;

    final label = widget.labels.describeItem(
      index: itemIndex + 1,
      count: group.items.length,
      label: group.semanticLabel ?? group.label ?? '',
    );
    final paused = _pauseReasons.contains(PauseReason.controller);
    page = Semantics(
      container: true,
      label: label,
      value: item.semanticLabel ?? item.caption,
      customSemanticsActions: {
        CustomSemanticsAction(label: widget.labels.next): () =>
            goNext(StoryChangeReason.semantics),
        CustomSemanticsAction(label: widget.labels.previous): () =>
            goPrevious(StoryChangeReason.semantics),
        CustomSemanticsAction(
          label: paused ? widget.labels.resume : widget.labels.pause,
        ): _togglePause,
      },
      onDismiss: () => requestDismiss(StoriesDismissReason.semantics),
      child: page,
    );

    return LayoutBuilder(
      builder: (context, constraints) => Listener(
        onPointerDown: (_) => addPauseReason(PauseReason.pointerDown),
        onPointerUp: (_) => removePauseReason(PauseReason.pointerDown),
        onPointerCancel: (_) => removePauseReason(PauseReason.pointerDown),
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: {
            TapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  () => TapGestureRecognizer(debugOwner: this),
                  (recognizer) =>
                      recognizer.onTapUp = (details) =>
                          _onTapUp(details, constraints.maxWidth),
                ),
            if (widget.gestures.holdToPause)
              LongPressGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    LongPressGestureRecognizer
                  >(
                    () => LongPressGestureRecognizer(
                      duration: widget.gestures.holdDelay,
                      debugOwner: this,
                    ),
                    (recognizer) => recognizer
                      ..onLongPressStart = ((_) => _onHoldStart())
                      ..onLongPressEnd = ((_) => _onHoldEnd())
                      ..onLongPressCancel = _onHoldEnd,
                  ),
            if (widget.gestures.swipeDownToDismiss || widget.onSwipeUp != null)
              _DismissDragGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    _DismissDragGestureRecognizer
                  >(
                    () => _DismissDragGestureRecognizer(debugOwner: this),
                    (recognizer) => recognizer
                      ..gestureSettings = MediaQuery.maybeGestureSettingsOf(
                        context,
                      )
                      ..onStart = ((details) =>
                          _onDragStart(details, constraints.maxHeight))
                      ..onUpdate = _onDragUpdate
                      ..onEnd = _onDragEnd,
                  ),
          },
          child: page,
        ),
      ),
    );
  }
}

/// A vertical drag that still wins when the finger moves at an angle.
///
/// Flutter's drag recognizers measure the whole distance the finger moved,
/// so the page view's horizontal drag also counts a mostly downward drag,
/// and the first to pass its slop wins. This one looks at the angle of the
/// whole drag: anything closer to vertical than [_maxAngle] is ours, and it
/// claims it a little before the horizontal slop is reached.
class _DismissDragGestureRecognizer extends VerticalDragGestureRecognizer {
  _DismissDragGestureRecognizer({super.debugOwner});

  /// tan(55°): drags up to 55 degrees off vertical close the player.
  static const double _maxAngle = 1.43;

  final Map<int, Offset> _starts = {};
  Offset _moved = Offset.zero;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _starts[event.pointer] = event.position;
    _moved = Offset.zero;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    final start = _starts[event.pointer];
    if (start != null && event is PointerMoveEvent) {
      _moved = event.position - start;
    }
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _starts.remove(event.pointer);
    }
    super.handleEvent(event);
  }

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) {
    final slop = computeHitSlop(pointerDeviceKind, gestureSettings) * 0.75;
    return _moved.distance > slop &&
        _moved.dx.abs() <= _moved.dy.abs() * _maxAngle;
  }

  @override
  void dispose() {
    _starts.clear();
    super.dispose();
  }

  @override
  String get debugDescription => 'dismiss drag';
}

class _TapZones extends StatelessWidget {
  const _TapZones({required this.previousFraction, required this.labels});

  final double previousFraction;
  final StoriesLabels labels;

  @override
  Widget build(BuildContext context) {
    final previousFlex = (previousFraction * 100).round();
    Widget zone(String text, Color color, int flex) => Expanded(
      flex: flex,
      child: ColoredBox(
        color: color,
        child: Center(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
    return IgnorePointer(
      child: Row(
        children: [
          zone(labels.previous, const Color(0x55E91E63), previousFlex),
          zone(labels.next, const Color(0x552196F3), 100 - previousFlex),
        ],
      ),
    );
  }
}
