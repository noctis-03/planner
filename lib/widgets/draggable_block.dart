import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/task_block.dart';
import '../providers/planner_provider.dart';
import 'block_card.dart';
import 'drag_payload.dart';

/// 즉시 드래그 가능한 블록.
/// - 그냥 드래그: 이동
/// - Ctrl 키 누른 채 드래그: 복사
/// - 길게 누르면(long-press) 일회용 블록으로 토글.
class DraggableBlock extends StatefulWidget {
  final TaskBlock block;
  final double width;

  const DraggableBlock({
    super.key,
    required this.block,
    this.width = double.infinity,
  });

  @override
  State<DraggableBlock> createState() => _DraggableBlockState();
}

class _DraggableBlockState extends State<DraggableBlock> {
  bool _ctrlDown = false;

  bool _isCtrlPressed() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        // macOS 사용자를 위해 Meta 키도 복사로 인식
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<PlannerProvider>();
    final card = BlockCard(block: widget.block, width: widget.width);
    final feedbackWidth =
        widget.width == double.infinity ? 220.0 : widget.width;

    // 드래그 시작 시점의 Ctrl 상태를 담아 페이로드 생성
    final draggable = Draggable<DragPayload>(
      data: DragPayload(widget.block.id, copy: _ctrlDown),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: () {
        // 드래그 시작 시 현재 키보드 상태 재확인
        setState(() => _ctrlDown = _isCtrlPressed());
      },
      onDragEnd: (_) {
        setState(() => _ctrlDown = false);
      },
      feedback: Material(
        color: Colors.transparent,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Opacity(
              opacity: 0.92,
              child: SizedBox(
                width: feedbackWidth,
                child: BlockCard(
                  block: widget.block,
                  width: feedbackWidth,
                  interactive: false,
                  elevated: true,
                ),
              ),
            ),
            // Ctrl 누르면 "복사" 뱃지 표시
            if (_ctrlDown)
              Positioned(
                top: -6,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.content_copy_rounded,
                          size: 10, color: Colors.white),
                      SizedBox(width: 3),
                      Text('복사',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      childWhenDragging: _ctrlDown
          ? card // 복사 중엔 원본이 그대로 보이도록
          : Opacity(opacity: 0.3, child: card),
      child: card,
    );

    // long-press로 일회용 토글
    return GestureDetector(
      behavior: HitTestBehavior.deferToChild,
      onLongPress: () {
        final willBeOneTime = !widget.block.oneTime;
        provider.toggleOneTime(widget.block.id);
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
