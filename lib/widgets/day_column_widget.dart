import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_block.dart';
import '../providers/planner_provider.dart';
import '../theme/app_theme.dart';
import 'draggable_block.dart';
import 'drop_slot.dart';
import 'edit_dialog.dart';

class DayColumnWidget extends StatelessWidget {
  final DayColumn day;
  final double width;
  final bool isToday;

  const DayColumnWidget({
    super.key,
    required this.day,
    this.width = 230,
    this.isToday = false,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.read<PlannerProvider>();

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: isToday ? AppTokens.accentSoft : AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.rLg),
        border: Border.all(
          color: isToday ? AppTokens.accent : AppTokens.border,
          width: isToday ? 1.4 : 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context, provider),
          const SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (day.blocks.isEmpty)
                    EmptyDropZone(
                      targetType: 'day',
                      targetId: day.id,
                      hint: '블록 드래그 또는 + 추가',
                    )
                  else ...[
                    for (int i = 0; i < day.blocks.length; i++) ...[
                      DropSlot(
                        targetType: 'day',
                        targetId: day.id,
                        index: i,
                      ),
                      DraggableBlock(block: day.blocks[i]),
                    ],
                    DropSlot(
                      targetType: 'day',
                      targetId: day.id,
                      index: day.blocks.length,
                    ),
                  ],
                  const SizedBox(height: 6),
                  _addButton(context, provider),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, PlannerProvider provider) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _editDay(context, provider),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        day.dayLabel,
                        style: TextStyle(
                          color: isToday
                              ? AppTokens.accent
                              : AppTokens.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppTokens.accent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('오늘',
                            style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ],
                  ],
                ),
                if (day.subLabel.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    day.subLabel,
                    style: const TextStyle(
                        color: AppTokens.textFaint, fontSize: 10.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
        // 시간 정렬 버튼
        _miniIcon(
          Icons.sort_rounded,
          tooltip: '시간순 정렬',
          onTap: () => provider.sortDayByTime(day.id),
        ),
        _miniIcon(
          Icons.edit_outlined,
          tooltip: '요일 편집',
          onTap: () => _editDay(context, provider),
        ),
      ],
    );
  }

  Widget _miniIcon(IconData icon,
      {required VoidCallback onTap, String? tooltip}) {
    final btn = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 16, color: AppTokens.textFaint),
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip, child: btn) : btn;
  }

  Widget _addButton(BuildContext context, PlannerProvider provider) {
    return InkWell(
      onTap: () => provider.addBlockToDay(day.id),
      borderRadius: BorderRadius.circular(AppTokens.rSm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTokens.rSm),
          border: Border.all(color: AppTokens.border),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, size: 15, color: AppTokens.textSecondary),
            SizedBox(width: 4),
            Text('블록 추가',
                style:
                    TextStyle(fontSize: 12, color: AppTokens.textSecondary)),
          ],
        ),
      ),
    );
  }

  void _editDay(BuildContext context, PlannerProvider provider) {
    final labelCtrl = TextEditingController(text: day.dayLabel);
    final subCtrl = TextEditingController(text: day.subLabel);
    showMinimalEditDialog(
      context,
      title: '요일 편집',
      children: [
        minimalField(labelCtrl, '요일 / 제목'),
        const SizedBox(height: 12),
        minimalField(subCtrl, '메모 (부제)'),
      ],
      onSave: () {
        provider.updateDayLabel(
          day.id,
          dayLabel: labelCtrl.text.trim().isEmpty
              ? day.dayLabel
              : labelCtrl.text.trim(),
          subLabel: subCtrl.text.trim(),
        );
      },
    );
  }
}
