import 'package:flutter/material.dart';

/// Brand colours: Toyota red for actions and deals, a muted yellow for headers and highlights.
class MintadealColors {
  const MintadealColors._();

  /// Toyota red. White text on it is readable (4.6:1), so it is used for buttons, badges and the cart bar.
  static const red = Color(0xFFEB0A1E);

  /// Darker red for pressed states and red text on light tints.
  static const deepRed = Color(0xFFB8000F);

  /// Muted yellow for the customer app header and selected states. Text on it is charcoal, never white.
  static const yellow = Color(0xFFF2CD5C);

  /// Pale yellow for tiles, chips and highlights.
  static const yellowSoft = Color(0xFFFFF5D6);

  /// Pale red for discount and savings highlights.
  static const redSoft = Color(0xFFFFE8EA);

  static const charcoal = Color(0xFF1F1F1F);

  /// Page background behind white cards.
  static const canvas = Color(0xFFF4F5F7);

  /// Background behind product images.
  static const imageWell = Color(0xFFF7F7F9);
}

ThemeData mintadealTheme({Brightness brightness = Brightness.light}) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: MintadealColors.red,
    brightness: brightness,
    primary: dark ? const Color(0xFFFF6B75) : MintadealColors.red,
    onPrimary: dark ? const Color(0xFF4A0007) : Colors.white,
    primaryContainer: dark ? const Color(0xFF5C0A12) : MintadealColors.redSoft,
    onPrimaryContainer: dark ? const Color(0xFFFFDADC) : MintadealColors.deepRed,
    secondary: dark ? const Color(0xFFE9C766) : const Color(0xFF7A5C00),
    onSecondary: dark ? const Color(0xFF3D2E00) : Colors.white,
    secondaryContainer: dark ? const Color(0xFF4A3B12) : MintadealColors.yellow,
    onSecondaryContainer: dark ? const Color(0xFFFFEFC2) : MintadealColors.charcoal,
    tertiaryContainer: dark ? const Color(0xFF3A3120) : MintadealColors.yellowSoft,
    onTertiaryContainer: dark ? const Color(0xFFFFEFC2) : MintadealColors.charcoal,
    surface: dark ? const Color(0xFF17171A) : Colors.white,
    surfaceContainerLowest: dark ? const Color(0xFF101012) : MintadealColors.canvas,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final text = base.textTheme.copyWith(
    headlineSmall: base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
    titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    titleSmall: base.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
  );
  final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: scheme.surfaceContainerLowest,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
      titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface, fontSize: 20),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: rounded,
        textStyle: text.labelLarge?.copyWith(fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 48),
        shape: rounded,
        foregroundColor: scheme.primary,
        side: BorderSide(color: scheme.primary),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: const StadiumBorder(),
      selectedColor: scheme.secondaryContainer,
      checkmarkColor: scheme.onSecondaryContainer,
      side: BorderSide(color: scheme.outlineVariant),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.secondaryContainer,
      elevation: 3,
      labelTextStyle: WidgetStateProperty.resolveWith((states) => text.labelSmall?.copyWith(
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
          )),
    ),
    navigationRailTheme: NavigationRailThemeData(indicatorColor: scheme.secondaryContainer),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark ? const Color(0xFF2A2A2E) : MintadealColors.charcoal,
      shape: rounded,
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.6)),
    badgeTheme: BadgeThemeData(backgroundColor: scheme.primary, textColor: scheme.onPrimary),
  );
}

/// The Mintadeal logo. On dark backgrounds it sits on a light tile so the charcoal cart stays visible.
class MintadealLogo extends StatelessWidget {
  const MintadealLogo({super.key, this.height = 48});

  final double height;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset('assets/logo.png', package: 'mintadeal_core', height: height,
        semanticLabel: 'Mintadeal');
    if (Theme.of(context).brightness == Brightness.light) return image;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: height * 0.2, vertical: height * 0.1),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(height * 0.2)),
      child: image,
    );
  }
}
