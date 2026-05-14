import 'package:flutter/material.dart';

/// Lexy Files theme — dark navy + cyan.
///
/// Palette derived from the Windows reference mockups in `design/windows/`:
/// - Page bg: #051424  (deep navy)
/// - Surface: #122131  (cards, sidebar)
/// - Accent:  #00F0FF  (cyan, primary action + active state)
/// - Text:    #D0E0F0 / #8B9BAE
///
/// Legacy token names (primaryColor, background, etc.) are preserved so
/// existing screens pick up the new look without per-file refactors.
class AppTheme {
  // ── Core surfaces ────────────────────────────────────────────────────────
  static const Color bgPage = Color(0xFF051424);
  static const Color bgDeep = Color(0xFF001020);
  static const Color surfaceColor = Color(0xFF122131);
  static const Color surface2 = Color(0xFF102030); // sidebar / subtle variant
  static const Color surface3 = Color(0xFF172737); // elevated card
  static const Color borderSubtle = Color(0xFF203040);
  static const Color borderStrong = Color(0xFF103040);

  // ── Accent (cyan) ────────────────────────────────────────────────────────
  static const Color accentColor = Color(0xFF00F0FF);
  static const Color accentHover = Color(0xFF00D0E0);
  static const Color accentDeep = Color(0xFF008090);
  static const Color accentDark = Color(0xFF006070);

  // ── Text ─────────────────────────────────────────────────────────────────
  static const Color text1 = Color(0xFFD0E0F0); // primary
  static const Color text2 = Color(0xFF8B9BAE); // secondary
  static const Color text3 = Color(0xFF6B7280); // tertiary / disabled

  // ── State ────────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF10E5A8);
  static const Color successDark = Color(0xFF0AA97E);
  static const Color warning = Color(0xFFF5B840);
  static const Color error = Color(0xFFFF4D6A);
  static const Color info = Color(0xFF3BA7FF);

  // ── Legacy aliases (keep old screens compiling & retinted) ──────────────
  static const Color primaryColor = accentColor;
  static const Color primaryDark = accentHover;
  static const Color primaryLight = accentDeep;
  static const Color primarySubtle = Color(0x3300F0FF); // 20% cyan
  static const Color accent = accentColor;
  static const Color surface = surfaceColor;
  static const Color surfaceMuted = surface2;
  static const Color background = bgPage;
  static const Color textPrimary = text1;
  static const Color textSecondary = text2;
  static const Color textTertiary = text3;
  static const Color border = borderSubtle;

  // ── Radii ───────────────────────────────────────────────────────────────
  static const double radiusSm = 8;
  static const double radiusMd = 10;
  static const double radiusLg = 14;
  static const double radiusXl = 18;
  static const double radiusPill = 999;

  // ── Sidebar metrics ─────────────────────────────────────────────────────
  static const double sidebarWidth = 248;
  static const double topBarHeight = 56;

