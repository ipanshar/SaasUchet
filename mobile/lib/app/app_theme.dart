import 'package:flutter/material.dart';

enum AppThemePreset {
  emerald,
  graphite,
  ocean,
  contrast,
}

extension AppThemePresetInfo on AppThemePreset {
  String get storageKey {
    switch (this) {
      case AppThemePreset.emerald:
        return 'emerald';
      case AppThemePreset.graphite:
        return 'graphite';
      case AppThemePreset.ocean:
        return 'ocean';
      case AppThemePreset.contrast:
        return 'contrast';
    }
  }

  String get label {
    switch (this) {
      case AppThemePreset.emerald:
        return 'Изумрудная';
      case AppThemePreset.graphite:
        return 'Графит';
      case AppThemePreset.ocean:
        return 'Океан';
      case AppThemePreset.contrast:
        return 'Контрастная';
    }
  }

  String get description {
    switch (this) {
      case AppThemePreset.emerald:
        return 'Светлая Figma-тема с фирменным зеленым акцентом';
      case AppThemePreset.graphite:
        return 'Темная тема для работы вечером';
      case AppThemePreset.ocean:
        return 'Светлая синяя тема для спокойной аналитики';
      case AppThemePreset.contrast:
        return 'Больше контраста для чтения цифр и документов';
    }
  }

  IconData get icon {
    switch (this) {
      case AppThemePreset.emerald:
        return Icons.eco_rounded;
      case AppThemePreset.graphite:
        return Icons.dark_mode_rounded;
      case AppThemePreset.ocean:
        return Icons.water_drop_rounded;
      case AppThemePreset.contrast:
        return Icons.contrast_rounded;
    }
  }

  bool get isDark => this == AppThemePreset.graphite;

  AppThemeTokens get tokens {
    switch (this) {
      case AppThemePreset.emerald:
        return const AppThemeTokens(
          brightness: Brightness.light,
          background: Color(0xFFF8FAFC),
          foreground: Color(0xFF0F172A),
          card: Color(0xFFFFFFFF),
          cardForeground: Color(0xFF0F172A),
          primary: Color(0xFF00A86B),
          primaryHover: Color(0xFF008F5B),
          onPrimary: Color(0xFFFFFFFF),
          secondary: Color(0xFFF8FAFC),
          secondaryForeground: Color(0xFF1E293B),
          muted: Color(0xFFE2E8F0),
          mutedForeground: Color(0xFF64748B),
          accent: Color(0xFFF1F5F9),
          border: Color(0xFFE2E8F0),
          inputBackground: Color(0xFFF8FAFC),
          success: Color(0xFF22C55E),
          warning: Color(0xFFF59E0B),
          destructive: Color(0xFFEF4444),
          info: Color(0xFF3B82F6),
          chart1: Color(0xFF00A86B),
          chart2: Color(0xFF3B82F6),
          chart3: Color(0xFFF59E0B),
          chart4: Color(0xFF8B5CF6),
          chart5: Color(0xFFEC4899),
          navBackground: Color(0xFFFFFFFF),
          shadow: Color(0x160F172A),
        );
      case AppThemePreset.graphite:
        return const AppThemeTokens(
          brightness: Brightness.dark,
          background: Color(0xFF0F172A),
          foreground: Color(0xFFF8FAFC),
          card: Color(0xFF1E293B),
          cardForeground: Color(0xFFF8FAFC),
          primary: Color(0xFF00A86B),
          primaryHover: Color(0xFF00C278),
          onPrimary: Color(0xFFFFFFFF),
          secondary: Color(0xFF1E293B),
          secondaryForeground: Color(0xFFF8FAFC),
          muted: Color(0xFF334155),
          mutedForeground: Color(0xFF94A3B8),
          accent: Color(0xFF334155),
          border: Color(0xFF334155),
          inputBackground: Color(0xFF111827),
          success: Color(0xFF22C55E),
          warning: Color(0xFFF59E0B),
          destructive: Color(0xFFF87171),
          info: Color(0xFF60A5FA),
          chart1: Color(0xFF00A86B),
          chart2: Color(0xFF60A5FA),
          chart3: Color(0xFFFBBF24),
          chart4: Color(0xFFA78BFA),
          chart5: Color(0xFFF472B6),
          navBackground: Color(0xFF111827),
          shadow: Color(0x66000000),
        );
      case AppThemePreset.ocean:
        return const AppThemeTokens(
          brightness: Brightness.light,
          background: Color(0xFFF6FAFF),
          foreground: Color(0xFF102033),
          card: Color(0xFFFFFFFF),
          cardForeground: Color(0xFF102033),
          primary: Color(0xFF2563EB),
          primaryHover: Color(0xFF1D4ED8),
          onPrimary: Color(0xFFFFFFFF),
          secondary: Color(0xFFEFF6FF),
          secondaryForeground: Color(0xFF1E3A8A),
          muted: Color(0xFFDCEBFB),
          mutedForeground: Color(0xFF52677F),
          accent: Color(0xFFE0F2FE),
          border: Color(0xFFD7E3F3),
          inputBackground: Color(0xFFFFFFFF),
          success: Color(0xFF16A34A),
          warning: Color(0xFFD97706),
          destructive: Color(0xFFDC2626),
          info: Color(0xFF0284C7),
          chart1: Color(0xFF2563EB),
          chart2: Color(0xFF00A86B),
          chart3: Color(0xFFF59E0B),
          chart4: Color(0xFF7C3AED),
          chart5: Color(0xFFDB2777),
          navBackground: Color(0xFFFFFFFF),
          shadow: Color(0x181D4ED8),
        );
      case AppThemePreset.contrast:
        return const AppThemeTokens(
          brightness: Brightness.light,
          background: Color(0xFFFFFFFF),
          foreground: Color(0xFF020617),
          card: Color(0xFFFFFFFF),
          cardForeground: Color(0xFF020617),
          primary: Color(0xFF0F766E),
          primaryHover: Color(0xFF115E59),
          onPrimary: Color(0xFFFFFFFF),
          secondary: Color(0xFFF1F5F9),
          secondaryForeground: Color(0xFF0F172A),
          muted: Color(0xFFCBD5E1),
          mutedForeground: Color(0xFF334155),
          accent: Color(0xFFE2E8F0),
          border: Color(0xFFCBD5E1),
          inputBackground: Color(0xFFFFFFFF),
          success: Color(0xFF15803D),
          warning: Color(0xFFB45309),
          destructive: Color(0xFFB91C1C),
          info: Color(0xFF1D4ED8),
          chart1: Color(0xFF0F766E),
          chart2: Color(0xFF1D4ED8),
          chart3: Color(0xFFB45309),
          chart4: Color(0xFF6D28D9),
          chart5: Color(0xFFBE185D),
          navBackground: Color(0xFFFFFFFF),
          shadow: Color(0x1F020617),
        );
    }
  }

