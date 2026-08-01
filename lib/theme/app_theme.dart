import 'package:flutter/material.dart';

/// 미니멀 디자인 토큰
class AppTokens {
  // 색상
  static const Color bg = Color(0xFFF7F8FA); // 전체 배경 (아주 옅은 회색)
  static const Color surface = Color(0xFFFFFFFF); // 카드/패널 표면
  static const Color surfaceAlt = Color(0xFFF1F3F6); // 옅은 서브 표면
  static const Color border = Color(0xFFE3E7ED); // 경계선
  static const Color borderStrong = Color(0xFFCED4DC);
  static const Color textPrimary = Color(0xFF1F2430); // 진한 텍스트
  static const Color textSecondary = Color(0xFF6B7280); // 보조 텍스트
  static const Color textFaint = Color(0xFF9AA1AC); // 흐린 텍스트
  static const Color accent = Color(0xFF2563EB); // 주 포인트 (블루)
  static const Color accentSoft = Color(0xFFEAF1FF);
  static const Color danger = Color(0xFFEF4444);

  // 반경
  static const double rSm = 8;
  static const double rMd = 12;
  static const double rLg = 16;

  // 간격
  static const double gap = 12;
  static const double gapSm = 8;

  // 그림자 (아주 은은하게)
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
}

ThemeData buildMinimalTheme() {
  const seed = AppTokens.accent;
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    ).copyWith(
      surface: AppTokens.surface,
    ),
    scaffoldBackgroundColor: AppTokens.bg,
    fontFamily: 'Roboto',
  );

  return base.copyWith(
    dividerColor: AppTokens.border,
    cardTheme: const CardThemeData(
      color: AppTokens.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppTokens.textPrimary,
      displayColor: AppTokens.textPrimary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: AppTokens.surfaceAlt,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.rSm),
        borderSide: const BorderSide(color: AppTokens.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.rSm),
        borderSide: const BorderSide(color: AppTokens.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.rSm),
        borderSide: const BorderSide(color: AppTokens.accent, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTokens.accent,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.rSm),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
  );
}

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
    final fg = primary ? Colors.white : AppTokens.textSecondary;
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
