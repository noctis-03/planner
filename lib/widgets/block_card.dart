import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_block.dart';
import '../models/category.dart';
import '../providers/planner_provider.dart';
import '../theme/app_theme.dart';
import '../screens/canvas_screen.dart';
import 'block_edit_dialog.dart';

class BlockCard extends StatefulWidget {
  final TaskBlock block;
  final double width;
  final bool interactive;
  final bool elevated;

  /// 이 블록이 속한 요일 id (요일 컬럼에서 렌더될 때만 지정).
  /// 클릭 정렬 시 자기 요일 컬럼을 스크롤하지 않기 위해 사용됨.
  final String? dayId;

  const BlockCard({
    super.key,
    required this.block,
    this.width = double.infinity,
    this.interactive = true,
    this.elevated = false,
    this.dayId,
  });

  @override
  State<BlockCard> createState() => _BlockCardState();
}

class _BlockCardState extends State<BlockCard> {
  bool _hover = false;

  Future<void> _openEditDialog() async {
    final provider = context.read<PlannerProvider>();
    final result = await showBlockEditDialog(context, widget.block);
    if (result != null) {
      provider.updateBlockField(
        widget.block.id,
        time: result.time,
        title: result.title,
        desc: result.desc,
      );
      provider.setCategory(widget.block.id, result.categoryId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<PlannerProvider>();
    final block = widget.block;
    final cat = categoryById(block.categoryId);
    final hasTime = block.time.trim().isNotEmpty;
    final done = block.completed;

    const Color mutedText = Color(0xFF9AA1AC);
    const Color mutedBg = Color(0xFFF1F3F6);
    const Color mutedBorder = Color(0xFFD8DCE3);

    final Color catColor = done ? mutedText : cat.color;
    final Color cardBg = done ? mutedBg : cat.tint;

    final bool timeMatch = context.select<PlannerProvider, bool>(
      (p) =>
          widget.interactive &&
          hasTime &&
          p.hoverMinutes != null &&
          p.hoverMatchedIds.contains(block.id),
    );

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: widget.interactive
                    ? () => provider.cycleCategory(block.id)
                    : null,
                child: Text(
                  cat.label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: catColor.withValues(alpha: 0.85),
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              const Spacer(),
              if (block.oneTime) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDE8E8),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.timelapse_rounded,
                          size: 10, color: Color(0xFFDC2626)),
                      SizedBox(width: 3),
                      Text('일회용',
                          style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFDC2626))),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
              ],
              if (done) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDFF5E4),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.check_rounded,
                          size: 11, color: Color(0xFF16A34A)),
                      SizedBox(width: 2),
                      Text('완료',
                          style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF16A34A))),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
              ],
              if (block.hasCanvas)
                Icon(Icons.hub_outlined,
                    size: 13, color: done ? mutedText : catColor),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            hasTime ? block.time : '시간 미정',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: hasTime ? catColor : mutedText,
              decoration:
                  (done && hasTime) ? TextDecoration.lineThrough : null,
              decorationColor: mutedText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            block.title,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: done ? mutedText : AppTokens.textPrimary,
              height: 1.3,
              decoration: done ? TextDecoration.lineThrough : null,
              decorationColor: mutedText,
              decorationThickness: 1.5,
            ),
          ),
          if (block.desc.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              block.desc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: done ? mutedText : AppTokens.textSecondary,
                height: 1.35,
                decoration: done ? TextDecoration.lineThrough : null,
                decorationColor: mutedText,
              ),
            ),
          ],
        ],
      ),
    );

    Widget card;
    if (block.oneTime) {
      card = Container(
        width: widget.width,
        margin: const EdgeInsets.only(bottom: 2),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: done ? mutedBorder : cat.color,
            radius: AppTokens.rMd,
            strokeWidth: 1.6,
            dash: 5,
            gap: 3.5,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(AppTokens.rMd),
            ),
            child: content,
          ),
        ),
      );
    } else {
      card = AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: widget.width,
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(AppTokens.rMd),
          border: Border.all(
            color: timeMatch
                ? cat.color.withValues(alpha: 0.9)
                : (done
                    ? mutedBorder
                    : cat.color.withValues(alpha: 0.18)),
            width: timeMatch ? 1.8 : 1,
          ),
          boxShadow: timeMatch
              ? [
                  BoxShadow(
                    color: cat.color.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : (widget.elevated
                  ? AppTokens.softShadow
                  : const [
                      BoxShadow(
                        color: Color(0x08000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ]),
        ),
        child: content,
      );
    }

    if (done) {
      card = Opacity(opacity: 0.78, child: card);
    }

    final Widget withHoverAction = Stack(
      children: [
        card,
        if (widget.interactive)
          Positioned(
            top: 6,
            right: 6,
            child: AnimatedOpacity(
              opacity: _hover ? 1 : 0,
              duration: const Duration(milliseconds: 120),
              child: IgnorePointer(
                ignoring: !_hover,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _circleActionBtn(
                      icon: Icons.edit_outlined,
                      tooltip: '일정 수정',
                      iconColor: AppTokens.textSecondary,
                      onTap: _openEditDialog,
                    ),
                    const SizedBox(width: 4),
                    _circleActionBtn(
                      icon: done
                          ? Icons.close_rounded
                          : Icons.check_rounded,
                      tooltip: block.oneTime
                          ? '삭제'
                          : (done ? '삭제' : '완료 표시 (다시 누르면 삭제)'),
                      iconColor: done
                          ? const Color(0xFFDC2626)
                          : AppTokens.textSecondary,
                      onTap: () =>
                          provider.toggleCompleteOrDelete(block.id),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );

    if (!widget.interactive) return card;

    return MouseRegion(
      onEnter: (_) {
        setState(() => _hover = true);
        if (hasTime) provider.setHoverMinutes(block.minutes);
      },
      onExit: (_) {
        setState(() => _hover = false);
        provider.setHoverMinutes(null);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // 카드 본체 클릭 → 다른 요일 컬럼들을 이 시간 기준으로 정렬
        // (자기 요일은 originDayId로 제외)
        onTap: hasTime
            ? () => provider.requestAlignByMinutes(
                  block.minutes,
                  originDayId: widget.dayId,
                )
            : null,
        onDoubleTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CanvasScreen(blockId: block.id),
            ),
          );
        },
        child: withHoverAction,
      ),
    );
  }

  Widget _circleActionBtn({
    required IconData icon,
    required String tooltip,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: AppTokens.border,
                width: 1,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
        ),
      ),
    );
  }
}

/// 점선 둥근 테두리 페인터 (일회용 블록용)
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;
  final double dash;
  final double gap;

  _DashedBorderPainter({
    required this.color,
    required this.radius,
    this.strokeWidth = 1.5,
    this.dash = 5,
    this.gap = 3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      double dist = 0;
      while (dist < metric.length) {
        final len = math.min(dash, metric.length - dist);
        canvas.drawPath(metric.extractPath(dist, dist + len), paint);
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.dash != dash ||
      old.gap != gap;
}
