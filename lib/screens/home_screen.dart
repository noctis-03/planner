import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/planner_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/day_column_widget.dart';
import '../widgets/pool_section.dart';
import '../widgets/legend_bar.dart';
import '../widgets/edit_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver {
  bool _poolOpen = true;
  final ScrollController _boardCtrl = ScrollController();
  Timer? _purgeTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 앱이 켜져 있는 동안에도 주기적으로(1분마다) 만료된 일회용 블록 정리
    _purgeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) context.read<PlannerProvider>().purgeExpiredNow();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 포그라운드 복귀 시(다른 날이 되었을 수 있음) 즉시 정리
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<PlannerProvider>().purgeExpiredNow();
    }
  }

  @override
  void dispose() {
    _purgeTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _boardCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.bg,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              poolOpen: _poolOpen,
              onTogglePool: () => setState(() => _poolOpen = !_poolOpen),
            ),
            const Divider(height: 1, color: AppTokens.border),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 좌측 보관함 사이드바
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _poolOpen ? 300 : 0,
                    child: _poolOpen
                        ? Container(
                            decoration: const BoxDecoration(
                              color: AppTokens.surface,
                              border: Border(
                                right: BorderSide(color: AppTokens.border),
                              ),
                            ),
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                            child: const PoolSidebar(),
                          )
                        : const SizedBox.shrink(),
                  ),
                  // 우측 플래너 보드 (가로 슬라이드)
                  Expanded(
                    child: _PlannerBoard(controller: _boardCtrl),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- 상단 바 ----------------
class _TopBar extends StatelessWidget {
  final bool poolOpen;
  final VoidCallback onTogglePool;
  const _TopBar({required this.poolOpen, required this.onTogglePool});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<PlannerProvider>();
    return Container(
      color: AppTokens.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Tooltip(
            message: poolOpen ? '보관함 숨기기' : '보관함 보기',
            child: IconButton(
              onPressed: onTogglePool,
              icon: Icon(
                poolOpen ? Icons.menu_open_rounded : Icons.menu_rounded,
                color: AppTokens.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.calendar_view_week_rounded,
              color: AppTokens.accent, size: 22),
          const SizedBox(width: 8),
          const Text(
            '주간 일정 계획표',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTokens.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: LegendBar(),
            ),
          ),
          const SizedBox(width: 12),
          _Toolbar(provider: provider),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final PlannerProvider provider;
  const _Toolbar({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        ToolButton(
          icon: Icons.sort_rounded,
          label: '전체 정렬',
          onTap: () {
            provider.sortAllDaysByTime();
            _snack(context, '시간순으로 정렬했습니다');
          },
        ),
        ToolButton(
          icon: Icons.bookmarks_outlined,
          label: '프리셋',
          onTap: () => _showPresetSheet(context, provider),
        ),
        ToolButton(
          icon: Icons.refresh_rounded,
          label: '초기화',
          onTap: () => _confirmReset(context, provider),
        ),
      ],
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTokens.textPrimary,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _confirmReset(BuildContext context, PlannerProvider provider) {
    showMinimalEditDialog(
      context,
      title: '초기화',
      saveLabel: '초기화',
      children: const [
        Text('모든 일정을 삭제하고 초기 상태로 되돌릴까요?',
            style: TextStyle(color: AppTokens.textSecondary, fontSize: 14)),
      ],
      onSave: () => provider.resetAll(),
    );
  }

  void _showPresetSheet(BuildContext context, PlannerProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTokens.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PresetSheet(provider: provider),
    );
  }
}

// ---------------- 프리셋 시트 ----------------
class _PresetSheet extends StatelessWidget {
  final PlannerProvider provider;
  const _PresetSheet({required this.provider});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: provider,
      builder: (context, _) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.bookmarks_outlined,
                      size: 18, color: AppTokens.textSecondary),
                  const SizedBox(width: 8),
                  const Text('프리셋 관리',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ToolButton(
                icon: Icons.add_rounded,
                label: '현재 상태를 새 프리셋으로 저장',
                primary: true,
                onTap: () => _saveNewPreset(context),
              ),
              const SizedBox(height: 16),
              if (provider.presetNames.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('저장된 프리셋이 없습니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTokens.textFaint)),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: provider.presetNames.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final name = provider.presetNames[i];
                      return _presetTile(context, name);
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _presetTile(BuildContext context, String name) {
    return MinimalPanel(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      child: Row(
        children: [
          const Icon(Icons.bookmark_rounded,
              size: 16, color: AppTokens.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(context);
              final m = ScaffoldMessenger.of(context);
              await provider.loadPreset(name);
              nav.pop();
              m.showSnackBar(SnackBar(
                content: Text("'$name' 불러오기 완료"),
                behavior: SnackBarBehavior.floating,
              ));
            },
            child: const Text('불러오기'),
          ),
          Tooltip(
            message: '덮어쓰기',
            child: IconButton(
              onPressed: () async {
                final m = ScaffoldMessenger.of(context);
                await provider.savePreset(name);
                m.showSnackBar(SnackBar(
                  content: Text("'$name' 에 덮어썼습니다"),
                  behavior: SnackBarBehavior.floating,
                ));
              },
              icon: const Icon(Icons.save_rounded,
                  size: 18, color: AppTokens.textSecondary),
            ),
          ),
          IconButton(
            onPressed: () => provider.deletePreset(name),
            icon: const Icon(Icons.delete_outline_rounded,
                size: 18, color: AppTokens.danger),
          ),
        ],
      ),
    );
  }

  void _saveNewPreset(BuildContext context) {
    final ctrl = TextEditingController();
    showMinimalEditDialog(
      context,
      title: '프리셋 저장',
      children: [
        minimalField(ctrl, '프리셋 이름', hint: '예: 이번 주, 시험기간'),
      ],
      onSave: () async {
        final name = ctrl.text.trim();
        if (name.isEmpty) return;
        await provider.savePreset(name);
      },
    );
  }
}

// ---------------- 플래너 보드 (가로 슬라이드) ----------------
class _PlannerBoard extends StatelessWidget {
  final ScrollController controller;
  const _PlannerBoard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlannerProvider>();
    final todayIdx = DateTime.now().weekday - 1; // 월=0

    return LayoutBuilder(
      builder: (context, c) {
        // 화면이 충분히 넓으면 7일 균등, 아니면 고정폭 가로 슬라이드
        const gap = 10.0;
        const minColW = 220.0;
        final available = c.maxWidth - 28; // 좌우 패딩
        final equalW = (available - gap * 6) / 7;
        final useEqual = equalW >= minColW;
        final colW = useEqual ? equalW : minColW;

        final board = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < provider.days.length; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              DayColumnWidget(
                day: provider.days[i],
                width: colW,
                isToday: i == todayIdx,
              ),
            ],
          ],
        );

        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Scrollbar(
            controller: controller,
            thumbVisibility: !useEqual,
            child: SingleChildScrollView(
              controller: controller,
              scrollDirection: Axis.horizontal,
              physics: useEqual
                  ? const NeverScrollableScrollPhysics()
                  : const BouncingScrollPhysics(),
              child: SizedBox(
                width: useEqual ? available : null,
                child: board,
              ),
            ),
          ),
        );
      },
    );
  }
}
