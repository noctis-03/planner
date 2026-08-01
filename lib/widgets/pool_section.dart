import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_block.dart';
import '../providers/planner_provider.dart';
import '../theme/app_theme.dart';
import 'draggable_block.dart';
import 'drop_slot.dart';
import 'edit_dialog.dart';

/// 좌측 보관함 사이드 패널 (세로 배치)
class PoolSidebar extends StatelessWidget {
  const PoolSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlannerProvider>();
    final blockCount =
        provider.pools.fold<int>(0, (sum, r) => sum + r.blocks.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Row(
            children: [
              const Icon(Icons.inventory_2_outlined,
                  size: 17, color: AppTokens.textSecondary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '보관함',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppTokens.textPrimary,
                  ),
                ),
              ),
              Text(
                '$blockCount',
                style: const TextStyle(
                    fontSize: 12, color: AppTokens.textFaint),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: '카테고리 추가',
                child: InkWell(
                  onTap: () => provider.addPoolRow(),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(3),
                    child: Icon(Icons.add_rounded,
                        size: 18, color: AppTokens.accent),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              ...provider.pools.map((row) => _PoolRowWidget(row: row)),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}

class _PoolRowWidget extends StatelessWidget {
  final PoolRow row;

  const _PoolRowWidget({required this.row});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<PlannerProvider>();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTokens.surfaceAlt,
        borderRadius: BorderRadius.circular(AppTokens.rMd),
        border: Border.all(color: AppTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => _editTitle(context, provider),
                  child: Text(
                    row.title,
                    style: const TextStyle(
                      color: AppTokens.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              _iconBtn(Icons.sort_rounded, AppTokens.textFaint,
                  '시간순 정렬', () => provider.sortPoolByTime(row.id)),
              _iconBtn(Icons.add_rounded, AppTokens.accent, '블록 추가',
                  () => provider.addBlockToPool(row.id)),
              _iconBtn(Icons.delete_outline_rounded, AppTokens.danger,
                  '행 삭제', () => _confirmDelete(context, provider)),
            ],
          ),
          const SizedBox(height: 8),
          _rowItems(),
        ],
      ),
    );
  }

  Widget _rowItems() {
    if (row.blocks.isEmpty) {
      return EmptyDropZone(
        targetType: 'pool',
        targetId: row.id,
        hint: '여기에 블록을 놓으세요',
      );
    }
    // 세로 사이드바이므로 블록도 세로로 쌓음
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < row.blocks.length; i++) ...[
          DropSlot(targetType: 'pool', targetId: row.id, index: i),
          DraggableBlock(block: row.blocks[i]),
        ],
        DropSlot(
          targetType: 'pool',
          targetId: row.id,
          index: row.blocks.length,
        ),
      ],
    );
  }

  Widget _iconBtn(
      IconData icon, Color color, String tip, VoidCallback onTap) {
    return Tooltip(
      message: tip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  void _editTitle(BuildContext context, PlannerProvider provider) {
    final ctrl = TextEditingController(text: row.title);
    showMinimalEditDialog(
      context,
      title: '행 제목 편집',
      children: [minimalField(ctrl, '제목')],
      onSave: () => provider.updatePoolTitle(
        row.id,
        ctrl.text.trim().isEmpty ? row.title : ctrl.text.trim(),
      ),
    );
  }

  void _confirmDelete(BuildContext context, PlannerProvider provider) {
    final count = row.blocks.length;
    final msg =
        count > 0 ? '이 행에 $count개의 블록이 있습니다. 정말 삭제할까요?' : '이 행을 삭제할까요?';
    showMinimalEditDialog(
      context,
      title: '행 삭제',
      saveLabel: '삭제',
      children: [
        Text(msg,
            style: const TextStyle(
                color: AppTokens.textSecondary, fontSize: 14)),
      ],
      onSave: () => provider.deletePoolRow(row.id),
    );
  }
}
