import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_block.dart';
import '../providers/planner_provider.dart';
import '../theme/app_theme.dart';
import 'draggable_block.dart';
import 'drop_slot.dart';
import 'edit_dialog.dart';

class DayColumnWidget extends StatefulWidget {
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
  State<DayColumnWidget> createState() => _DayColumnWidgetState();
}

class _DayColumnWidgetState extends State<DayColumnWidget> {
  final Map<String, GlobalKey> _blockKeys = {};
  final GlobalKey _viewportKey = GlobalKey();
  final ScrollController _vCtrl = ScrollController();
  int _lastAlignTick = 0;

  @override
  void initState() {
    super.initState();
    _vCtrl.addListener(_reportMatchedEdges);
  }

  @override
  void dispose() {
    _vCtrl.removeListener(_reportMatchedEdges);
    _vCtrl.dispose();
    try {
      final provider = context.read<PlannerProvider>();
      provider.updateBlockEdges(widget.day.id, null, null);
    } catch (_) {}
    super.dispose();
  }

  GlobalKey _keyFor(String blockId) =>
      _blockKeys.putIfAbsent(blockId, () => GlobalKey());

  String? _matchedIdOf(PlannerProvider provider) {
    for (final b in widget.day.blocks) {
      if (provider.hoverMatchedIds.contains(b.id)) return b.id;
    }
    return null;
  }

  /// 매칭 블록의 "좌측 중앙" / "우측 중앙" 글로벌 좌표를 provider에 등록.
  void _reportMatchedEdges() {
    if (!mounted) return;
    final provider = context.read<PlannerProvider>();
    final id = _matchedIdOf(provider);
    if (id == null) {
      provider.updateBlockEdges(widget.day.id, null, null);
      return;
    }
    final ctx = _blockKeys[id]?.currentContext;
    final rb = ctx?.findRenderObject() as RenderBox?;
    if (rb == null || !rb.attached) return;
    final topLeft = rb.localToGlobal(Offset.zero);
    final size = rb.size;
    final left = topLeft + Offset(0, size.height / 2);
    final right = topLeft + Offset(size.width, size.height / 2);
    provider.updateBlockEdges(widget.day.id, left, right);
  }

  void _maybeAlign(PlannerProvider provider) {
    if (provider.alignTick == _lastAlignTick) return;
    _lastAlignTick = provider.alignTick;

    final matchedId = _matchedIdOf(provider);
    if (matchedId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context
              .read<PlannerProvider>()
              .updateBlockEdges(widget.day.id, null, null);
        }
      });
      return;
    }

    // 모든 요일(클릭한 요일 포함)이 매칭 블록을 상단 근처로 정렬
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_vCtrl.hasClients) return;

      final blockCtx = _blockKeys[matchedId]?.currentContext;
      final viewportCtx = _viewportKey.currentContext;
      if (blockCtx == null || viewportCtx == null) return;

      final blockBox = blockCtx.findRenderObject() as RenderBox?;
      final viewportBox = viewportCtx.findRenderObject() as RenderBox?;
      if (blockBox == null || viewportBox == null) return;

      final blockTopInViewport =
          blockBox.localToGlobal(Offset.zero, ancestor: viewportBox).dy;
      final viewportHeight = viewportBox.size.height;
      final desiredTopInside = viewportHeight * 0.15;

      final target =
          (_vCtrl.offset + blockTopInViewport - desiredTopInside).clamp(
        _vCtrl.position.minScrollExtent,
        _vCtrl.position.maxScrollExtent,
      );

      _vCtrl
          .animateTo(
        target,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      )
          .whenComplete(() {
        if (mounted) _reportMatchedEdges();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlannerProvider>();
    _maybeAlign(provider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportMatchedEdges();
    });

    return Container(
      width: widget.width,
      decoration: BoxDecoration(
        color: widget.isToday ? AppTokens.accentSoft : AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.rLg),
        border: Border.all(
          color: widget.isToday ? AppTokens.accent : AppTokens.border,
          width: widget.isToday ? 1.4 : 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context, provider),
          const SizedBox(height: 10),
          Expanded(
            child: KeyedSubtree(
              key: _viewportKey,
              child: SingleChildScrollView(
                controller: _vCtrl,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.day.blocks.isEmpty)
                      EmptyDropZone(
                        targetType: 'day',
                        targetId: widget.day.id,
                        hint: '블록 드래그 또는 + 추가',
                      )
                    else ...[
                      for (int i = 0;
                          i < widget.day.blocks.length;
                          i++) ...[
                        DropSlot(
                          targetType: 'day',
                          targetId: widget.day.id,
                          index: i,
                        ),
                        KeyedSubtree(
                          key: _keyFor(widget.day.blocks[i].id),
                          child: DraggableBlock(
                            block: widget.day.blocks[i],
                            dayId: widget.day.id,
                          ),
                        ),
                      ],
                      DropSlot(
                        targetType: 'day',
                        targetId: widget.day.id,
                        index: widget.day.blocks.length,
                      ),
                    ],
                    const SizedBox(height: 6),
                    _addButton(context, provider),
                    const SizedBox(height: 4),
                  ],
                ),
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
                        widget.day.dayLabel,
                        style: TextStyle(
                          color: widget.isToday
                              ? AppTokens.accent
                              : AppTokens.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.isToday) ...[
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
                if (widget.day.subLabel.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    widget.day.subLabel,
                    style: const TextStyle(
                        color: AppTokens.textFaint, fontSize: 10.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
        _miniIcon(
          Icons.sort_rounded,
          tooltip: '시간순 정렬',
          onTap: () => provider.sortDayByTime(widget.day.id),
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
      onTap: () => provider.addBlockToDay(widget.day.id),
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
    final labelCtrl = TextEditingController(text: widget.day.dayLabel);
    final subCtrl = TextEditingController(text: widget.day.subLabel);
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
          widget.day.id,
          dayLabel: labelCtrl.text.trim().isEmpty
              ? widget.day.dayLabel
              : labelCtrl.text.trim(),
          subLabel: subCtrl.text.trim(),
        );
      },
    );
  }
}
