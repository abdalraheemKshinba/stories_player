import 'dart:async';

import 'package:flutter/material.dart';
import 'package:stories_player/stories_player.dart';
import 'package:stories_player_audio/stories_player_audio.dart';
import 'package:stories_player_lottie/stories_player_lottie.dart';
import 'package:stories_player_video/stories_player_video.dart';

import 'demo_data.dart';
import 'scenes.dart';
import 'stories_tray.dart';

void main() => runApp(const StoriesDemoApp());

/// The example app. Opens a feature scene when the URL asks for one, which
/// is how the README screenshots are made.
class StoriesDemoApp extends StatelessWidget {
  const StoriesDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scene = Scene.fromUri(Uri.base);
    return MaterialApp(
      title: 'stories_player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFFFF6B2C),
        useMaterial3: true,
      ),
      home: scene == null ? const HomePage() : SceneView(scene: scene),
    );
  }
}

/// How the demo player is configured.
class DemoSettings {
  const DemoSettings({
    this.arabic = false,
    this.transition = StoryGroupTransition.slide,
    this.customTheme = false,
    this.tapZones = false,
  });

  final bool arabic;
  final StoryGroupTransition transition;
  final bool customTheme;
  final bool tapZones;

  DemoSettings copyWith({
    bool? arabic,
    StoryGroupTransition? transition,
    bool? customTheme,
    bool? tapZones,
  }) => DemoSettings(
    arabic: arabic ?? this.arabic,
    transition: transition ?? this.transition,
    customTheme: customTheme ?? this.customTheme,
    tapZones: tapZones ?? this.tapZones,
  );

  DemoCopy get copy => arabic ? DemoCopy.arabic : DemoCopy.english;
}

