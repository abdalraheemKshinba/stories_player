// Golden images of what must mirror in right-to-left locales. Regenerate
// with `flutter test --update-goldens test/goldens_test.dart` after an
// intended visual change.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stories_player/stories_player.dart';
import 'package:stories_player/testing.dart';

void main() {
  for (final direction in TextDirection.values) {
    testWidgets('progress bar fills in reading order (${direction.name})', (
      tester,
    ) async {
      final progress = ValueNotifier<double>(0.4);
      addTearDown(progress.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: direction,
          child: Center(
            child: RepaintBoundary(
              key: const ValueKey('bar'),
              child: Container(
                width: 360,
                height: 24,
                color: const Color(0xFF202020),
                alignment: Alignment.topCenter,
                child: Theme(
                  data: ThemeData(),
                  child: StoryProgressBar(
                    count: 4,
                    index: 1,
                    progress: progress,
                    theme: const StoriesThemeData(
                      progressHeight: 6,
                      progressFillColor: Color(0xFFFF5722),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await expectLater(
        find.byKey(const ValueKey('bar')),
        matchesGoldenFile('goldens/progress_bar_${direction.name}.png'),
      );
    });

    testWidgets('tap zones mirror (${direction.name})', (tester) async {
      tester.view
        ..physicalSize = const Size(300, 520)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = StoriesController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: const ValueKey('player'),
            child: StoriesPlayer(
              groups: [
                StoryGroup(
                  id: 'g',
                  label: 'Stories',
                  items: const [
                    FakeStoryItem(id: 'a'),
                    FakeStoryItem(id: 'b'),
                    FakeStoryItem(id: 'c'),
                  ],
                ),
              ],
              controller: controller,
              delegates: [FakeStoryItemDelegate()],
              mediaStore: FakeStoryMediaStore(),
              textDirection: direction,
              debugShowTapZones: true,
              initialPosition: const StoryPosition(0, 1),
            ),
          ),
        ),
      );
      await tester.pump();
      controller.pause();
      await tester.pump(const Duration(milliseconds: 300));
      await expectLater(
        find.byKey(const ValueKey('player')),
        matchesGoldenFile('goldens/tap_zones_${direction.name}.png'),
      );
    });
  }
}
