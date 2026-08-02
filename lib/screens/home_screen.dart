import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/category.dart';
import '../models/task_block.dart';
import '../providers/planner_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/day_column_widget.dart';
import '../widgets/pool_section.dart';
import '../widgets/legend_bar.dart';
import '../widgets/edit_dialog.dart';
import 'package:flutter/scheduler.dart'; // Ticker 사용


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
                                padding: const EdgeInsets.fromLTRB(
                                    12, 12, 12, 8),
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

// ---------------- 플래너 보드 ----------------
class _PlannerBoard extends StatefulWidget {
  final ScrollController controller;
  const _PlannerBoard({required this.controller});

  static const double kBaseColumnWidth = 230.0;
  static const double kBaseColumnGap = 10.0;

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

  double _zoom = 1.0;
  static const double _minZoom = 0.5;
  static const double _maxZoom = 2.0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onBoardScroll);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onBoardScroll);
    _autoScrollTimer?.cancel();
    super.dispose();
  }

  void _onBoardScroll() {
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

  bool _isCtrlPressed() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight);
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (!_isCtrlPressed()) return;
    final dy = event.scrollDelta.dy;
    if (dy == 0) return;
    setState(() {
      final factor = dy > 0 ? 0.9 : 1.1;
      _zoom = (_zoom * factor).clamp(_minZoom, _maxZoom);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlannerProvider>();
    final todayIdx = DateTime.now().weekday - 1;

    // 실제 컬럼/갭 크기 (zoom 반영)
    final colW = _PlannerBoard.kBaseColumnWidth * _zoom;
    final colGap = _PlannerBoard.kBaseColumnGap * _zoom;

    return LayoutBuilder(
      builder: (context, c) {
        final totalW = colW * 7 + colGap * 6;
        final scrollable = totalW > (c.maxWidth - 28);

        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Listener(
            onPointerSignal: _handlePointerSignal,
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
                    // 세로는 부모(Expanded)가 준 높이 그대로 100% 사용
                    child: SizedBox(
                      width: totalW,
                      height: c.maxHeight - 10,
                      child: Stack(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (int i = 0;
                                  i < provider.days.length;
                                  i++) ...[
                                if (i > 0) SizedBox(width: colGap),
                                SizedBox(
                                  width: colW,
                                  child: DayColumnWidget(
                                    day: provider.days[i],
                                    width: colW,
                                    isToday: i == todayIdx,
                                    zoom: _zoom,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          // 곡선 오버레이: 스크롤 콘텐츠와 같은 좌표계
                          Positioned.fill(
                            child: IgnorePointer(
                              child: _ConnectionOverlay(columnGap: colGap),
                            ),
                          ),
                        ],
                      ),
                    ),
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

                if ((_zoom - 1.0).abs() > 0.001)
                  Positioned(
                    right: 12,
                    bottom: 14,
                    child: _ZoomBadge(
                      zoom: _zoom,
                      onReset: () => setState(() => _zoom = 1.0),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ZoomBadge extends StatelessWidget {
  final double zoom;
  final VoidCallback onReset;
  const _ZoomBadge({required this.zoom, required this.onReset});

  @override
  Widget build(BuildContext context) {
    final pct = (zoom * 100).round();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onReset,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppTokens.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppTokens.border),
            boxShadow: AppTokens.cardShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_rounded,
                  size: 14, color: AppTokens.textSecondary),
              const SizedBox(width: 6),
              Text('$pct%',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTokens.textPrimary)),
              const SizedBox(width: 6),
              const Text('클릭 시 100%',
                  style: TextStyle(
                      fontSize: 10.5, color: AppTokens.textFaint)),
            ],
          ),
        ),
      ),
    );
  }
}

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
  final double columnGap;
  const _ConnectionOverlay({required this.columnGap});

  @override
  State<_ConnectionOverlay> createState() => _ConnectionOverlayState();
}