/// The custom theme of the "Custom theme" setting.
const customStoriesTheme = StoriesThemeData(
  progressFillColor: Color(0xFFFFC23C),
  progressTrackColor: Color(0x40FFFFFF),
  progressHeight: 4,
  progressGap: 6,
  progressRadius: 4,
  avatarSize: 40,
  titleStyle: TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.2,
  ),
  captionStyle: TextStyle(
    color: Colors.white,
    fontSize: 20,
    height: 1.3,
    fontWeight: FontWeight.w700,
  ),
);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DemoSettings _settings = const DemoSettings();
  final Set<String> _seen = {};
  final List<String> _log = [];

  List<StoryGroup> get _groups => demoGroups(_settings.copy);

  Future<void> _open(List<StoryGroup> groups, String groupId) =>
      Navigator.of(context)
          .push(
            storiesRoute(
              DemoPlayer(
                groups: groups,
                groupId: groupId,
                settings: _settings,
                seen: _seen,
                onEvent: _onEvent,
              ),
            ),
          )
          .then((_) {
            if (mounted) setState(() {});
          });

  void _onEvent(StoryEvent event) {
    final line = switch (event) {
      StoryItemShown(:final timeToFirstFrame, :final cacheHit) =>
        'shown ${event.itemId} · first frame '
            '${timeToFirstFrame.inMilliseconds} ms${cacheHit ? ' · cached' : ''}',
      StoryItemFailed(:final error) => 'failed ${event.itemId} · $error',
      StoryStalled(:final stalledFor) =>
        'stalled ${event.itemId} · ${stalledFor.inMilliseconds} ms',
      StoriesDismissed(:final reason, :final itemsShown) =>
        'dismissed · ${reason.name} after $itemsShown items',
      StoryPrefetchReport(
        :final requested,
        :final completed,
        :final cancelled,
      ) =>
        'prefetch · $requested requested, $completed done, '
            '$cancelled cancelled',
      _ => null,
    };
    if (line == null) return;
    _log.insert(0, line);
    if (_log.length > 8) _log.removeLast();
  }

  void _update(DemoSettings settings) => setState(() => _settings = settings);

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    final theme = Theme.of(context);
    return Directionality(
      textDirection: _settings.arabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF7F5),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 4),
                child: Text(
                  'stories_player',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 12),
                child: Text(
                  'Tap a story. Hold to pause, swipe down to close.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.black54,
                  ),
                ),
              ),
              StoriesTray(
                groups: groups,
                isSeen: (group) =>
                    group.items.every((item) => _seen.contains(item.id)),
                onTap: (group) => _open(groups, group.id),
              ),
              const SizedBox(height: 12),
              _Section(
                title: 'Player settings',
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: SegmentedButton<StoryGroupTransition>(
                        segments: const [
                          ButtonSegment(
                            value: StoryGroupTransition.slide,
                            label: Text('Slide'),
                            icon: Icon(Icons.view_carousel_outlined),
                          ),
                          ButtonSegment(
                            value: StoryGroupTransition.cube,
                            label: Text('Cube'),
                            icon: Icon(Icons.view_in_ar_outlined),
                          ),
                          ButtonSegment(
                            value: StoryGroupTransition.fade,
                            label: Text('Fade'),
                            icon: Icon(Icons.gradient_outlined),
                          ),
                        ],
                        selected: {_settings.transition},
                        onSelectionChanged: (value) => _update(
                          _settings.copyWith(transition: value.first),
                        ),
                      ),
                    ),
                    SwitchListTile(
                      title: const Text('Arabic, right to left'),
                      subtitle: const Text(
                        'Tap zones, progress and swipes mirror',
                      ),
                      value: _settings.arabic,
                      onChanged: (value) =>
                          _update(_settings.copyWith(arabic: value)),
                    ),
                    SwitchListTile(
                      title: const Text('Custom theme and footer'),
                      subtitle: const Text('StoriesThemeData + footerBuilder'),
                      value: _settings.customTheme,
                      onChanged: (value) =>
                          _update(_settings.copyWith(customTheme: value)),
                    ),
                    SwitchListTile(
                      title: const Text('Show tap zones'),
                      subtitle: const Text('debugShowTapZones'),
                      value: _settings.tapZones,
                      onChanged: (value) =>
                          _update(_settings.copyWith(tapZones: value)),
                    ),
                  ],
                ),
              ),
              _Section(
                title: 'Try a feature',
                child: Column(
                  children: [
                    _FeatureTile(
                      icon: Icons.music_note_rounded,
                      title: 'Image with music',
                      subtitle: 'ImageStoryItem + StoryAudio',
                      onTap: () => _open(groups, 'market'),
                    ),
                    _FeatureTile(
                      icon: Icons.play_circle_outline_rounded,
                      title: 'Video',
                      subtitle: 'VideoStoryItem, progress follows the video',
                      onTap: () => _open(groups, 'coffee'),
                    ),
                    _FeatureTile(
                      icon: Icons.animation_rounded,
                      title: 'Lottie',
                      subtitle: 'LottieStoryItem on the story clock',
                      onTap: () => _open(groups, 'kitchen'),
                    ),
                    _FeatureTile(
                      icon: Icons.text_fields_rounded,
                      title: 'Any widget',
                      subtitle: 'WidgetStoryItem with a progress animation',
                      onTap: () => _open(groups, 'bakery'),
                    ),
                    _FeatureTile(
                      icon: Icons.wifi_off_rounded,
                      title: 'Error and retry',
                      subtitle: 'A story whose image cannot load',
                      onTap: () =>
                          _open([errorGroup(_settings.copy)], 'offline'),
                    ),
                  ],
                ),
              ),
              _Section(
                title: 'Live events',
                child: _log.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'Open a story: time to first frame, stalls and '
                          'prefetch results appear here.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final line in _log)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Text(
                                line,
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the player with a quick fade and scale, as the big apps do. The
/// route is not opaque, so dragging a story down reveals the page behind it.
Route<void> storiesRoute(Widget player) => PageRouteBuilder<void>(
  opaque: false,
  transitionDuration: const Duration(milliseconds: 220),
  reverseTransitionDuration: const Duration(milliseconds: 180),
  pageBuilder: (context, animation, secondaryAnimation) => player,
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(
        scale: Tween(begin: 0.94, end: 1.0).animate(curved),
        child: child,
      ),
    );
  },
);

