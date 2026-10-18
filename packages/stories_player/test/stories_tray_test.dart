import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stories_player/stories_player.dart';
import 'package:stories_player/testing.dart';

void main() {
  StoryMedia asset(String name) => StoryMedia.asset('assets/$name.webp');

  final shop = StoryGroup(
    id: 'shop',
    label: 'Burger Barn',
    avatar: asset('avatar'),
    items: [
      ImageStoryItem(id: 'a', image: asset('a')),
      const WidgetStoryItem(
        id: 'text',
        duration: Duration(seconds: 3),
        builder: _blank,
      ),
      ImageStoryItem(id: 'b', image: asset('b'), poster: asset('b_poster')),
    ],
  );

  group('StoryCard.coverOf', () {
    test('is the first item when nothing was seen', () {
      expect(StoryCard.coverOf(shop), asset('a'));
    });

    test('is the first unseen item, where the player opens', () {
      expect(
        StoryCard.coverOf(shop, isSeen: (_, item) => item.id != 'b'),
        asset('b_poster'),
      );
    });

    test('skips items without a snapshot', () {
      expect(
        StoryCard.coverOf(shop, isSeen: (_, item) => item.id == 'a'),
        asset('b_poster'),
      );
    });

    test('is the first item again once all were seen', () {
      expect(StoryCard.coverOf(shop, isSeen: (_, _) => true), asset('a'));
    });

    test('prefers the group cover', () {
      final group = StoryGroup(
        id: 'g',
        cover: asset('cover'),
        items: [ImageStoryItem(id: 'a', image: asset('a'))],
      );
      expect(StoryCard.coverOf(group), asset('cover'));
    });

    test('is null when no item has a snapshot', () {
      final group = StoryGroup(
        id: 'g',
        items: const [
          WidgetStoryItem(
            id: 'w',
            duration: Duration(seconds: 1),
            builder: _blank,
          ),
        ],
      );
      expect(StoryCard.coverOf(group), isNull);
    });
  });

  Future<void> pumpTray(
    WidgetTester tester, {
    required StoriesTrayLayout layout,
    TextDirection direction = TextDirection.ltr,
    StorySeenTester? isSeen,
    ValueChanged<StoryGroup>? onTap,
    Widget? leading,
    double textScale = 1,
  }) {
    final store = FakeStoryMediaStore(completeImmediately: true);
    return tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Directionality(
            textDirection: direction,
            child: Scaffold(
              body: Align(
                alignment: Alignment.topCenter,
                child: StoriesTray(
                  groups: [shop, _other],
                  layout: layout,
                  isSeen: isSeen,
                  leading: leading,
                  store: store,
                  onTap: onTap ?? (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('cards are 112 × 200 and the tray fits them', (tester) async {
    await pumpTray(tester, layout: StoriesTrayLayout.cards);
    expect(tester.getSize(find.byType(StoryCard).first), const Size(112, 200));
    expect(tester.getSize(find.byType(StoriesTray)).height, 200);
    expect(find.text('Burger Barn'), findsOneWidget);
  });

  testWidgets('circles keep the old layout', (tester) async {
    await pumpTray(tester, layout: StoriesTrayLayout.circles);
    expect(find.byType(StoryCircle), findsNWidgets(2));
    expect(find.byType(StoryCard), findsNothing);
  });

  for (final layout in StoriesTrayLayout.values) {
    testWidgets('${layout.name}: tapping opens the group', (tester) async {
      StoryGroup? tapped;
      await pumpTray(tester, layout: layout, onTap: (group) => tapped = group);
      await tester.tap(find.bySemanticsLabel('Burger Barn'));
      expect(tapped, shop);
    });

    testWidgets('${layout.name}: the label never clips at large text', (
      tester,
    ) async {
      await pumpTray(tester, layout: layout, textScale: 1.6);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the ring greys once every story was seen', (tester) async {
    await pumpTray(
      tester,
      layout: StoriesTrayLayout.cards,
      isSeen: (group, _) => group.id == 'shop',
    );
    final cards = tester.widgetList<StoryCard>(find.byType(StoryCard));
    expect(cards.map((card) => card.seen), [true, false]);
  });

  testWidgets('the avatar sits in the leading corner (RTL)', (tester) async {
    await pumpTray(
      tester,
      layout: StoriesTrayLayout.cards,
      direction: TextDirection.rtl,
    );
    final card = tester.getRect(find.byType(StoryCard).first);
    final avatar = tester.getRect(
      find
          .descendant(
            of: find.byType(StoryCard).first,
            matching: find.byType(ClipOval),
          )
          .first,
    );
    expect(avatar.center.dx, greaterThan(card.center.dx));
    expect(avatar.center.dy, lessThan(card.center.dy));
  });

  testWidgets('leading comes before the groups', (tester) async {
    await pumpTray(
      tester,
      layout: StoriesTrayLayout.cards,
      leading: const SizedBox(key: ValueKey('add'), width: 112, height: 200),
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('add'))).left,
      lessThan(tester.getRect(find.byType(StoryCard).first).left),
    );
  });

  testWidgets('a group without an avatar shows its initial', (tester) async {
    final store = FakeStoryMediaStore(completeImmediately: true);
    await tester.pumpWidget(
      MaterialApp(
        home: StoryCircle(group: _other, store: store),
      ),
    );
    expect(find.text('F'), findsOneWidget);
  });
}

final _other = StoryGroup(
  id: 'other',
  label: 'fresh market',
  items: const [
    WidgetStoryItem(id: 'w', duration: Duration(seconds: 1), builder: _blank),
  ],
);

Widget _blank(BuildContext context, Animation<double> progress) =>
    const SizedBox();
