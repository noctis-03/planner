import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_block.dart';
import '../providers/planner_provider.dart';
import 'block_card.dart';
import 'drag_payload.dart';

/// 즉시 드래그 가능한 블록.
/// 길게 누르면(long-press) 일회용 블록으로 토글.
class DraggableBlock extends StatelessWidget {
  final TaskBlock block;
  final double width;

  const DraggableBlock({
    super.key,
    required this.block,
    this.width = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<PlannerProvider>();
    final card = BlockCard(block: block, width: width);
    final feedbackWidth = width == double.infinity ? 220.0 : width;

    final draggable = Draggable<DragPayload>(
      data: DragPayload(block.id),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      // 데스크톱/웹에서 즉시 드래그 (딜레이 없음)
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.92,
          child: SizedBox(
            width: feedbackWidth,
            child: BlockCard(
              block: block,
              width: feedbackWidth,
              interactive: false,
              elevated: true,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: card),
      child: card,
    );

    // long-press로 일회용 토글. Draggable(pan)과 GestureDetector(longPress)는
    // 제스처 아레나에서 공존 가능 — 짧게 눌러 끌면 드래그, 길게 누르면 토글.
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onLongPress: () {
        final willBeOneTime = !block.oneTime;
        provider.toggleOneTime(block.id);
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(SnackBar(
          content: Text(willBeOneTime
              ? '일회용 블록으로 전환 · 해당 요일의 오늘이 지나면 자동 삭제됩니다'
              : '일반 블록으로 전환'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
      },
      child: draggable,
    );
  }
}
