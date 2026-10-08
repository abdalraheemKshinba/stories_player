import 'package:flutter/material.dart';
import 'package:stories_player/stories_player.dart';

import 'demo_data.dart';
import 'main.dart';

/// A single feature, opened straight from the URL, for screenshots:
///
/// `?scene=player&group=market&rtl=1&theme=1&zones=1&transition=cube&freeze=2200`
/// `?scene=cube` · `?scene=error`
class Scene {
  const Scene({
    required this.name,
    required this.settings,
    this.group = 'market',
    this.item,
    this.freezeAfter = const Duration(milliseconds: 2200),
    this.seen = const {},
  });

  static Scene? fromUri(Uri uri) {
    final q = uri.queryParameters;
    final name = q['scene'];
    if (name == null) return null;
    bool flag(String key) => q[key] == '1';
    return Scene(
      name: name,
      group: q['group'] ?? 'market',
      item: q['item'],
      freezeAfter: Duration(
        milliseconds: int.tryParse(q['freeze'] ?? '') ?? 2200,
      ),
      seen: {...?q['seen']?.split(',')},
      settings: DemoSettings(
        transition: switch (q['transition']) {
          'cube' => StoryGroupTransition.cube,
          'fade' => StoryGroupTransition.fade,
          _ => StoryGroupTransition.slide,
        },
        arabic: flag('rtl'),
        customTheme: flag('theme'),
        tapZones: flag('zones'),
      ),
    );
  }

  final String name;
  final DemoSettings settings;
  final String group;
  final String? item;
  final Duration freezeAfter;
  final Set<String> seen;
}

class SceneView extends StatelessWidget {
  const SceneView({super.key, required this.scene});

  final Scene scene;

  @override
  Widget build(BuildContext context) {
    final copy = scene.settings.copy;
    return switch (scene.name) {
      // The home page sits behind the player, as it would after a tap.
      'player' => Stack(
        fit: StackFit.expand,
        children: [
          const HomePage(),
          DemoPlayer(
            groups: demoGroups(copy),
            groupId: scene.group,
            itemId: scene.item,
            settings: scene.settings,
            seen: {...scene.seen},
            freezeAfter: scene.freezeAfter,
          ),
        ],
      ),
      'error' => DemoPlayer(
        groups: [errorGroup(copy)],
        groupId: 'offline',
        settings: scene.settings,
        seen: <String>{},
      ),
      'cube' => _CubePreview(groups: demoGroups(copy)),
      _ => const HomePage(),
    };
  }
}

/// Two groups caught halfway through the cube transition, drawn with the
/// package's own [StoryGroupTransition.cube].
class _CubePreview extends StatelessWidget {
  const _CubePreview({required this.groups});

  final List<StoryGroup> groups;

  @override
  Widget build(BuildContext context) {
    const delta = 0.42;
    Widget page(StoryGroup group, int item, double progress) {
      final image = (group.items[item] as ImageStoryItem).image;
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(image.assetName!, fit: BoxFit.cover),
          Align(
            alignment: Alignment.topCenter,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: StoriesThemeData.fallback.topScrim,
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StoryProgressBar(
                        count: group.items.length,
                        index: item,
                        progress: ValueNotifier(progress),
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          12,
                          10,
                          12,
                          0,
                        ),
                        child: Row(
                          children: [
                            ClipOval(
                              child: Image.asset(
                                group.avatar!.assetName!,
                                width: 34,
                                height: 34,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              group.label!,
                              style: StoriesThemeData.fallback.titleStyle,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    final width = MediaQuery.sizeOf(context).width;
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(-delta * width, 0),
              child: StoryGroupTransition.cube.buildPage(
                context,
                page(groups[0], 1, 0.7),
                -delta,
                TextDirection.ltr,
              ),
            ),
          ),
          Positioned.fill(
            child: Transform.translate(
              offset: Offset((1 - delta) * width, 0),
              child: StoryGroupTransition.cube.buildPage(
                context,
                page(groups[1], 0, 0),
                1 - delta,
                TextDirection.ltr,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
