import 'package:flutter/material.dart';
import 'package:stories_player/stories_player.dart';
import 'package:stories_player_lottie/stories_player_lottie.dart';
import 'package:stories_player_video/stories_player_video.dart';

StoryMedia _photo(int id) => StoryMedia.asset('assets/images/p$id.jpg');

StoryMedia _avatar(int id) => StoryMedia.asset('assets/avatars/a$id.jpg');

StoryMedia _video(String name) => StoryMedia.network(
  Uri.parse(
    'https://flutter.github.io/assets-for-api-docs/assets/videos/$name.mp4',
  ),
  kind: StoryMediaKind.video,
);

/// A video bundled with the example, with its first frame as the poster.
StoryMedia _bundledVideo(String name) =>
    StoryMedia.asset('assets/videos/$name.mp4', kind: StoryMediaKind.video);

StoryMedia _videoPoster(String name) =>
    StoryMedia.asset('assets/videos/${name}_poster.jpg');

const _music = StoryAudio(
  StoryMedia.asset('assets/audio/sunny_loop.wav', kind: StoryMediaKind.audio),
  length: Duration(seconds: 8),
);

/// The words of the demo, in English or Arabic.
class DemoCopy {
  const DemoCopy._({
    required this.market,
    required this.coffee,
    required this.salad,
    required this.bakery,
    required this.kitchen,
    required this.ago,
    required this.strawberries,
    required this.raspberries,
    required this.grapes,
    required this.latte,
    required this.beeVideo,
    required this.pourOver,
    required this.saladBowl,
    required this.yogurt,
    required this.preparing,
    required this.cake,
    required this.croissants,
    required this.cookies,
    required this.delivered,
    required this.freeDelivery,
    required this.freeDeliveryBody,
    required this.butterfly,
  });

  static const english = DemoCopy._(
    market: 'Fresh Market',
    coffee: 'Coffee Corner',
    salad: 'Salad Bar',
    bakery: 'Sweet Bakery',
    kitchen: 'Our Kitchen',
    ago: '2h',
    strawberries: 'Strawberries are in season. 2 boxes for the price of 1.',
    raspberries: 'Raspberries picked this morning.',
    grapes: 'Sweet black grapes, delivered cold.',
    latte: 'Your morning latte, at your door in 20 minutes.',
    beeVideo: 'Our honey comes straight from local farms.',
    pourOver: 'New: single-origin pour-over.',
    saladBowl: 'Build your own bowl, 30 toppings.',
    yogurt: 'Greek yogurt with fresh berries.',
    preparing: 'Your bowl is being prepared.',
    cake: 'Chocolate pear cake, today only.',
    croissants: 'Fresh croissants every morning at 7.',
    cookies: 'Cookies, still warm.',
    delivered: 'Order delivered! Enjoy your meal.',
    freeDelivery: 'Free delivery',
    freeDeliveryBody: 'On every order this weekend.',
    butterfly: 'Spring menu, now live.',
  );

  static const arabic = DemoCopy._(
    market: 'سوق الفواكه',
    coffee: 'ركن القهوة',
    salad: 'بار السلطات',
    bakery: 'مخبز الحلويات',
    kitchen: 'مطبخنا',
    ago: 'منذ ساعتين',
    strawberries: 'موسم الفراولة بدأ. علبتان بسعر علبة واحدة.',
    raspberries: 'توت أحمر قُطف هذا الصباح.',
    grapes: 'عنب أسود حلو، يصلك باردًا.',
    latte: 'لاتيه الصباح عند بابك خلال ٢٠ دقيقة.',
    beeVideo: 'عسلنا يأتي مباشرة من المزارع المحلية.',
    pourOver: 'جديد: قهوة مقطّرة من مصدر واحد.',
    saladBowl: 'اصنع طبقك بنفسك، ٣٠ إضافة.',
    yogurt: 'زبادي يوناني مع التوت الطازج.',
    preparing: 'يتم تجهيز طلبك الآن.',
    cake: 'كعكة الشوكولاتة بالكمثرى، اليوم فقط.',
    croissants: 'كرواسون طازج كل صباح في السابعة.',
    cookies: 'كوكيز، ما زالت دافئة.',
    delivered: 'تم توصيل طلبك! بالهناء والشفاء.',
    freeDelivery: 'توصيل مجاني',
    freeDeliveryBody: 'على كل الطلبات في عطلة نهاية الأسبوع.',
    butterfly: 'قائمة الربيع متاحة الآن.',
  );

  final String market, coffee, salad, bakery, kitchen, ago;
  final String strawberries, raspberries, grapes;
  final String latte, beeVideo, pourOver;
  final String saladBowl, yogurt, preparing;
  final String cake, croissants, cookies;
  final String delivered, freeDelivery, freeDeliveryBody, butterfly;
}

