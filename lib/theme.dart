import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ink on paper, with a highlighter for the words you save.
abstract final class Palette {
  static const paper = Color(0xFFF7F3EC);

  /// Index cards and other things lying on the paper.
  static const raised = Color(0xFFFFFDF8);
  static const sunk = Color(0xFFEFE9DF);
  static const sunkDeep = Color(0xFFE6DFD2);

  static const ink = Color(0xFF1E1B18);
  static const inkSoft = Color(0xFF6B635A);
  static const inkFaint = Color(0xFF9A9084);
  static const rule = Color(0xFFDDD4C6);
  static const outline = Color(0xFFB9AE9E);

  /// Only for saved or selected words, and the current tab.
  static const highlighter = Color(0xFFF2D45C);
  static const pencil = Color(0xFFB4412F);
  static const pencilWash = Color(0xFFF6DCD4);
  static const leaf = Color(0xFF2F6B3F);
  static const leafWash = Color(0xFFDCE8D6);
}

/// Serif for titles and the numbers that matter.
TextStyle serif({
  double? fontSize,
  FontWeight fontWeight = FontWeight.w500,
  Color? color,
  double? height,
  FontStyle? fontStyle,
}) => GoogleFonts.newsreader(
  fontSize: fontSize,
  fontWeight: fontWeight,
  // Explicit: inherited colors inside cards come out pale.
  color: color ?? Palette.ink,
  height: height,
  fontStyle: fontStyle,
);

/// Text in the language being learned ([language] is a course language
/// code), set in a serif that has its script.
TextStyle learned(
  String? language, {
  double? fontSize,
  FontWeight fontWeight = FontWeight.w500,
  Color? color,
  double? height,
}) => switch (language) {
  'ja' => GoogleFonts.notoSerifJp(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? Palette.ink,
    height: height,
  ),
  'zh' => GoogleFonts.notoSerifSc(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color ?? Palette.ink,
    height: height,
  ),
  _ => serif(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
  ),
};

ThemeData buildTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: Palette.ink,
        brightness: Brightness.light,
      ).copyWith(
        primary: Palette.ink,
        onPrimary: Palette.paper,
        primaryContainer: Palette.highlighter,
        onPrimaryContainer: Palette.ink,
        secondary: Palette.inkSoft,
        onSecondary: Palette.paper,
        secondaryContainer: Palette.sunkDeep,
        onSecondaryContainer: Palette.ink,
        error: Palette.pencil,
        onError: Palette.raised,
        errorContainer: Palette.pencilWash,
        onErrorContainer: Palette.ink,
        surface: Palette.paper,
        onSurface: Palette.ink,
        onSurfaceVariant: Palette.inkSoft,
        surfaceContainerLowest: Palette.raised,
        surfaceContainerLow: Palette.raised,
        surfaceContainer: Palette.sunk,
        surfaceContainerHigh: Palette.sunk,
        surfaceContainerHighest: Palette.sunkDeep,
        surfaceTint: Colors.transparent,
        outline: Palette.outline,
        outlineVariant: Palette.rule,
        inverseSurface: Palette.ink,
        onInverseSurface: Palette.paper,
      );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme);
  final sans = GoogleFonts.notoSansTextTheme(base.textTheme)
      .apply(bodyColor: Palette.ink, displayColor: Palette.ink);
  final text = sans.copyWith(
    displayLarge: serif(fontSize: 56, color: Palette.ink),
    displayMedium: serif(fontSize: 44, color: Palette.ink),
    displaySmall: serif(fontSize: 36, color: Palette.ink),
    headlineLarge: serif(fontSize: 32, color: Palette.ink),
    headlineMedium: serif(fontSize: 28, color: Palette.ink),
    headlineSmall: serif(fontSize: 24, color: Palette.ink),
    titleLarge: serif(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: Palette.ink,
    ),
    // Material's wide tracking reads airy in prose.
    bodyLarge: sans.bodyLarge?.copyWith(letterSpacing: 0.1),
    bodyMedium: sans.bodyMedium?.copyWith(letterSpacing: 0.1),
  );

  final corners = BorderRadius.circular(8);
  final buttonText = GoogleFonts.notoSans(
    fontSize: 15,
    fontWeight: FontWeight.w600,
  );
  const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 16);

  final inputs = InputDecorationThemeData(
    filled: true,
    fillColor: Palette.sunk,
    hintStyle: const TextStyle(color: Palette.inkSoft),
    // Underline borders keep floating labels inside the fill; focus draws
    // an ink line under the field.
    border: UnderlineInputBorder(
      borderRadius: corners,
      borderSide: BorderSide.none,
    ),
    enabledBorder: UnderlineInputBorder(
      borderRadius: corners,
      borderSide: BorderSide.none,
    ),
    focusedBorder: UnderlineInputBorder(
      borderRadius: corners,
      borderSide: const BorderSide(color: Palette.ink, width: 1.5),
    ),
  );

  return base.copyWith(
    scaffoldBackgroundColor: Palette.paper,
    textTheme: text,
    iconTheme: const IconThemeData(color: Palette.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: Palette.paper,
      foregroundColor: Palette.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: serif(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: Palette.ink,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.ink,
        foregroundColor: Palette.paper,
        disabledBackgroundColor: Palette.sunkDeep,
        disabledForegroundColor: Palette.inkFaint,
        padding: buttonPadding,
        textStyle: buttonText,
        shape: RoundedRectangleBorder(borderRadius: corners),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.ink,
        side: const BorderSide(color: Palette.ink),
        padding: buttonPadding,
        textStyle: buttonText,
        shape: RoundedRectangleBorder(borderRadius: corners),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Palette.ink,
        textStyle: buttonText,
        shape: RoundedRectangleBorder(borderRadius: corners),
      ),
    ),
    cardTheme: CardThemeData(
      color: Palette.raised,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: corners,
        side: const BorderSide(color: Palette.rule),
      ),
    ),
    inputDecorationTheme: inputs,
    // DropdownMenu reads its own theme, not inputDecorationTheme.
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: inputs,
      menuStyle: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(Palette.raised),
        surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Palette.raised,
      selectedColor: Palette.highlighter,
      side: const BorderSide(color: Palette.rule),
      labelStyle: const TextStyle(color: Palette.ink),
      checkmarkColor: Palette.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),
    dividerTheme: const DividerThemeData(
      color: Palette.rule,
      thickness: 1,
      space: 1,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Palette.ink,
      linearTrackColor: Palette.rule,
      circularTrackColor: Colors.transparent,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? Palette.highlighter
            : Palette.outline,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) ? Palette.ink : Palette.sunkDeep,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Palette.ink : Palette.outline,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Palette.ink,
      contentTextStyle: GoogleFonts.notoSans(color: Palette.paper),
      actionTextColor: Palette.highlighter,
      shape: RoundedRectangleBorder(borderRadius: corners),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.paper,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Palette.raised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titleTextStyle: serif(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: Palette.ink,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Palette.raised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: corners,
        side: const BorderSide(color: Palette.rule),
      ),
    ),
    listTileTheme: const ListTileThemeData(iconColor: Palette.ink),
  );
}