  ThemeData get themeData => AppTheme.build(this);

  static AppThemePreset fromStorageKey(String? value) {
    for (final preset in AppThemePreset.values) {
      if (preset.storageKey == value) {
        return preset;
      }
    }
    return AppThemePreset.emerald;
  }
}

@immutable
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  const AppThemeTokens({
    required this.brightness,
    required this.background,
    required this.foreground,
    required this.card,
    required this.cardForeground,
    required this.primary,
    required this.primaryHover,
    required this.onPrimary,
    required this.secondary,
    required this.secondaryForeground,
    required this.muted,
    required this.mutedForeground,
    required this.accent,
    required this.border,
    required this.inputBackground,
    required this.success,
    required this.warning,
    required this.destructive,
    required this.info,
    required this.chart1,
    required this.chart2,
    required this.chart3,
    required this.chart4,
    required this.chart5,
    required this.navBackground,
    required this.shadow,
  });

  final Brightness brightness;
  final Color background;
  final Color foreground;
  final Color card;
  final Color cardForeground;
  final Color primary;
  final Color primaryHover;
  final Color onPrimary;
  final Color secondary;
  final Color secondaryForeground;
  final Color muted;
  final Color mutedForeground;
  final Color accent;
  final Color border;
  final Color inputBackground;
  final Color success;
  final Color warning;
  final Color destructive;
  final Color info;
  final Color chart1;
  final Color chart2;
  final Color chart3;
  final Color chart4;
  final Color chart5;
  final Color navBackground;
  final Color shadow;

  LinearGradient get heroGradient => LinearGradient(
        colors: [primary, primaryHover],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  Color tone(Color color, [double alpha = 0.12]) =>
      color.withValues(alpha: alpha);

  @override
  AppThemeTokens copyWith({
    Brightness? brightness,
    Color? background,
    Color? foreground,
    Color? card,
    Color? cardForeground,
    Color? primary,
    Color? primaryHover,
    Color? onPrimary,
    Color? secondary,
    Color? secondaryForeground,
    Color? muted,
    Color? mutedForeground,
    Color? accent,
    Color? border,
    Color? inputBackground,
    Color? success,
    Color? warning,
    Color? destructive,
    Color? info,
    Color? chart1,
    Color? chart2,
    Color? chart3,
    Color? chart4,
    Color? chart5,
    Color? navBackground,
    Color? shadow,
  }) {
    return AppThemeTokens(
      brightness: brightness ?? this.brightness,
      background: background ?? this.background,
      foreground: foreground ?? this.foreground,
      card: card ?? this.card,
      cardForeground: cardForeground ?? this.cardForeground,
      primary: primary ?? this.primary,
      primaryHover: primaryHover ?? this.primaryHover,
      onPrimary: onPrimary ?? this.onPrimary,
      secondary: secondary ?? this.secondary,
      secondaryForeground: secondaryForeground ?? this.secondaryForeground,
      muted: muted ?? this.muted,
      mutedForeground: mutedForeground ?? this.mutedForeground,
      accent: accent ?? this.accent,
      border: border ?? this.border,
      inputBackground: inputBackground ?? this.inputBackground,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      destructive: destructive ?? this.destructive,
      info: info ?? this.info,
      chart1: chart1 ?? this.chart1,
      chart2: chart2 ?? this.chart2,
      chart3: chart3 ?? this.chart3,
      chart4: chart4 ?? this.chart4,
      chart5: chart5 ?? this.chart5,
      navBackground: navBackground ?? this.navBackground,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppThemeTokens lerp(ThemeExtension<AppThemeTokens>? other, double t) {
    if (other is! AppThemeTokens) {
      return this;
    }
    return AppThemeTokens(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: Color.lerp(background, other.background, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardForeground: Color.lerp(cardForeground, other.cardForeground, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryHover: Color.lerp(primaryHover, other.primaryHover, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      secondaryForeground:
          Color.lerp(secondaryForeground, other.secondaryForeground, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      mutedForeground: Color.lerp(mutedForeground, other.mutedForeground, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      border: Color.lerp(border, other.border, t)!,
      inputBackground: Color.lerp(inputBackground, other.inputBackground, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      destructive: Color.lerp(destructive, other.destructive, t)!,
      info: Color.lerp(info, other.info, t)!,
      chart1: Color.lerp(chart1, other.chart1, t)!,
      chart2: Color.lerp(chart2, other.chart2, t)!,
      chart3: Color.lerp(chart3, other.chart3, t)!,
      chart4: Color.lerp(chart4, other.chart4, t)!,
      chart5: Color.lerp(chart5, other.chart5, t)!,
      navBackground: Color.lerp(navBackground, other.navBackground, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension AppThemeTokensContext on BuildContext {
  AppThemeTokens get appThemeTokens {
    return Theme.of(this).extension<AppThemeTokens>() ??
        AppThemePreset.emerald.tokens;
  }
}

class AppTheme {
  const AppTheme._();

  static ThemeData build(AppThemePreset preset) {
    final tokens = preset.tokens;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: tokens.primary,
      brightness: tokens.brightness,
    ).copyWith(
      primary: tokens.primary,
      onPrimary: tokens.onPrimary,
      secondary: tokens.info,
      onSecondary: Colors.white,
      surface: tokens.card,
      onSurface: tokens.foreground,
      error: tokens.destructive,
      outline: tokens.border,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: tokens.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.background,
      fontFamily: 'SF Pro Display',
      extensions: [tokens],
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.background,
        foregroundColor: tokens.foreground,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.card,
        modalBackgroundColor: tokens.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      cardTheme: CardThemeData(
        color: tokens.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: tokens.border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: tokens.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.inputBackground,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: TextStyle(color: tokens.mutedForeground),
        hintStyle: TextStyle(color: tokens.mutedForeground),
        prefixIconColor: tokens.mutedForeground,
        suffixIconColor: tokens.mutedForeground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: tokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: tokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: tokens.primary, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: tokens.destructive),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: tokens.destructive, width: 1.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: preset.isDark ? tokens.muted : const Color(0xFF0F172A),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: tokens.primary,
        foregroundColor: tokens.onPrimary,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.primary,
          foregroundColor: tokens.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.foreground,
          side: BorderSide(color: tokens.border),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return tokens.primary;
          }
          return tokens.card;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return tokens.primary.withValues(alpha: 0.28);
          }
          return tokens.muted;
        }),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return tokens.primary;
          }
          return tokens.mutedForeground;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return tokens.primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(tokens.onPrimary),
        side: BorderSide(color: tokens.border, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: tokens.secondary,
        selectedColor: tokens.primary.withValues(alpha: 0.14),
        disabledColor: tokens.muted,
        labelStyle: TextStyle(color: tokens.foreground),
        secondaryLabelStyle: TextStyle(color: tokens.primary),
        side: BorderSide(color: tokens.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme
          .apply(
            bodyColor: tokens.foreground,
            displayColor: tokens.foreground,
            fontFamily: 'SF Pro Display',
          )
          .copyWith(
            headlineMedium: base.textTheme.headlineMedium?.copyWith(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
            titleLarge: base.textTheme.titleLarge?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
            titleMedium: base.textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
            bodyMedium: base.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              letterSpacing: 0,
            ),
            labelLarge: base.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
    );
  }
}
