import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/task_block.dart';
import '../providers/planner_provider.dart';
import 'block_card.dart';
import 'drag_payload.dart';

/// 즉시 드래그 가능한 블록.
/// - 짧게 탭: onTap 콜백 (부모가 지정)
/// - 드래그: 이동 / Ctrl+드래그: 복사
/// - 길게 누르기: 일회용 블록으로 토글
class DraggableBlock extends StatefulWidget {
  final TaskBlock block;
  final double width;

  /// 이 블록이 속한 요일 id (요일 컬럼에서 렌더될 때만 지정).
  /// 클릭 정렬 시 자기 요일 컬럼을 스크롤하지 않기 위해 BlockCard로 전달됨.
  final String? dayId;

  const DraggableBlock({
    super.key,
    required this.block,
    this.width = double.infinity,
    this.dayId,
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
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<PlannerProvider>();
    final feedbackWidth =
        widget.width == double.infinity ? 220.0 : widget.width;

    // 실제 카드 (탭/더블탭 이벤트도 여기서 처리)
    final card = BlockCard(
      block: widget.block,
      width: widget.width,
      dayId: widget.dayId,
    );

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        final ctrl = _isCtrlPressed();
        if (ctrl != _ctrlDown) {
          setState(() => _ctrlDown = ctrl);
        }
      },
      child: GestureDetector(
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
        child: Draggable<DragPayload>(
          data: DragPayload(widget.block.id, copy: _ctrlDown),
          dragAnchorStrategy: pointerDragAnchorStrategy,
          onDragEnd: (_) {
            if (_ctrlDown) setState(() => _ctrlDown = false);
          },
          onDraggableCanceled: (_, __) {
            if (_ctrlDown) setState(() => _ctrlDown = false);
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
                if (_ctrlDown)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A),
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
          childWhenDragging:
              _ctrlDown ? card : Opacity(opacity: 0.3, child: card),
          child: card,
        ),
      ),
    );
  }
}
