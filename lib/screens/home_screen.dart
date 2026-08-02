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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _poolOpen = true;
  final ScrollController _boardCtrl = ScrollController();
  Timer? _purgeTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _purgeTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) context.read<PlannerProvider>().purgeExpiredNow();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
                  LayoutBuilder(
                    builder: (context, c) {
                      final screenW = MediaQuery.of(context).size.width;
                      final sidebarW =
                          (screenW * 0.20).clamp(200.0, 300.0);
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: _poolOpen ? sidebarW : 0,
                        child: _poolOpen
                            ? Container(
                                decoration: const BoxDecoration(
                                  color: AppTokens.surface,
                                  border: Border(
                                    right:
                                        BorderSide(color: AppTokens.border),
                                  ),
                                ),
                                padding:
                                    const EdgeInsets.fromLTRB(12, 12, 12, 8),
                                child: const PoolSidebar(),
                              )
                            : const SizedBox.shrink(),
                      );
                    },
                  ),
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
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

// ---------------- 플래너 보드 (컬럼 고정폭 + 가로 스크롤 + 드래그 오토스크롤) ----------------
class _PlannerBoard extends StatefulWidget {
  final ScrollController controller;
  const _PlannerBoard({required this.controller});

  static const double kColumnWidth = 230.0;
  static const double kColumnGap = 10.0;

  @override
  State<_PlannerBoard> createState() => _PlannerBoardState();
}

class _PlannerBoardState extends State<_PlannerBoard> {
  static const double _edgeZone = 70.0;
  static const double _maxSpeed = 500.0;

  Timer? _autoScrollTimer;
  double _scrollDir = 0;
  double _scrollStrength = 0;

  bool _draggingActive = false;

  @override
  void initState() {
    super.initState();
    // 가로 스크롤이 움직이면 곡선 오버레이가 다시 그려지도록 신호
    widget.controller.addListener(_onBoardScroll);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onBoardScroll);
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  void _onBoardScroll() {
    // provider를 통해 오버레이가 리빌드되도록 알림
    // (좌표 자체는 각 요일 컬럼이 다음 프레임에 다시 등록함)
    if (!mounted) return;
    setState(() {});
  }

