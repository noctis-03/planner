import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/planner_provider.dart';
import '../theme/app_theme.dart';
import 'drag_payload.dart';

/// 블록 사이 / 컨테이너 끝에 위치하는 드롭 슬롯 (미니멀)
class DropSlot extends StatefulWidget {
  final String targetType; // 'day' | 'pool'
  final String targetId;
  final int index;
  final bool horizontal;
  final double thickness;

  const DropSlot({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.index,
    this.horizontal = false,
    this.thickness = 6,
  });

  @override
  State<DropSlot> createState() => _DropSlotState();
}

class _DropSlotState extends State<DropSlot> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return DragTarget<DragPayload>(
      onWillAcceptWithDetails: (_) {
        setState(() => _hovering = true);
        return true;
      },
      onLeave: (_) => setState(() => _hovering = false),
      onAcceptWithDetails: (details) {
        setState(() => _hovering = false);
        context.read<PlannerProvider>().moveBlock(
              blockId: details.data.blockId,
              targetType: widget.targetType,
              targetId: widget.targetId,
              targetIndex: widget.index,
            );
      },
      builder: (context, candidate, rejected) {
        final active = _hovering || candidate.isNotEmpty;
        if (widget.horizontal) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: active ? 6 : widget.thickness,
            height: 108,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: active ? AppTokens.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: active ? 22 : widget.thickness,
          margin: const EdgeInsets.symmetric(vertical: 1),
          decoration: BoxDecoration(
            color: active ? AppTokens.accentSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: active
                ? Border.all(color: AppTokens.accent, width: 1.4)
                : null,
          ),
        );
      },
    );
  }
}

/// 컨테이너가 비었을 때 표시되는 큰 드롭 영역
class EmptyDropZone extends StatefulWidget {
  final String targetType;
  final String targetId;
  final String hint;
  final bool horizontal;

  const EmptyDropZone({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.hint,
    this.horizontal = false,
  });

  @override
  State<EmptyDropZone> createState() => _EmptyDropZoneState();
}

class _EmptyDropZoneState extends State<EmptyDropZone> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return DragTarget<DragPayload>(
      onWillAcceptWithDetails: (_) {
        setState(() => _hovering = true);
        return true;
      },
      onLeave: (_) => setState(() => _hovering = false),
      onAcceptWithDetails: (details) {
        setState(() => _hovering = false);
        context.read<PlannerProvider>().moveBlock(
              blockId: details.data.blockId,
              targetType: widget.targetType,
              targetId: widget.targetId,
              targetIndex: 0,
            );
      },
      builder: (context, candidate, rejected) {
        final active = _hovering || candidate.isNotEmpty;
        return Container(
          width: double.infinity,
          height: widget.horizontal ? 80 : 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppTokens.accentSoft : AppTokens.surfaceAlt,
            borderRadius: BorderRadius.circular(AppTokens.rSm),
            border: Border.all(
              color: active ? AppTokens.accent : AppTokens.border,
              width: active ? 1.4 : 1,
              // ignore: deprecated_member_use
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                active ? Icons.south_rounded : Icons.add_rounded,
                size: 15,
                color: active ? AppTokens.accent : AppTokens.textFaint,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  active ? '여기에 놓기' : widget.hint,
                  style: TextStyle(
                    fontSize: 11,
                    color: active ? AppTokens.accent : AppTokens.textFaint,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
