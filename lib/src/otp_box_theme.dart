import 'package:flutter/material.dart';

/// How a single box of an [OtpTextField] looks.
///
/// Create one with the default constructor, or start from a preset with
/// [OtpBoxTheme.outlined], [OtpBoxTheme.circle], [OtpBoxTheme.underlined] or
/// [OtpBoxTheme.filled], and adjust it with [copyWith].
@immutable
class OtpBoxTheme {
  /// Creates a box theme. Every value is optional; [width] and [height]
  /// default to 52 × 58.
  const OtpBoxTheme({
    this.width = 52,
    this.height = 58,
    this.textStyle,
    this.decoration,
    this.padding,
    this.margin,
  });

  /// A box with a rounded border on every side.
  factory OtpBoxTheme.outlined({
    double width = 52,
    double height = 58,
    double radius = 12,
    Color borderColor = const Color(0xFFBDBDBD),
    double borderWidth = 1.5,
    Color? fillColor,
    TextStyle? textStyle,
  }) {
    return OtpBoxTheme(
      width: width,
      height: height,
      textStyle: textStyle,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
    );
  }

  /// A round box. [fillColor] is optional; the border takes the state colors
  /// (focused, error, ...) like the other presets.
  factory OtpBoxTheme.circle({
    double size = 52,
    Color borderColor = const Color(0xFFBDBDBD),
    double borderWidth = 1.5,
    Color? fillColor,
    TextStyle? textStyle,
  }) {
    return OtpBoxTheme(
      width: size,
      height: size,
      textStyle: textStyle,
      decoration: BoxDecoration(
        color: fillColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
    );
  }

  /// A box with only a bottom line.
  factory OtpBoxTheme.underlined({
    double width = 44,
    double height = 56,
    Color borderColor = const Color(0xFFBDBDBD),
    double borderWidth = 2,
    TextStyle? textStyle,
  }) {
    return OtpBoxTheme(
      width: width,
      height: height,
      textStyle: textStyle,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: borderColor, width: borderWidth),
        ),
      ),
    );
  }

  /// A box with a background color and no border.
  factory OtpBoxTheme.filled({
    double width = 52,
    double height = 58,
    double radius = 12,
    Color fillColor = const Color(0xFFF1F1F4),
    TextStyle? textStyle,
  }) {
    return OtpBoxTheme(
      width: width,
      height: height,
      textStyle: textStyle,
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.transparent, width: 2),
      ),
    );
  }

  /// Width of the box.
  final double width;

  /// Height of the box.
  final double height;

  /// Style of the digit inside the box.
  final TextStyle? textStyle;

  /// Background, border, radius and shadow of the box.
  final BoxDecoration? decoration;

  /// Space inside the box.
  final EdgeInsetsGeometry? padding;

  /// Space around the box. Usually you'll want [OtpTextField.spacing] instead.
  final EdgeInsetsGeometry? margin;

  /// Returns a copy with the given values replaced.
  OtpBoxTheme copyWith({
    double? width,
    double? height,
    TextStyle? textStyle,
    BoxDecoration? decoration,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
  }) {
    return OtpBoxTheme(
      width: width ?? this.width,
      height: height ?? this.height,
      textStyle: textStyle ?? this.textStyle,
      decoration: decoration ?? this.decoration,
      padding: padding ?? this.padding,
      margin: margin ?? this.margin,
    );
  }

  /// Returns a copy with only the border color changed. Handy for building
  /// the focused, filled and error themes from one base theme.
  OtpBoxTheme copyBorderWith({required Color color, double? width}) {
    final border = decoration?.border;
    Border newBorder;
    if (border is Border &&
        border.top == BorderSide.none &&
        border.bottom != BorderSide.none) {
      // Underlined style: keep only the bottom line.
      newBorder = Border(
        bottom: border.bottom.copyWith(color: color, width: width),
      );
    } else {
      final side = border is Border ? border.top : const BorderSide();
      newBorder = Border.all(color: color, width: width ?? side.width);
    }
    return copyWith(
      decoration: (decoration ?? const BoxDecoration()).copyWith(
        border: newBorder,
      ),
    );
  }

  /// Returns a copy with the text style merged with [style].
  OtpBoxTheme mergeTextStyle(TextStyle? style) =>
      copyWith(textStyle: textStyle?.merge(style) ?? style);
}

/// The state of one box, passed to [OtpTextField.boxBuilder].
@immutable
class OtpBoxState {
  /// Creates the state of one box. [OtpTextField] creates these for you.
  const OtpBoxState({
    required this.index,
    required this.value,
    required this.isFocused,
    required this.isFilled,
    required this.hasError,
    required this.enabled,
  });

  /// Position of the box, starting at 0.
  final int index;

  /// The character in this box, or an empty string.
  final String value;

  /// Whether this is the box the next character goes into.
  final bool isFocused;

  /// Whether this box has a character.
  final bool isFilled;

  /// Whether the field is showing an error.
  final bool hasError;

  /// Whether the field is enabled.
  final bool enabled;
}