  void _startAutoScroll(double dir, double strength) {
    _scrollDir = dir;
    _scrollStrength = strength;
    _autoScrollTimer ??= Timer.periodic(
      const Duration(milliseconds: 16),
      (_) {
        if (!widget.controller.hasClients) return;
        final delta = _maxSpeed * _scrollStrength * (16 / 1000) * _scrollDir;
        final pos = widget.controller.position;
        final next = (widget.controller.offset + delta)
            .clamp(pos.minScrollExtent, pos.maxScrollExtent);
        widget.controller.jumpTo(next);
      },
    );
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
    _scrollDir = 0;
    _scrollStrength = 0;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlannerProvider>();
    final todayIdx = DateTime.now().weekday - 1;

    return LayoutBuilder(
      builder: (context, c) {
        final totalWidth = _PlannerBoard.kColumnWidth * 7 +
            _PlannerBoard.kColumnGap * 6;
        final scrollable = totalWidth > (c.maxWidth - 28);

        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Stack(
            children: [
              Scrollbar(
                controller: widget.controller,
                thumbVisibility: scrollable,
                trackVisibility: scrollable,
                child: SingleChildScrollView(
                  controller: widget.controller,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (int i = 0; i < provider.days.length; i++) ...[
                          if (i > 0)
                            const SizedBox(width: _PlannerBoard.kColumnGap),
                          SizedBox(
                            width: _PlannerBoard.kColumnWidth,
                            child: DayColumnWidget(
                              day: provider.days[i],
                              width: _PlannerBoard.kColumnWidth,
                              isToday: i == todayIdx,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // 요일 간 곡선 연결 오버레이
              const Positioned.fill(
                child: IgnorePointer(
                  child: _ConnectionOverlay(),
                ),
              ),

              if (scrollable)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: _edgeZone,
                  child: _EdgeAutoScroll(
                    direction: -1,
                    onEnter: (strength) {
                      setState(() => _draggingActive = true);
                      _startAutoScroll(-1, strength);
                    },
                    onUpdate: (strength) => _startAutoScroll(-1, strength),
                    onLeave: () {
                      _stopAutoScroll();
                      setState(() => _draggingActive = false);
                    },
                    showHint: _draggingActive && _scrollDir == -1,
                  ),
                ),

              if (scrollable)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: _edgeZone,
                  child: _EdgeAutoScroll(
                    direction: 1,
                    onEnter: (strength) {
                      setState(() => _draggingActive = true);
                      _startAutoScroll(1, strength);
                    },
                    onUpdate: (strength) => _startAutoScroll(1, strength),
                    onLeave: () {
                      _stopAutoScroll();
                      setState(() => _draggingActive = false);
                    },
                    showHint: _draggingActive && _scrollDir == 1,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 좌우 가장자리 오토스크롤 감지 영역.
class _EdgeAutoScroll extends StatefulWidget {
  final int direction;
  final ValueChanged<double> onEnter;
  final ValueChanged<double> onUpdate;
  final VoidCallback onLeave;
  final bool showHint;

  const _EdgeAutoScroll({
    required this.direction,
    required this.onEnter,
    required this.onUpdate,
    required this.onLeave,
    required this.showHint,
  });

  @override
  State<_EdgeAutoScroll> createState() => _EdgeAutoScrollState();
}

class _EdgeAutoScrollState extends State<_EdgeAutoScroll> {
  double _computeStrength(Offset localPos, Size size) {
    final double dx = widget.direction < 0
        ? (size.width - localPos.dx)
        : localPos.dx;
    final double ratio = 1.0 - (dx / size.width).clamp(0.0, 1.0);
    return (ratio * 0.75 + 0.25).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        return DragTarget<Object>(
          onWillAcceptWithDetails: (details) {
            final size = Size(c.maxWidth, c.maxHeight);
            final box = context.findRenderObject() as RenderBox?;
            if (box == null) return false;
            final local = box.globalToLocal(details.offset);
            widget.onEnter(_computeStrength(local, size));
            return false;
          },
          onMove: (details) {
            final size = Size(c.maxWidth, c.maxHeight);
            final box = context.findRenderObject() as RenderBox?;
            if (box == null) return;
            final local = box.globalToLocal(details.offset);
            widget.onUpdate(_computeStrength(local, size));
          },
          onLeave: (_) => widget.onLeave(),
          builder: (context, candidate, rejected) {
            return IgnorePointer(
              ignoring: true,
              child: AnimatedOpacity(
                opacity: widget.showHint ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: widget.direction < 0
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      end: widget.direction < 0
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      colors: [
                        AppTokens.accent.withValues(alpha: 0.18),
                        AppTokens.accent.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  child: Align(
                    alignment: widget.direction < 0
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(
                        widget.direction < 0
                            ? Icons.chevron_left_rounded
                            : Icons.chevron_right_rounded,
                        size: 32,
                        color: AppTokens.accent.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------- 요일 간 곡선 연결 오버레이 ----------------
class _ConnectionOverlay extends StatefulWidget {
  const _ConnectionOverlay();

  @override
  State<_ConnectionOverlay> createState() => _ConnectionOverlayState();
}

class _ConnectionOverlayState extends State<_ConnectionOverlay> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlannerProvider>();

    // days 순서대로, 각 요일의 (left, right) 쌍을 모음
    final segments = <(_EdgePoint, _EdgePoint)>[];

    _EdgePoint? prevRight;
    for (final d in provider.days) {
      final left = provider.blockLefts[d.id];
      final right = provider.blockRights[d.id];
      if (left == null || right == null) continue;

      if (prevRight != null) {
        segments.add((prevRight, _EdgePoint(left)));
      }
      prevRight = _EdgePoint(right);
    }

    if (segments.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null || !box.attached) {
          return const SizedBox.shrink();
        }

        // 글로벌 → 로컬 변환
        final localSegs = segments.map((s) {
          return (
            _EdgePoint(box.globalToLocal(s.$1.p)),
            _EdgePoint(box.globalToLocal(s.$2.p)),
          );
        }).toList(growable: false);

        return CustomPaint(
          painter: _ConnectionPainter(
            segments: localSegs,
            color: AppTokens.accent,
          ),
        );
      },
    );
  }
}

class _EdgePoint {
  final Offset p;
  _EdgePoint(this.p);
}

class _ConnectionPainter extends CustomPainter {
  final List<(_EdgePoint, _EdgePoint)> segments;
  final Color color;

  _ConnectionPainter({required this.segments, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) return;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final dot = Paint()..color = color;

    for (final seg in segments) {
      final a = seg.$1.p; // 이전 요일 카드의 우측 중앙
      final b = seg.$2.p; // 다음 요일 카드의 좌측 중앙
      final dx = (b.dx - a.dx);
      final cp1 = Offset(a.dx + dx * 0.5, a.dy);
      final cp2 = Offset(b.dx - dx * 0.5, b.dy);
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, b.dx, b.dy);
      canvas.drawPath(path, paint);

      canvas.drawCircle(a, 2.6, dot);
      canvas.drawCircle(b, 2.6, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectionPainter old) => true;
}