/// The demo's groups: images with music, video, Lottie and widget items.
List<StoryGroup> demoGroups(DemoCopy copy) => [
  StoryGroup(
    id: 'market',
    label: copy.market,
    subtitle: copy.ago,
    avatar: _avatar(1080),
    items: [
      ImageStoryItem(
        id: 'market-strawberries',
        image: _photo(1080),
        audio: _music,
        caption: copy.strawberries,
        placeholderColor: const Color(0xFF8E1B1B),
        duration: const Duration(seconds: 6),
      ),
      // A food video with its own soundtrack; its captions are part of the
      // video, so the item sets none.
      VideoStoryItem(
        id: 'market-fruit-video',
        video: _bundledVideo('market_fruit'),
        poster: _videoPoster('market_fruit'),
        placeholderColor: const Color(0xFF8E1B1B),
      ),
      ImageStoryItem(
        id: 'market-grapes',
        image: _photo(674),
        caption: copy.grapes,
        placeholderColor: const Color(0xFF2B3550),
      ),
    ],
  ),
  StoryGroup(
    id: 'coffee',
    label: copy.coffee,
    subtitle: copy.ago,
    avatar: _avatar(431),
    items: [
      ImageStoryItem(
        id: 'coffee-latte',
        image: _photo(431),
        caption: copy.latte,
        placeholderColor: const Color(0xFF3B2416),
      ),
      VideoStoryItem(
        id: 'coffee-bee',
        video: _video('bee'),
        poster: _photo(312),
        caption: copy.beeVideo,
        placeholderColor: const Color(0xFF1B1B1B),
        duration: const Duration(seconds: 8),
      ),
      ImageStoryItem(
        id: 'coffee-pourover',
        image: _photo(1060),
        caption: copy.pourOver,
        placeholderColor: const Color(0xFF2E3A40),
      ),
    ],
  ),
  StoryGroup(
    id: 'salad',
    label: copy.salad,
    subtitle: copy.ago,
    avatar: _avatar(488),
    items: [
      ImageStoryItem(
        id: 'salad-bowl',
        image: _photo(488),
        caption: copy.saladBowl,
        placeholderColor: const Color(0xFFE8E2D6),
      ),
      ImageStoryItem(
        id: 'salad-yogurt',
        image: _photo(493),
        caption: copy.yogurt,
        placeholderColor: const Color(0xFFF2EEEA),
      ),
      LottieStoryItem(
        id: 'salad-preparing',
        animation: const StoryMedia.asset(
          'assets/lottie/preparing.json',
          kind: StoryMediaKind.lottie,
        ),
        loop: true,
        duration: const Duration(seconds: 5),
        backgroundColor: const Color(0xFF1F6F5C),
        placeholderColor: const Color(0xFF1F6F5C),
        caption: copy.preparing,
      ),
    ],
  ),
  StoryGroup(
    id: 'bakery',
    label: copy.bakery,
    subtitle: copy.ago,
    avatar: _avatar(999),
    items: [
      VideoStoryItem(
        id: 'bakery-video',
        video: _bundledVideo('bakery_sweets'),
        poster: _videoPoster('bakery_sweets'),
        hasSound: false,
        placeholderColor: const Color(0xFF20262C),
      ),
      WidgetStoryItem(
        id: 'bakery-croissants',
        duration: const Duration(seconds: 5),
        placeholderColor: const Color(0xFFFFB347),
        builder: (context, progress) => _TextStory(
          text: copy.croissants,
          progress: progress,
          colors: const [Color(0xFFFFB347), Color(0xFFFF6B6B)],
        ),
      ),
      ImageStoryItem(
        id: 'bakery-cookies',
        image: _photo(835),
        caption: copy.cookies,
        placeholderColor: const Color(0xFF2A2420),
      ),
    ],
  ),
  StoryGroup(
    id: 'kitchen',
    label: copy.kitchen,
    subtitle: copy.ago,
    avatar: _avatar(1025),
    items: [
      LottieStoryItem(
        id: 'kitchen-delivered',
        animation: const StoryMedia.asset(
          'assets/lottie/celebrate.json',
          kind: StoryMediaKind.lottie,
        ),
        audio: _music,
        backgroundColor: const Color(0xFF2B1B4A),
        placeholderColor: const Color(0xFF2B1B4A),
        caption: copy.delivered,
      ),
      WidgetStoryItem(
        id: 'kitchen-free-delivery',
        duration: const Duration(seconds: 5),
        placeholderColor: const Color(0xFF0EAD69),
        builder: (context, progress) => _PromoStory(
          title: copy.freeDelivery,
          body: copy.freeDeliveryBody,
          progress: progress,
        ),
      ),
      VideoStoryItem(
        id: 'kitchen-spring',
        video: _video('butterfly'),
        caption: copy.butterfly,
        placeholderColor: const Color(0xFF101010),
      ),
    ],
  ),
];

/// A group whose image cannot load, to show error handling.
StoryGroup errorGroup(DemoCopy copy) => StoryGroup(
  id: 'offline',
  label: copy.market,
  avatar: _avatar(225),
  items: [
    ImageStoryItem(
      id: 'offline-missing',
      image: StoryMedia.network(
        Uri.parse('https://stories-player.invalid/missing.jpg'),
      ),
      placeholderColor: const Color(0xFF263238),
    ),
  ],
);

class _TextStory extends StatelessWidget {
  const _TextStory({
    required this.text,
    required this.progress,
    required this.colors,
  });

  final String text;
  final Animation<double> progress;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: colors,
      ),
    ),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: AnimatedBuilder(
          animation: progress,
          builder: (context, child) => Transform.scale(
            scale: 0.92 + 0.08 * Curves.easeOut.transform(progress.value),
            child: child,
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              height: 1.25,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    ),
  );
}

class _PromoStory extends StatelessWidget {
  const _PromoStory({
    required this.title,
    required this.body,
    required this.progress,
  });

  final String title;
  final String body;
  final Animation<double> progress;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF0EAD69),
    child: Center(
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, child) => Transform.rotate(
          angle:
              -0.06 +
              0.06 *
                  Curves.elasticOut.transform(
                    (progress.value * 2).clamp(0.0, 1.0),
                  ),
          child: child,
        ),
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(color: Color(0x33000000), blurRadius: 24),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.delivery_dining_rounded,
                size: 72,
                color: Color(0xFF0EAD69),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF14213D),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, color: Color(0xFF4A5568)),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
