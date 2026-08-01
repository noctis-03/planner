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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: cat.tint,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    block.time,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cat.color,
                    ),
                  ),
                )
              else
                Text(
                  '시간 미정',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppTokens.textFaint,
                  ),
                ),
              if (block.oneTime) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
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
              const Spacer(),
              if (block.hasCanvas)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(Icons.hub_outlined,
                      size: 13, color: AppTokens.textFaint),
                ),
              if (interactive)
                GestureDetector(
                  onTap: () => provider.deleteBlock(block.id),
                  child: const Icon(Icons.close_rounded,
                      size: 15, color: AppTokens.textFaint),
                ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            block.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTokens.textPrimary,
              height: 1.25,
            ),
          ),
          if (block.desc.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              block.desc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppTokens.textSecondary,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 7),
          GestureDetector(
            onTap: interactive ? () => provider.cycleCategory(block.id) : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: cat.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  cat.label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppTokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // 일반 블록: 실선 + 왼쪽 카테고리 액센트 바
    // 일회용 블록: 점선 테두리(카테고리색) + 살짝 투명한 배경
    final Widget card = block.oneTime
        ? Container(
            width: width,
            margin: const EdgeInsets.only(bottom: 2),
            child: CustomPaint(
              painter: _DashedBorderPainter(
                color: cat.color,
                radius: AppTokens.rMd,
                strokeWidth: 1.6,
                dash: 5,
                gap: 3.5,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTokens.surface,
                  borderRadius: BorderRadius.circular(AppTokens.rMd),
                ),
                child: content,
              ),
            ),
          )
        : Container(
            width: width,
            margin: const EdgeInsets.only(bottom: 2),
            decoration: BoxDecoration(
              color: AppTokens.surface,
              borderRadius: BorderRadius.circular(AppTokens.rMd),
              border: Border(
                top: const BorderSide(color: AppTokens.border),
                right: const BorderSide(color: AppTokens.border),
                bottom: const BorderSide(color: AppTokens.border),
                left: BorderSide(color: cat.color, width: 3.5),
              ),
              boxShadow: elevated ? AppTokens.softShadow : AppTokens.cardShadow,
            ),
            child: content,
          );

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
