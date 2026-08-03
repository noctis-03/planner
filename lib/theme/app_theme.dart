import 'package:flutter/material.dart';

/// 테마 모드
enum AppThemeMode { light, dark }

/// 전역 테마 컨트롤러 — 앱 어디서든 구독/변경 가능.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  AppThemeMode _mode = AppThemeMode.light;
  AppThemeMode get mode => _mode;
  bool get isDark => _mode == AppThemeMode.dark;

  void setMode(AppThemeMode m) {
    if (_mode == m) return;
    _mode = m;
    AppTokens._applyMode(m);
    notifyListeners();
  }

  void toggle() {
    setMode(isDark ? AppThemeMode.light : AppThemeMode.dark);
  }
}

/// 미니멀 디자인 토큰 — 라이트/다크 전환 시 값이 바뀐다.
/// 기존 코드가 `AppTokens.bg` 처럼 static 접근하던 부분과 호환.
class AppTokens {
  // 색상 (초기값: 라이트 팔레트)
  static Color bg = const Color(0xFFF7F8FA);
  static Color surface = const Color(0xFFFFFFFF);
  static Color surfaceAlt = const Color(0xFFF1F3F6);
  static Color border = const Color(0xFFE3E7ED);
  static Color borderStrong = const Color(0xFFCED4DC);
  static Color textPrimary = const Color(0xFF1F2430);
  static Color textSecondary = const Color(0xFF6B7280);
  static Color textFaint = const Color(0xFF9AA1AC);
  static Color accent = const Color(0xFF8FB3E8);
  static Color accentSoft = const Color(0xFFEEF4FC);
  static Color danger = const Color(0xFFEF9A9A);

  // 반경
  static const double rSm = 8;
  static const double rMd = 12;
  static const double rLg = 16;

  // 간격
  static const double gap = 12;
  static const double gapSm = 8;

  // 그림자 (라이트 기본)
  static List<BoxShadow> softShadow = const [
    BoxShadow(
      color: Color(0x0F1F2430),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static List<BoxShadow> cardShadow = const [
    BoxShadow(
      color: Color(0x0A1F2430),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  static void _applyMode(AppThemeMode mode) {
    if (mode == AppThemeMode.dark) {
      bg = const Color(0xFF14161B);
      surface = const Color(0xFF1C1F26);
      surfaceAlt = const Color(0xFF23262E);
      border = const Color(0xFF2E323B);
      borderStrong = const Color(0xFF3B4048);
      textPrimary = const Color(0xFFE7EAF0);
      textSecondary = const Color(0xFFA6ADBB);
      textFaint = const Color(0xFF6E7683);
      accent = const Color(0xFF7FA6DE);
      accentSoft = const Color(0xFF23303F);
      danger = const Color(0xFFE07A7A);

      softShadow = const [
        BoxShadow(
          color: Color(0x66000000),
          blurRadius: 14,
          offset: Offset(0, 4),
        ),
      ];
      cardShadow = const [
        BoxShadow(
          color: Color(0x40000000),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ];
    } else {
      bg = const Color(0xFFF7F8FA);
      surface = const Color(0xFFFFFFFF);
      surfaceAlt = const Color(0xFFF1F3F6);
      border = const Color(0xFFE3E7ED);
      borderStrong = const Color(0xFFCED4DC);
      textPrimary = const Color(0xFF1F2430);
      textSecondary = const Color(0xFF6B7280);
      textFaint = const Color(0xFF9AA1AC);
      accent = const Color(0xFF8FB3E8);
      accentSoft = const Color(0xFFEEF4FC);
      danger = const Color(0xFFEF9A9A);

      softShadow = const [
        BoxShadow(
          color: Color(0x0F1F2430),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ];
      cardShadow = const [
        BoxShadow(
          color: Color(0x0A1F2430),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ];
    }
  }
}

ThemeData buildAppTheme({required bool dark}) {
  final seed = AppTokens.accent;
  final base = ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: dark ? Brightness.dark : Brightness.light,
    ).copyWith(
      surface: AppTokens.surface,
    ),
    scaffoldBackgroundColor: AppTokens.bg,
    fontFamily: 'Roboto',
  );

  return base.copyWith(
    dividerColor: AppTokens.border,
    cardTheme: CardThemeData(
      color: AppTokens.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppTokens.textPrimary,
      displayColor: AppTokens.textPrimary,
    ),
    iconTheme: IconThemeData(color: AppTokens.textSecondary),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: AppTokens.surfaceAlt,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      labelStyle: TextStyle(color: AppTokens.textSecondary),
      hintStyle: TextStyle(color: AppTokens.textFaint),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.rSm),
        borderSide: BorderSide(color: AppTokens.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.rSm),
        borderSide: BorderSide(color: AppTokens.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.rSm),
        borderSide: BorderSide(color: AppTokens.accent, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTokens.accent,
        foregroundColor: dark ? const Color(0xFF14161B) : Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.rSm),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    dialogTheme: DialogThemeData(backgroundColor: AppTokens.surface),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: AppTokens.surface),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: dark ? const Color(0xFF2A2E37) : AppTokens.textPrimary,
      contentTextStyle: TextStyle(
        color: dark ? AppTokens.textPrimary : Colors.white,
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// 하위호환용 별칭 (기존 코드에서 buildMinimalTheme 호출하는 곳 대응)
ThemeData buildMinimalTheme() => buildAppTheme(dark: false);

/// 재사용 가능한 미니멀 카드/패널 컨테이너
class MinimalPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final double radius;
  final bool shadow;
  final Color? borderColor;

  const MinimalPanel({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.radius = AppTokens.rMd,
    this.shadow = false,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppTokens.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? AppTokens.border),
        boxShadow: shadow ? AppTokens.cardShadow : null,
      ),
      child: child,
    );
  }
}

/// 미니멀 아이콘 텍스트 버튼 (툴바용)
class ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  const ToolButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = primary
        ? (ThemeController.instance.isDark
            ? const Color(0xFF14161B)
            : Colors.white)
        : AppTokens.textSecondary;
    final bg = primary ? AppTokens.accent : AppTokens.surface;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppTokens.rSm),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.rSm),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.rSm),
            border: Border.all(
              color: primary ? AppTokens.accent : AppTokens.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