  // ── Gradients ───────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentColor, accentDeep],
  );

  /// Hero gradient: soft deep-navy with a cyan glow band.
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0C2C44), Color(0xFF0A1A2C)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [success, successDark],
  );

  /// Dimmed grey gradient for offline device icons.
  static const LinearGradient offlineGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2A3B4E), Color(0xFF1E2B3A)],
  );

  // ── Shadows (subtle - we are on a dark surface) ─────────────────────────
  static const List<BoxShadow> shadowSm = [
    BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> shadowMd = [
    BoxShadow(color: Color(0x40000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> shadowLg = [
    BoxShadow(color: Color(0x55000000), blurRadius: 24, offset: Offset(0, 8)),
  ];

  /// Cyan glow used for primary buttons / active sidebar pill.
  static List<BoxShadow> accentGlow({double alpha = 0.35}) => [
    BoxShadow(
      color: accentColor.withValues(alpha: alpha),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
  ];

  static ThemeData get lightTheme => _buildTheme();

  /// Kept for backwards compatibility; the app always renders dark.
  static ThemeData get darkTheme => _buildTheme();

  static ThemeData _buildTheme() {
    final scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: accentColor,
      onPrimary: bgDeep,
      primaryContainer: surface3,
      onPrimaryContainer: text1,
      secondary: accentHover,
      onSecondary: bgDeep,
      secondaryContainer: surface2,
      onSecondaryContainer: text1,
      tertiary: info,
      onTertiary: bgDeep,
      error: error,
      onError: Colors.white,
      surface: surfaceColor,
      onSurface: text1,
      surfaceContainerHighest: surface3,
      onSurfaceVariant: text2,
      outline: borderSubtle,
      outlineVariant: borderStrong,
      shadow: Colors.black,
      scrim: Colors.black54,
      inverseSurface: text1,
      onInverseSurface: bgDeep,
      inversePrimary: accentDeep,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: bgPage,
      canvasColor: bgPage,
      fontFamily: 'Roboto',
      splashColor: accentColor.withValues(alpha: 0.12),
      highlightColor: accentColor.withValues(alpha: 0.08),
      hoverColor: accentColor.withValues(alpha: 0.06),

      appBarTheme: const AppBarTheme(
        backgroundColor: bgPage,
        foregroundColor: text1,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: text1),
        titleTextStyle: TextStyle(
          color: text1,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),

      cardTheme: CardThemeData(
        color: surfaceColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface2,
        hintStyle: const TextStyle(color: text3),
        labelStyle: const TextStyle(color: text2),
        prefixIconColor: text2,
        suffixIconColor: text2,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: borderSubtle, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: borderSubtle, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: accentColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: bgDeep,
          disabledBackgroundColor: surface3,
          disabledForegroundColor: text3,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: bgDeep,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accentColor,
          side: const BorderSide(color: accentColor, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentColor,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: text2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface2,
        surfaceTintColor: Colors.transparent,
        indicatorColor: accentColor.withValues(alpha: 0.18),
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected) ? accentColor : text2,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? accentColor : text2,
            size: 24,
          ),
        ),
        height: 68,
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface2,
        indicatorColor: accentColor.withValues(alpha: 0.18),
        selectedIconTheme: const IconThemeData(color: accentColor, size: 24),
        unselectedIconTheme: const IconThemeData(color: text2, size: 24),
        selectedLabelTextStyle: const TextStyle(
          color: accentColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: text2,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),

      tabBarTheme: const TabBarThemeData(
        labelColor: accentColor,
        unselectedLabelColor: text2,
        indicatorColor: accentColor,
        dividerColor: borderSubtle,
        labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: surface3,
        selectedColor: accentColor.withValues(alpha: 0.18),
        labelStyle: const TextStyle(color: text1, fontSize: 12),
        side: const BorderSide(color: borderSubtle),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPill),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surface3,
        contentTextStyle: const TextStyle(color: text1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: borderSubtle),
        ),
      ),

      dividerTheme: const DividerThemeData(color: borderSubtle, thickness: 1),

      dialogTheme: DialogThemeData(
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusXl),
          side: const BorderSide(color: borderSubtle),
        ),
        titleTextStyle: const TextStyle(
          color: text1,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(color: text2, fontSize: 14),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: surfaceColor,
        surfaceTintColor: Colors.transparent,
        textStyle: const TextStyle(color: text1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: borderSubtle),
        ),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accentColor,
        linearTrackColor: surface2,
        circularTrackColor: Color(0x3300F0FF),
      ),

      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(borderStrong),
        trackColor: WidgetStateProperty.all(surface2),
        thickness: WidgetStateProperty.all(6),
        radius: const Radius.circular(3),
      ),

      listTileTheme: const ListTileThemeData(
        iconColor: text2,
        textColor: text1,
      ),

      textTheme: const TextTheme(
        displayLarge: TextStyle(color: text1, fontWeight: FontWeight.w800),
        displayMedium: TextStyle(color: text1, fontWeight: FontWeight.w800),
        displaySmall: TextStyle(color: text1, fontWeight: FontWeight.w700),
        headlineLarge: TextStyle(color: text1, fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(color: text1, fontWeight: FontWeight.w700),
        headlineSmall: TextStyle(color: text1, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(color: text1, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: text1, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: text1, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: text1),
        bodyMedium: TextStyle(color: text1),
        bodySmall: TextStyle(color: text2),
        labelLarge: TextStyle(color: text1, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(color: text2),
        labelSmall: TextStyle(color: text2),
      ),
    );
  }
}