class _ConnectionOverlayState extends State<_ConnectionOverlay> {
  @override
  Widget build(BuildContext context) {
    // provider 변화에도 리빌드되어야 하므로 watch
    final provider = context.watch<PlannerProvider>();

    if (provider.matchedKeys.isEmpty) {
      return const SizedBox.shrink();
    }

    // 모든 요일의 스크롤 컨트롤러를 하나의 Listenable 로 병합.
    // 어느 컬럼이든 스크롤 애니메이션이 진행되면 매 프레임 rebuild → 곡선이 카드 따라감.
    final scrollListenables =
        provider.dayScrollControllers.values.toList(growable: false);

    return AnimatedBuilder(
      animation: Listenable.merge(scrollListenables),
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final overlayBox = context.findRenderObject() as RenderBox?;
            if (overlayBox == null || !overlayBox.attached) {
              return const SizedBox.shrink();
            }

            final points = <_EdgeInfo>[];
            for (final d in provider.days) {
              final key = provider.matchedKeys[d.id];
              if (key == null) continue;
              final ctx = key.currentContext;
              if (ctx == null) continue;
              final rb = ctx.findRenderObject() as RenderBox?;
              if (rb == null || !rb.attached) continue;

              final leftGlobal =
                  rb.localToGlobal(Offset(0, rb.size.height / 2));
              final rightGlobal =
                  rb.localToGlobal(Offset(rb.size.width, rb.size.height / 2));

              final leftLocal = overlayBox.globalToLocal(leftGlobal);
              final rightLocal = overlayBox.globalToLocal(rightGlobal);

              Color color = AppTokens.accent;
              for (final b in d.blocks) {
                if (provider.hoverMatchedIds.contains(b.id)) {
                  color = categoryById(b.categoryId).color;
                  break;
                }
              }

              points.add(_EdgeInfo(
                left: leftLocal,
                right: rightLocal,
                color: color,
              ));
            }

            if (points.length < 2) return const SizedBox.shrink();

            final segments = <_Segment>[];
            for (int i = 0; i < points.length - 1; i++) {
              segments.add(_Segment(
                a: points[i].right,
                b: points[i + 1].left,
                colorA: points[i].color,
                colorB: points[i + 1].color,
              ));
            }

            return CustomPaint(
              painter: _ConnectionPainter(segments: segments),
            );
          },
        );
      },
    );
  }
}



class _EdgeInfo {
  final Offset left;
  final Offset right;
  final Color color;
  _EdgeInfo({
    required this.left,
    required this.right,
    required this.color,
  });
}

class _Segment {
  final Offset a;
  final Offset b;
  final Color colorA;
  final Color colorB;
  _Segment({
    required this.a,
    required this.b,
    required this.colorA,
    required this.colorB,
  });
}

class _ConnectionPainter extends CustomPainter {
  final List<_Segment> segments;

  _ConnectionPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) return;

    for (final seg in segments) {
      final a = seg.a;
      final b = seg.b;
      final gapDx = (b.dx - a.dx);

      // 제어점을 두 카드 사이 갭 안에 완전히 가둠 → 카드 위 통과 불가
      final controlOffset = gapDx * 0.4;
      final cp1 = Offset(a.dx + controlOffset, a.dy);
      final cp2 = Offset(b.dx - controlOffset, b.dy);

      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, b.dx, b.dy);

      final rect = path.getBounds().inflate(1);
      final shader = ui.Gradient.linear(
        Offset(rect.left, (a.dy + b.dy) / 2),
        Offset(rect.right, (a.dy + b.dy) / 2),
        [
          seg.colorA.withValues(alpha: 0.95),
          seg.colorB.withValues(alpha: 0.95),
        ],
      );

      final paint = Paint()
        ..shader = shader
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(path, paint);
      
      // 끝점 dot marker
final dotPaint = Paint()..style = PaintingStyle.fill;

// 시작점: 왼쪽 블록 카테고리 색
dotPaint.color = seg.colorA;
canvas.drawCircle(a, 3.0, dotPaint);

// 끝점: 오른쪽 블록 카테고리 색
dotPaint.color = seg.colorB;
canvas.drawCircle(b, 3.0, dotPaint);

      
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectionPainter old) => true;
}
