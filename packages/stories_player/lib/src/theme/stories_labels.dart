import 'package:flutter/foundation.dart';

/// The words a [StoriesPlayer] shows and announces to screen readers.
///
/// English, Arabic and French are built in. Pass your own for any other
/// language, or to match your app's tone.
///
/// {@tool snippet}
/// ```dart
/// StoriesPlayer(
///   groups: groups,
///   labels: Localizations.localeOf(context).languageCode == 'ar'
///       ? StoriesLabels.arabic
///       : StoriesLabels.english,
/// )
/// ```
/// {@end-tool}
@immutable
final class StoriesLabels {
  /// Creates labels. [itemPosition] may use `{index}`, `{count}` and
  /// `{label}` placeholders.
  const StoriesLabels({
    required this.close,
    required this.mute,
    required this.unmute,
    required this.next,
    required this.previous,
    required this.pause,
    required this.resume,
    required this.retry,
    required this.loadFailed,
    required this.itemPosition,
    this.retrying = 'Retrying…',
    this.stillFailing = "Still couldn't load this story",
    this.skip = 'Skip',
  });

  /// English labels. The default.
  static const StoriesLabels english = StoriesLabels(
    close: 'Close',
    mute: 'Mute',
    unmute: 'Unmute',
    next: 'Next story',
    previous: 'Previous story',
    pause: 'Pause',
    resume: 'Resume',
    retry: 'Retry',
    loadFailed: "Couldn't load this story",
    itemPosition: 'Story {index} of {count}, {label}',
  );

  /// Arabic labels.
  static const StoriesLabels arabic = StoriesLabels(
    close: 'إغلاق',
    mute: 'كتم الصوت',
    unmute: 'تشغيل الصوت',
    next: 'القصة التالية',
    previous: 'القصة السابقة',
    pause: 'إيقاف مؤقت',
    resume: 'متابعة',
    retry: 'إعادة المحاولة',
    loadFailed: 'تعذّر تحميل هذه القصة',
    itemPosition: 'القصة {index} من {count}، {label}',
    retrying: 'جارٍ إعادة المحاولة…',
    stillFailing: 'ما زال تعذّر تحميل هذه القصة',
    skip: 'تخطٍّ',
  );

  /// French labels.
  static const StoriesLabels french = StoriesLabels(
    close: 'Fermer',
    mute: 'Couper le son',
    unmute: 'Activer le son',
    next: 'Story suivante',
    previous: 'Story précédente',
    pause: 'Pause',
    resume: 'Reprendre',
    retry: 'Réessayer',
    loadFailed: 'Impossible de charger cette story',
    itemPosition: 'Story {index} sur {count}, {label}',
    retrying: 'Nouvelle tentative…',
    stillFailing: 'Toujours impossible de charger cette story',
    skip: 'Passer',
  );

  /// The close button.
  final String close;

  /// The mute button while sound is on.
  final String mute;

  /// The mute button while sound is off.
  final String unmute;

  /// The screen-reader action that moves forward.
  final String next;

  /// The screen-reader action that moves back.
  final String previous;

  /// The screen-reader action that pauses.
  final String pause;

  /// The screen-reader action that resumes.
  final String resume;

  /// The retry button on a failed item.
  final String retry;

  /// The message on a failed item.
  final String loadFailed;

  /// What screen readers announce for an item, with `{index}`, `{count}`
  /// and `{label}` placeholders.
  final String itemPosition;

  /// Shown while a retry the user asked for is loading.
  final String retrying;

  /// The message after a retry failed too.
  final String stillFailing;

  /// The button that moves past an item that keeps failing.
  final String skip;

  /// Fills in [itemPosition].
  String describeItem({
    required int index,
    required int count,
    required String label,
  }) => itemPosition
      .replaceAll('{index}', '$index')
      .replaceAll('{count}', '$count')
      .replaceAll('{label}', label);
}