/// The player as an app would wire it: delegates, music, seen state,
/// analytics, theme, and a call to action that pauses while its sheet is
/// open.
class DemoPlayer extends StatefulWidget {
  const DemoPlayer({
    super.key,
    required this.groups,
    required this.groupId,
    required this.settings,
    required this.seen,
    this.onEvent,
    this.itemId,
    this.freezeAfter,
  });

  final List<StoryGroup> groups;
  final String groupId;
  final String? itemId;
  final DemoSettings settings;
  final Set<String> seen;
  final StoryEventCallback? onEvent;

  /// Pauses after this long, for screenshots.
  final Duration? freezeAfter;

  @override
  State<DemoPlayer> createState() => _DemoPlayerState();
}

class _DemoPlayerState extends State<DemoPlayer> {
  static const _sheet = PauseReason('orderSheet');
  final _controller = StoriesController();
  final _audio = AudioplayersStoryAudio();
  Timer? _freeze;

  @override
  void initState() {
    super.initState();
    final freezeAfter = widget.freezeAfter;
    if (freezeAfter != null) {
      _freeze = Timer(
        freezeAfter,
        () => _controller.pause(const PauseReason('screenshot')),
      );
    }
  }

  @override
  void dispose() {
    _freeze?.cancel();
    _controller.dispose();
    unawaited(_audio.dispose());
    super.dispose();
  }

  Future<void> _order(StoryOverlayDetails details) async {
    _controller.pause(_sheet);
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              details.group.label ?? '',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('The story is paused while this sheet is open.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to stories'),
            ),
          ],
        ),
      ),
    );
    _controller.play(_sheet);
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    Widget player = StoriesPlayer(
      groups: widget.groups,
      controller: _controller,
      initialPosition: widget.itemId == null
          ? StoryPosition.group(widget.groupId)
          : StoryPosition.item(widget.groupId, widget.itemId!),
      isSeen: (group, item) => widget.seen.contains(item.id),
      delegates: const [VideoStoryDelegate(), LottieStoryDelegate()],
      audio: _audio,
      groupTransition: settings.transition,
      labels: settings.arabic ? StoriesLabels.arabic : StoriesLabels.english,
      textDirection: settings.arabic ? TextDirection.rtl : TextDirection.ltr,
      debugShowTapZones: settings.tapZones,
      onItemSeen: (group, item) => widget.seen.add(item.id),
      onEvent: widget.onEvent,
      footerBuilder: settings.customTheme
          ? (context, details) => _OrderFooter(
              details: details,
              arabic: settings.arabic,
              onOrder: () => _order(details),
            )
          : StoriesPlayer.defaultFooterBuilder,
    );
    if (settings.customTheme) {
      player = StoriesTheme(data: customStoriesTheme, child: player);
    }
    return Scaffold(backgroundColor: Colors.transparent, body: player);
  }
}

class _OrderFooter extends StatelessWidget {
  const _OrderFooter({
    required this.details,
    required this.arabic,
    required this.onOrder,
  });

  final StoryOverlayDetails details;
  final bool arabic;
  final VoidCallback onOrder;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      StoryCaption(details: details),
      ColoredBox(
        color: const Color(0x99000000),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFC23C),
              foregroundColor: const Color(0xFF14213D),
              minimumSize: const Size.fromHeight(52),
              textStyle: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            onPressed: onOrder,
            icon: const Icon(Icons.shopping_bag_rounded),
            label: Text(arabic ? 'اطلب الآن' : 'Order now'),
          ),
        ),
      ),
    ],
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
    child: Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            child,
          ],
        ),
      ),
    ),
  );
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: CircleAvatar(
      backgroundColor: const Color(0xFFFFE9DE),
      foregroundColor: const Color(0xFFFF6B2C),
      child: Icon(icon),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}
