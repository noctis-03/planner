import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_block.dart';
import '../models/category.dart';
import '../providers/planner_provider.dart';
import '../theme/app_theme.dart';
import '../screens/canvas_screen.dart';
import 'block_edit_dialog.dart';

class BlockCard extends StatelessWidget {
  final TaskBlock block;
  final double width;
  final bool interactive;
  final bool elevated;

  const BlockCard({
    super.key,
    required this.block,
    this.width = double.infinity,
    this.interactive = true,
    this.elevated = false,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<PlannerProvider>();
    final cat = categoryById(block.categoryId);
    final hasTime = block.time.trim().isNotEmpty;
    final done = block.completed;

    // 완료 상태 색상 (회색 톤)
    const Color mutedText = Color(0xFF9AA1AC);
    const Color mutedBorder = Color(0xFFD8DCE3);

    // 왼쪽 카테고리 액센트 바 두께
    const double accentWidth = 4.0;

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(11, 9, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (hasTime)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: done ? const Color(0xFFEEF0F3) : cat.tint,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    block.time,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: done ? mutedText : cat.color,
                      decoration:
                          done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                )
              else
                Text(
                  '시간 미정',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: done ? mutedText : AppTokens.textFaint,
                  ),
                ),
              if (block.oneTime) ...[
                const SizedBox(width: 6),
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
              ],
              // 완료 체크 배지
              if (done) ...[
                const SizedBox(width: 6),
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
              ],
              const Spacer(),
              if (block.hasCanvas)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.hub_outlined,
                      size: 13,
                      color: done ? mutedText : AppTokens.textFaint),
                ),
              if (interactive)
                Tooltip(
                  message: block.oneTime
                      ? '삭제'
                      : (done ? '삭제' : '완료 표시 (다시 누르면 삭제)'),
                  child: GestureDetector(
                    onTap: () =>
                        provider.toggleCompleteOrDelete(block.id),
                    child: Icon(
                      done ? Icons.close_rounded : Icons.close_rounded,
                      size: 15,
                      color: done
                          ? const Color(0xFFDC2626)
                          : AppTokens.textFaint,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            block.title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: done ? mutedText : AppTokens.textPrimary,
              height: 1.25,
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
                fontSize: 11,
                color: done ? mutedText : AppTokens.textSecondary,
                height: 1.3,
                decoration: done ? TextDecoration.lineThrough : null,
                decorationColor: mutedText,
              ),
            ),
          ],
          const SizedBox(height: 7),
          GestureDetector(
            onTap:
                interactive ? () => provider.cycleCategory(block.id) : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: done ? mutedText : cat.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  cat.label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: done ? mutedText : AppTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // 카드 스타일 결정
    Widget card;
    if (block.oneTime) {
      // 일회용 블록: 점선 테두리
      card = Container(
        width: width,
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
              color: done ? const Color(0xFFF6F7F9) : AppTokens.surface,
              borderRadius: BorderRadius.circular(AppTokens.rMd),
            ),
            child: content,
          ),
        ),
      );
    } else {
      // 일반 블록: 균일한 테두리 + 왼쪽 카테고리 액센트 바 (Row 구조)
      card = Container(
        width: width,
        margin: const EdgeInsets.only(bottom: 2),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: done ? const Color(0xFFF6F7F9) : AppTokens.surface,
          borderRadius: BorderRadius.circular(AppTokens.rMd),
          border: Border.all(
            color: done ? mutedBorder : AppTokens.border,
            width: 1,
          ),
          boxShadow:
              elevated ? AppTokens.softShadow : AppTokens.cardShadow,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: accentWidth,
                color: done ? mutedBorder : cat.color,
              ),
              Expanded(child: content),
            ],
          ),
        ),
      );
    }

    // 완료 상태에선 전체를 살짝 투명하게
    if (done) {
      card = Opacity(opacity: 0.75, child: card);
    }

    if (!interactive) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.rMd),
        onTap: () async {
          final result = await showBlockEditDialog(context, block);
          if (result != null) {
            provider.updateBlockField(
              block.id,
              time: result.time,
              title: result.title,
              desc: result.desc,
            );
            provider.setCategory(block.id, result.categoryId);
          }
        },
        onDoubleTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CanvasScreen(blockId: block.id),
            ),
          );
        },
        child: card,
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
