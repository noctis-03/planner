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
  bool _hoverCopy = false; // 현재 hover 중인 페이로드가 복사인지

  @override
  Widget build(BuildContext context) {
    return DragTarget<DragPayload>(
      onWillAcceptWithDetails: (details) {
        setState(() {
          _hovering = true;
          _hoverCopy = details.data.copy;
        });
        return true;
      },
      onLeave: (_) => setState(() {
        _hovering = false;
        _hoverCopy = false;
      }),
      onAcceptWithDetails: (details) {
        setState(() {
          _hovering = false;
          _hoverCopy = false;
        });
        final payload = details.data;
        final provider = context.read<PlannerProvider>();
        if (payload.copy) {
          provider.copyBlockTo(
            blockId: payload.blockId,
            targetType: widget.targetType,
            targetId: widget.targetId,
            targetIndex: widget.index,
          );
        } else {
          provider.moveBlock(
            blockId: payload.blockId,
            targetType: widget.targetType,
            targetId: widget.targetId,
            targetIndex: widget.index,
          );
        }
      },
      builder: (context, candidate, rejected) {
        final active = _hovering || candidate.isNotEmpty;
        final Color accentColor =
            _hoverCopy ? const Color(0xFF16A34A) : AppTokens.accent;
        final Color softColor = _hoverCopy
            ? const Color(0xFFE7F7EC)
            : AppTokens.accentSoft;

        if (widget.horizontal) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: active ? 6 : widget.thickness,
            height: 108,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color: active ? accentColor : Colors.transparent,
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: active ? 22 : widget.thickness,
          margin: const EdgeInsets.symmetric(vertical: 1),
          decoration: BoxDecoration(
            color: active ? softColor : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: active
                ? Border.all(color: accentColor, width: 1.4)
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
  bool _hoverCopy = false;

  @override
  Widget build(BuildContext context) {
    return DragTarget<DragPayload>(
      onWillAcceptWithDetails: (details) {
        setState(() {
          _hovering = true;
          _hoverCopy = details.data.copy;
        });
        return true;
      },
      onLeave: (_) => setState(() {
        _hovering = false;
        _hoverCopy = false;
      }),
      onAcceptWithDetails: (details) {
        setState(() {
          _hovering = false;
          _hoverCopy = false;
        });
        final payload = details.data;
        final provider = context.read<PlannerProvider>();
        if (payload.copy) {
          provider.copyBlockTo(
            blockId: payload.blockId,
            targetType: widget.targetType,
            targetId: widget.targetId,
            targetIndex: 0,
          );
        } else {
          provider.moveBlock(
            blockId: payload.blockId,
            targetType: widget.targetType,
            targetId: widget.targetId,
            targetIndex: 0,
          );
        }
      },
      builder: (context, candidate, rejected) {
        final active = _hovering || candidate.isNotEmpty;
        final Color accentColor =
            _hoverCopy ? const Color(0xFF16A34A) : AppTokens.accent;
        final Color softColor = _hoverCopy
            ? const Color(0xFFE7F7EC)
            : AppTokens.accentSoft;

        return Container(
          width: double.infinity,
          height: widget.horizontal ? 80 : 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? softColor : AppTokens.surfaceAlt,
            borderRadius: BorderRadius.circular(AppTokens.rSm),
            border: Border.all(
              color: active ? accentColor : AppTokens.border,
              width: active ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                active
                    ? (_hoverCopy
                        ? Icons.content_copy_rounded
                        : Icons.south_rounded)
                    : Icons.add_rounded,
                size: 15,
                color: active ? accentColor : AppTokens.textFaint,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  active
                      ? (_hoverCopy ? '여기에 복사' : '여기에 놓기')
                      : widget.hint,
                  style: TextStyle(
                    fontSize: 11,
                    color: active ? accentColor : AppTokens.textFaint,
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
