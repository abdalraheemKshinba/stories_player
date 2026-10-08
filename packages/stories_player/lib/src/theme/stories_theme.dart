import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Colours, sizes and text styles of a [StoriesPlayer].
///
/// Values resolve from the nearest [StoriesTheme], then from a
/// [StoriesThemeData] registered in [ThemeData.extensions], then from
/// [StoriesThemeData.fallback]. Fields left `null` take the fallback's
/// value.
///
/// {@tool snippet}
/// ```dart
/// MaterialApp(
///   theme: ThemeData(
///     extensions: const [
///       StoriesThemeData(progressFillColor: Colors.amber, progressHeight: 3),
///     ],
///   ),
///   home: const MyHome(),
/// )
/// ```
/// {@end-tool}
@immutable
class StoriesThemeData extends ThemeExtension<StoriesThemeData>
    with Diagnosticable {
  /// Creates a theme. Unset fields take the fallback's values.
  const StoriesThemeData({
    this.backgroundColor,
    this.progressTrackColor,
    this.progressFillColor,
    this.progressHeight,
    this.progressGap,
    this.progressRadius,
    this.progressPadding,
    this.titleStyle,
    this.subtitleStyle,
    this.captionStyle,
    this.iconColor,
    this.avatarSize,
    this.topScrim,
    this.bottomScrim,
    this.loadingColor,
  });

  /// The values used when nothing else is set.
  static const StoriesThemeData fallback = StoriesThemeData(
    backgroundColor: Color(0xFF000000),
    progressTrackColor: Color(0x59FFFFFF),
    progressFillColor: Color(0xFFFFFFFF),
    progressHeight: 2.5,
    progressGap: 4,
    progressRadius: 2,
    progressPadding: EdgeInsetsDirectional.fromSTEB(8, 8, 8, 0),
    titleStyle: TextStyle(
      color: Color(0xFFFFFFFF),
      fontSize: 14,
      fontWeight: FontWeight.w600,
      shadows: [Shadow(color: Color(0x66000000), blurRadius: 4)],
    ),
    subtitleStyle: TextStyle(
      color: Color(0xCCFFFFFF),
      fontSize: 12,
      shadows: [Shadow(color: Color(0x66000000), blurRadius: 4)],
    ),
    captionStyle: TextStyle(
      color: Color(0xFFFFFFFF),
      fontSize: 16,
      height: 1.35,
      fontWeight: FontWeight.w500,
      shadows: [Shadow(color: Color(0x80000000), blurRadius: 6)],
    ),
    iconColor: Color(0xFFFFFFFF),
    avatarSize: 34,
    topScrim: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x66000000), Color(0x00000000)],
    ),
    bottomScrim: LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [Color(0x99000000), Color(0x00000000)],
    ),
    loadingColor: Color(0xFFFFFFFF),
  );

  /// Painted behind media and around it on wide screens.
  final Color? backgroundColor;

  /// The unfilled part of each progress segment.
  final Color? progressTrackColor;

  /// The filled part of each progress segment.
  final Color? progressFillColor;

  /// The height of the progress bar.
  final double? progressHeight;

  /// The space between progress segments.
  final double? progressGap;

  /// The corner radius of progress segments.
  final double? progressRadius;

  /// The space around the progress bar.
  final EdgeInsetsGeometry? progressPadding;

  /// The group label in the header.
  final TextStyle? titleStyle;

  /// The group subtitle in the header.
  final TextStyle? subtitleStyle;

  /// The caption in the footer.
  final TextStyle? captionStyle;

  /// The header's buttons.
  final Color? iconColor;

  /// The diameter of the header avatar.
  final double? avatarSize;

  /// Painted behind the progress bar and header, for contrast.
  final Gradient? topScrim;

  /// Painted behind the caption, for contrast.
  final Gradient? bottomScrim;

  /// The loading indicator.
  final Color? loadingColor;

  /// Returns this theme with every `null` field taken from [other].
  StoriesThemeData merge(StoriesThemeData? other) {
    if (other == null) return this;
    return StoriesThemeData(
      backgroundColor: backgroundColor ?? other.backgroundColor,
      progressTrackColor: progressTrackColor ?? other.progressTrackColor,
      progressFillColor: progressFillColor ?? other.progressFillColor,
      progressHeight: progressHeight ?? other.progressHeight,
      progressGap: progressGap ?? other.progressGap,
      progressRadius: progressRadius ?? other.progressRadius,
      progressPadding: progressPadding ?? other.progressPadding,
      titleStyle: other.titleStyle?.merge(titleStyle) ?? titleStyle,
      subtitleStyle: other.subtitleStyle?.merge(subtitleStyle) ?? subtitleStyle,
      captionStyle: other.captionStyle?.merge(captionStyle) ?? captionStyle,
      iconColor: iconColor ?? other.iconColor,
      avatarSize: avatarSize ?? other.avatarSize,
      topScrim: topScrim ?? other.topScrim,
      bottomScrim: bottomScrim ?? other.bottomScrim,
      loadingColor: loadingColor ?? other.loadingColor,
    );
  }

  @override
  StoriesThemeData copyWith({
    Color? backgroundColor,
    Color? progressTrackColor,
    Color? progressFillColor,
    double? progressHeight,
    double? progressGap,
    double? progressRadius,
    EdgeInsetsGeometry? progressPadding,
    TextStyle? titleStyle,
    TextStyle? subtitleStyle,
    TextStyle? captionStyle,
    Color? iconColor,
    double? avatarSize,
    Gradient? topScrim,
    Gradient? bottomScrim,
    Color? loadingColor,
  }) => StoriesThemeData(
    backgroundColor: backgroundColor ?? this.backgroundColor,
    progressTrackColor: progressTrackColor ?? this.progressTrackColor,
    progressFillColor: progressFillColor ?? this.progressFillColor,
    progressHeight: progressHeight ?? this.progressHeight,
    progressGap: progressGap ?? this.progressGap,
    progressRadius: progressRadius ?? this.progressRadius,
    progressPadding: progressPadding ?? this.progressPadding,
    titleStyle: titleStyle ?? this.titleStyle,
    subtitleStyle: subtitleStyle ?? this.subtitleStyle,
    captionStyle: captionStyle ?? this.captionStyle,
    iconColor: iconColor ?? this.iconColor,
    avatarSize: avatarSize ?? this.avatarSize,
    topScrim: topScrim ?? this.topScrim,
    bottomScrim: bottomScrim ?? this.bottomScrim,
    loadingColor: loadingColor ?? this.loadingColor,
  );

  @override
  StoriesThemeData lerp(StoriesThemeData? other, double t) {
    if (other == null) return this;
    return StoriesThemeData(
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t),
      progressTrackColor: Color.lerp(
        progressTrackColor,
        other.progressTrackColor,
        t,
      ),
      progressFillColor: Color.lerp(
        progressFillColor,
        other.progressFillColor,
        t,
      ),
      progressHeight: lerpDouble(progressHeight, other.progressHeight, t),
      progressGap: lerpDouble(progressGap, other.progressGap, t),
      progressRadius: lerpDouble(progressRadius, other.progressRadius, t),
      progressPadding: EdgeInsetsGeometry.lerp(
        progressPadding,
        other.progressPadding,
        t,
      ),
      titleStyle: TextStyle.lerp(titleStyle, other.titleStyle, t),
      subtitleStyle: TextStyle.lerp(subtitleStyle, other.subtitleStyle, t),
      captionStyle: TextStyle.lerp(captionStyle, other.captionStyle, t),
      iconColor: Color.lerp(iconColor, other.iconColor, t),
      avatarSize: lerpDouble(avatarSize, other.avatarSize, t),
      topScrim: Gradient.lerp(topScrim, other.topScrim, t),
      bottomScrim: Gradient.lerp(bottomScrim, other.bottomScrim, t),
      loadingColor: Color.lerp(loadingColor, other.loadingColor, t),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(ColorProperty('backgroundColor', backgroundColor))
      ..add(ColorProperty('progressTrackColor', progressTrackColor))
      ..add(ColorProperty('progressFillColor', progressFillColor))
      ..add(DoubleProperty('progressHeight', progressHeight))
      ..add(DoubleProperty('progressGap', progressGap))
      ..add(DoubleProperty('avatarSize', avatarSize))
      ..add(ColorProperty('iconColor', iconColor));
  }
}

/// Applies a [StoriesThemeData] to the [StoriesPlayer]s below it.
class StoriesTheme extends InheritedTheme {
  /// Applies [data] to [child].
  const StoriesTheme({super.key, required this.data, required super.child});

  /// The theme to apply.
  final StoriesThemeData data;

  /// The fully resolved theme for [context]: the nearest [StoriesTheme],
  /// then the [ThemeData] extension, then [StoriesThemeData.fallback].
  static StoriesThemeData of(BuildContext context) {
    final local = context.dependOnInheritedWidgetOfExactType<StoriesTheme>();
    final extension = Theme.of(context).extension<StoriesThemeData>();
    return (local?.data ?? const StoriesThemeData())
        .merge(extension)
        .merge(StoriesThemeData.fallback);
  }

  @override
  Widget wrap(BuildContext context, Widget child) =>
      StoriesTheme(data: data, child: child);

  @override
  bool updateShouldNotify(StoriesTheme oldWidget) => data != oldWidget.data;
}
