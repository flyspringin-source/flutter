import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accentSoft,
    required this.portfolioStart,
    required this.portfolioEnd,
  });

  static const accent = Color(0xFF3D8BFF);
  static const profit = Color(0xFF16C784);
  static const loss = Color(0xFFEA3943);
  static const gold = Color(0xFFF5C451);

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accentSoft;
  final Color portfolioStart;
  final Color portfolioEnd;

  static const dark = AppColors(
    background: Color(0xFF0B0F14),
    surface: Color(0xFF141A22),
    surfaceAlt: Color(0xFF1C2430),
    border: Color(0xFF2A3441),
    textPrimary: Color(0xFFF2F5F8),
    textSecondary: Color(0xFF8B98A8),
    textMuted: Color(0xFF5C6B7A),
    accentSoft: Color(0xFF1B3A66),
    portfolioStart: Color(0xFF1B3A66),
    portfolioEnd: Color(0xFF141A22),
  );

  static const light = AppColors(
    background: Color(0xFFF4F6F8),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEEF2F6),
    border: Color(0xFFD8E0E8),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF94A3B8),
    accentSoft: Color(0xFFE4EEFF),
    portfolioStart: Color(0xFFDCE9FF),
    portfolioEnd: Color(0xFFFFFFFF),
  );

  static AppColors of(BuildContext context) {
    return Theme.of(context).extension<AppColors>()!;
  }

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accentSoft,
    Color? portfolioStart,
    Color? portfolioEnd,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      accentSoft: accentSoft ?? this.accentSoft,
      portfolioStart: portfolioStart ?? this.portfolioStart,
      portfolioEnd: portfolioEnd ?? this.portfolioEnd,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) {
      return this;
    }
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      portfolioStart: Color.lerp(portfolioStart, other.portfolioStart, t)!,
      portfolioEnd: Color.lerp(portfolioEnd, other.portfolioEnd, t)!,
    );
  }
}

class AppTheme {
  static ThemeData light() => _build(Brightness.light, AppColors.light);

  static ThemeData dark() => _build(Brightness.dark, AppColors.dark);

  static ThemeData _build(Brightness brightness, AppColors colors) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: AppColors.accent,
      onPrimary: Colors.white,
      secondary: AppColors.gold,
      onSecondary: const Color(0xFF111827),
      error: AppColors.loss,
      onError: Colors.white,
      surface: colors.surface,
      onSurface: colors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.background,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      dividerColor: colors.border,
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: colors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
        bodyMedium: TextStyle(color: colors.textPrimary),
        bodySmall: TextStyle(color: colors.textSecondary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.surface,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: colors.textMuted,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
      ),
    );
  }
}

String formatPrice(double value, {int decimals = 2}) {
  final fixed = value.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final whole = parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    final remaining = whole.length - i;
    if (i != 0 && remaining % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(whole[i]);
  }
  if (parts.length > 1) {
    buffer.write('.');
    buffer.write(parts[1]);
  }
  return buffer.toString();
}

String formatMaybe(double? value, {int decimals = 2}) {
  if (value == null || value <= 0) {
    return '--';
  }
  return formatPrice(value, decimals: decimals);
}

String formatSigned(double value, {int decimals = 2}) {
  final sign = value > 0 ? '+' : '';
  return '$sign${formatPrice(value, decimals: decimals)}';
}

String formatRupee(double? value, {int decimals = 2}) {
  if (value == null) {
    return '--';
  }
  return '₹${formatPrice(value, decimals: decimals)}';
}

String formatSignedRupee(double value, {int decimals = 2}) {
  final sign = value > 0 ? '+' : (value < 0 ? '-' : '');
  return '$sign₹${formatPrice(value.abs(), decimals: decimals)}';
}

String formatCompactSigned(double value) {
  if (value == 0) {
    return '--';
  }
  final body = formatCompactQty(value.abs());
  return value > 0 ? '+$body' : '-$body';
}

String formatCompactQty(double? value) {
  if (value == null || value <= 0) {
    return '--';
  }
  if (value >= 10000000) {
    return '${(value / 10000000).toStringAsFixed(2)}Cr';
  }
  if (value >= 100000) {
    return '${(value / 100000).toStringAsFixed(2)}L';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  return value.round().toString();
}
