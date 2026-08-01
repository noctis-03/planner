import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../models/task_block.dart';
import '../providers/planner_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/edit_dialog.dart';

/// 블록별 무한 캔버스 워크스페이스
class CanvasScreen extends StatefulWidget {
  final String blockId;
  const CanvasScreen({super.key, required this.blockId});

  @override
  State<CanvasScreen> createState() => _CanvasScreenState();
}

class _CanvasScreenState extends State<CanvasScreen> {
  final TransformationController _tc = TransformationController();

  /// 포트 연결 드래그 중: 출발 노드 id 와 현재 포인터 위치(캔버스 좌표)
  String? _dragFromId;
  Offset? _dragCurrent; // 캔버스 좌표계
  String? _hoverTargetId; // 드래그 중 연결 가능 대상(하이라이트)

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PlannerProvider>();
    final block = provider.findBlock(widget.blockId);

    if (block == null) {
      return const Scaffold(body: Center(child: Text('블록을 찾을 수 없습니다')));
    }

    // 캔버스 크기를 노드 위치에 맞춰 동적으로 확장 (진짜 "무한")
    double maxRight = 1600;
    double maxBottom = 1200;
    for (final n in block.nodes) {
      maxRight = math.max(maxRight, n.x + n.w + 600);
      maxBottom = math.max(maxBottom, n.y + n.h + 600);
    }

    return Scaffold(
      backgroundColor: AppTokens.bg,
      appBar: AppBar(
        backgroundColor: AppTokens.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const Border(bottom: BorderSide(color: AppTokens.border)),
        foregroundColor: AppTokens.textPrimary,
        titleSpacing: 0,
        title: Row(
          children: [
            const Icon(Icons.hub_outlined, size: 18, color: AppTokens.accent),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                block.title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: '화면 맞춤(뷰 리셋)',
            onPressed: () => _tc.value = Matrix4.identity(),
            icon: const Icon(Icons.center_focus_strong_outlined, size: 20),
          ),
        ],
      ),
      body: Stack(
        children: [
          InteractiveViewer(
            transformationController: _tc,
            constrained: false,
            boundaryMargin: const EdgeInsets.all(4000),
            minScale: 0.3,
            maxScale: 3.0,
            // 연결 드래그 중에는 팬 비활성화
            panEnabled: _dragFromId == null,
            scaleEnabled: _dragFromId == null,
            child: SizedBox(
              width: maxRight,
              height: maxBottom,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _GridPainter()),
                  ),
                  // 확정된 연결선 + 드래그 중 임시선
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _EdgePainter(
                        block: block,
                        dragFromId: _dragFromId,
                        dragCurrent: _dragCurrent,
                      ),
                    ),
                  ),
                  for (final node in block.nodes)
                    _NodeWidget(
                      key: ValueKey(node.id),
                      blockId: widget.blockId,
                      node: node,
                      connecting: _dragFromId != null,
                      isHoverTarget: _hoverTargetId == node.id,
                      onExecute: () => _executeNode(provider, node),
                      onPortDragStart: (id, pos) {
                        setState(() {
                          _dragFromId = id;
                          _dragCurrent = pos;
                          _hoverTargetId = null;
                        });
                      },
                      onPortDragUpdate: (pos) {
                        setState(() {
                          _dragCurrent = pos;
                          _hoverTargetId = _hitTarget(block, _dragFromId, pos);
                        });
                      },
                      onPortDragEnd: () {
                        _finishConnection(provider, block);
                      },
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _AddNodeBar(blockId: widget.blockId),
          ),
        ],
      ),
    );
  }

  // 현재 포인터 아래의 연결 가능 대상 노드 id
  String? _hitTarget(TaskBlock block, String? from, Offset cur) {
    if (from == null) return null;
    for (final n in block.nodes) {
      if (n.id == from) continue;
      if (n.type == CanvasNodeType.execute) continue; // 실행 노드는 대상 아님
      final rect = Rect.fromLTWH(n.x, n.y, n.w, n.h);
      if (rect.contains(cur)) return n.id;
    }
    return null;
  }

  // 드래그 종료 시 포인터 아래의 노드에 연결
  void _finishConnection(PlannerProvider provider, TaskBlock block) {
    final from = _dragFromId;
    final cur = _dragCurrent;
    if (from != null && cur != null) {
      final targetId = _hitTarget(block, from, cur);
      if (targetId != null) {
        provider.addCanvasEdge(widget.blockId, from, targetId);
      }
    }
    setState(() {
      _dragFromId = null;
      _dragCurrent = null;
      _hoverTargetId = null;
    });
  }

  // "실행" = 연결된 링크 열기 + 파일 열기
  Future<void> _executeNode(
      PlannerProvider provider, CanvasNode executeNode) async {
    final m = ScaffoldMessenger.of(context);
    final targets = provider.connectedTargets(widget.blockId, executeNode.id);
    if (targets.isEmpty) {
      m.showSnackBar(const SnackBar(
        content: Text('연결된 노드가 없습니다. 실행 노드의 오른쪽 ● 를 링크/파일 노드로 드래그하세요.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    int opened = 0;
    final failed = <String>[];
    for (final t in targets) {
      if (t.type == CanvasNodeType.link) {
        final url = t.text.trim();
        if (url.isEmpty) {
          failed.add(t.title.isEmpty ? '링크' : t.title);
          continue;
        }
        final ok = await _openLink(url);
        ok ? opened++ : failed.add(url);
      } else if (t.type == CanvasNodeType.file) {
        if (t.fileData.trim().isEmpty) {
          failed.add(t.fileName.isEmpty ? '파일(미첨부)' : t.fileName);
          continue;
        }
        final ok = await _openFile(t);
        ok ? opened++ : failed.add(t.fileName.isEmpty ? '파일' : t.fileName);
      }
      // 메모 노드는 실행 대상 아님 (무시)
    }
    if (!mounted) return;
    m.showSnackBar(SnackBar(
      content: Text(opened > 0
          ? '$opened개 항목을 열었습니다${failed.isEmpty ? '' : ' · 실패 ${failed.length}개'}'
          : (failed.isEmpty
              ? '열 수 있는 항목이 없습니다 (링크/파일 노드를 연결하세요)'
              : '열기에 실패했습니다: ${failed.join(', ')}')),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<bool> _openLink(String raw) async {
    var url = raw.trim();
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    try {
      final uri = Uri.parse(url);
      if (kIsWeb) {
        return await launchUrl(uri, webOnlyWindowName: '_blank');
      }
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _openFile(CanvasNode node) async {
    try {
      if (kIsWeb) {
        if (node.fileData.startsWith('data:')) {
          return await launchUrl(
            Uri.parse(node.fileData),
            webOnlyWindowName: '_blank',
          );
        }
        return false;
      } else {
        final uri = Uri.file(node.fileData);
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      return false;
    }
  }
}

// ---------------- 노드 위젯 ----------------
typedef PortDragStart = void Function(String id, Offset canvasPos);
typedef PortDragUpdate = void Function(Offset canvasPos);

class _NodeWidget extends StatefulWidget {
  final String blockId;
  final CanvasNode node;
  final bool connecting; // 현재 캔버스에서 포트 드래그 진행 중
  final bool isHoverTarget; // 이 노드가 연결 드래그의 대상으로 하이라이트
  final VoidCallback onExecute;
  final PortDragStart onPortDragStart;
  final PortDragUpdate onPortDragUpdate;
  final VoidCallback onPortDragEnd;

  const _NodeWidget({
    super.key,
    required this.blockId,
    required this.node,
    required this.connecting,
    required this.isHoverTarget,
    required this.onExecute,
    required this.onPortDragStart,
    required this.onPortDragUpdate,
    required this.onPortDragEnd,
  });

  @override
  State<_NodeWidget> createState() => _NodeWidgetState();
}

class _NodeWidgetState extends State<_NodeWidget> {
  bool _hover = false;
  bool _portDragging = false; // 이 노드의 출력 포트를 드래그 중

  CanvasNode get node => widget.node;
  String get blockId => widget.blockId;

  Color get _accent {
    switch (node.type) {
      case CanvasNodeType.memo:
        return const Color(0xFF64748B);
      case CanvasNodeType.link:
        return const Color(0xFF3B82F6);
      case CanvasNodeType.file:
        return const Color(0xFF10B981);
      case CanvasNodeType.execute:
        return const Color(0xFFF97316);
    }
  }

  IconData get _icon {
    switch (node.type) {
      case CanvasNodeType.memo:
        return Icons.sticky_note_2_outlined;
      case CanvasNodeType.link:
        return Icons.link_rounded;
      case CanvasNodeType.file:
        return Icons.insert_drive_file_outlined;
      case CanvasNodeType.execute:
        return Icons.play_arrow_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<PlannerProvider>();

    // 실행 노드는 오른쪽 출력 포트만, 나머지는 왼쪽 입력 포트만 의미가 있음
    final bool hasOutputPort = node.type == CanvasNodeType.execute;
    final bool isInputTarget = node.type != CanvasNodeType.execute;

    // 포트 표시 조건:
    //  - 왼쪽 입력 포트: hover 또는 연결 드래그 진행 중(대상 후보)
    //  - 오른쪽 출력 포트: hover 또는 "이 노드가 지금 드래그 중"일 때 (드래그 중엔 hover가 풀려도 유지)
    final bool showLeftPort = isInputTarget && (_hover || widget.connecting);
    final bool showRightPort = hasOutputPort && (_hover || _portDragging);
    final bool showResize = _hover && !widget.connecting;

    return Positioned(
      left: node.x,
      top: node.y,
      width: node.w,
      height: node.h,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 노드 본체
            Container(
              width: node.w,
              height: node.h,
              decoration: BoxDecoration(
                color: AppTokens.surface,
                borderRadius: BorderRadius.circular(AppTokens.rMd),
                border: Border.all(
                  color: widget.isHoverTarget ? _accent : AppTokens.border,
                  width: widget.isHoverTarget ? 2 : 1,
                ),
                boxShadow: AppTokens.softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 헤더 (드래그로 이동)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (d) {
                      provider.updateCanvasNodePos(blockId, node.id,
                          node.x + d.delta.dx, node.y + d.delta.dy);
                    },
                    onPanEnd: (_) => provider.snapCanvasNode(blockId, node.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.10),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(AppTokens.rMd)),
                      ),
                      child: Row(
                        children: [
                          Icon(_icon, size: 15, color: _accent),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              node.title,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: _accent),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          GestureDetector(
                            onTap: () =>
                                provider.deleteCanvasNode(blockId, node.id),
                            child: const Icon(Icons.close_rounded,
                                size: 14, color: AppTokens.textFaint),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 본문
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: _body(context, provider),
                    ),
                  ),
                  if (node.type == CanvasNodeType.execute)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _RunButton(onTap: widget.onExecute),
                      ),
                    ),
                ],
              ),
            ),

            // 왼쪽 입력 포트 (수신) - 근처(hover/연결중)일 때만 표시
            if (showLeftPort)
              Positioned(
                left: -7,
                top: node.h / 2 - 7,
                child: _PortDot(
                    color: _accent,
                    filled: widget.isHoverTarget,
                    highlight: widget.isHoverTarget),
              ),

            // 오른쪽 출력 포트 (드래그 시작) - 실행 노드 + hover 시에만 표시
            if (showRightPort)
              Positioned(
                right: -7,
                top: node.h / 2 - 7,
                child: _RightPortDragger(
                  key: ValueKey('port_${node.id}'),
                  accent: _accent,
                  startPos: Offset(node.x + node.w, node.y + node.h / 2),
                  onStart: (pos) {
                    setState(() => _portDragging = true);
                    widget.onPortDragStart(node.id, pos);
                  },
                  onUpdate: widget.onPortDragUpdate,
                  onEnd: () {
                    setState(() => _portDragging = false);
                    widget.onPortDragEnd();
                  },
                ),
              ),

            // 오른쪽 아래 리사이즈 핸들 - hover 시에만 표시
            if (showResize)
              Positioned(
                right: -2,
                bottom: -2,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeDownRight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (d) {
                      provider.resizeCanvasNode(blockId, node.id,
                          node.w + d.delta.dx, node.h + d.delta.dy);
                    },
                    onPanEnd: (_) =>
                        provider.snapCanvasNodeSize(blockId, node.id),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppTokens.surface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTokens.border),
                      ),
                      child: const Icon(Icons.open_in_full_rounded,
                          size: 11, color: AppTokens.textFaint),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, PlannerProvider provider) {
    switch (node.type) {
      case CanvasNodeType.memo:
        return GestureDetector(
          onTap: () => _editText(context, provider, '메모 편집', '내용', node.text,
              multiline: true,
              apply: (v) =>
                  provider.updateCanvasNode(blockId, node.id, text: v)),
          child: SingleChildScrollView(
            child: Text(
              node.text.isEmpty ? '탭하여 메모 작성…' : node.text,
              style: TextStyle(
                fontSize: 12,
                color: node.text.isEmpty
                    ? AppTokens.textFaint
                    : AppTokens.textPrimary,
                height: 1.35,
              ),
            ),
          ),
        );
      case CanvasNodeType.link:
        return GestureDetector(
          onTap: () => _editText(context, provider, '링크 편집', 'URL', node.text,
              apply: (v) =>
                  provider.updateCanvasNode(blockId, node.id, text: v)),
          child: Align(
            alignment: Alignment.topLeft,
            child: Text(
              node.text.isEmpty ? '탭하여 URL 입력…' : node.text,
              style: TextStyle(
                fontSize: 12,
                color:
                    node.text.isEmpty ? AppTokens.textFaint : AppTokens.accent,
                decoration: node.text.isEmpty ? null : TextDecoration.underline,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      case CanvasNodeType.file:
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _pickFile(context, provider),
          child: Align(
            alignment: Alignment.topLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.attach_file_rounded,
                        size: 14,
                        color: node.fileName.isEmpty
                            ? AppTokens.textFaint
                            : _accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        node.fileName.isEmpty ? '탭하여 파일 첨부…' : node.fileName,
                        style: TextStyle(
                          fontSize: 12,
                          color: node.fileName.isEmpty
                              ? AppTokens.textFaint
                              : AppTokens.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (node.fileName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('탭하여 다른 파일로 교체',
                        style: const TextStyle(
                            fontSize: 10, color: AppTokens.textFaint)),
                  ),
              ],
            ),
          ),
        );
      case CanvasNodeType.execute:
        final targets = provider.connectedTargets(blockId, node.id);
        return Align(
          alignment: Alignment.topLeft,
          child: Text(
            targets.isEmpty
                ? '오른쪽 ● 를 링크/파일 노드로\n드래그해 연결하세요'
                : '연결됨: ${targets.length}개\n실행 → 링크/파일 열기',
            style: const TextStyle(
                fontSize: 11.5, color: AppTokens.textSecondary, height: 1.35),
          ),
        );
    }
  }

  void _editText(BuildContext context, PlannerProvider provider, String title,
      String label, String initial,
      {bool multiline = false, required ValueChanged<String> apply}) {
    final ctrl = TextEditingController(text: initial);
    showMinimalEditDialog(
      context,
      title: title,
      children: [
        TextField(
          controller: ctrl,
          minLines: multiline ? 3 : 1,
          maxLines: multiline ? 6 : 1,
          decoration: InputDecoration(
            labelText: label,
            hintText: label == 'URL' ? 'https://example.com' : null,
          ),
        ),
      ],
      onSave: () => apply(ctrl.text.trim()),
    );
  }

  Future<void> _pickFile(
      BuildContext context, PlannerProvider provider) async {
    final m = ScaffoldMessenger.of(context);
    try {
      final result = await FilePicker.platform.pickFiles(
        withData: kIsWeb,
        type: FileType.any,
      );
      if (result == null || result.files.isEmpty) return; // 취소
      final f = result.files.first;
      String data;
      if (kIsWeb) {
        final bytes = f.bytes;
        if (bytes == null) {
          m.showSnackBar(const SnackBar(
            content: Text('파일 데이터를 읽지 못했습니다. 다시 시도해주세요.'),
            behavior: SnackBarBehavior.floating,
          ));
          return;
        }
        final mime = _guessMime(f.extension);
        final b64 = base64Encode(bytes);
        data = 'data:$mime;base64,$b64';
      } else {
        data = f.path ?? '';
        if (data.isEmpty) {
          m.showSnackBar(const SnackBar(
            content: Text('파일 경로를 가져오지 못했습니다.'),
            behavior: SnackBarBehavior.floating,
          ));
          return;
        }
      }
      provider.updateCanvasNode(blockId, node.id,
          fileName: f.name, fileData: data);
      m.showSnackBar(SnackBar(
        content: Text('파일 첨부됨: ${f.name}'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      m.showSnackBar(SnackBar(
        content: Text('파일 선택 실패: $e'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  String _guessMime(String? ext) {
    switch ((ext ?? '').toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      case 'html':
        return 'text/html';
      case 'json':
        return 'application/json';
      case 'csv':
        return 'text/csv';
      case 'mp4':
        return 'video/mp4';
      case 'mp3':
        return 'audio/mpeg';
      default:
        return 'application/octet-stream';
    }
  }
}

// 오른쪽 출력 포트 드래거 (delta 누적으로 캔버스 좌표 추적)
class _RightPortDragger extends StatefulWidget {
  final Color accent;
  final Offset startPos;
  final ValueChanged<Offset> onStart;
  final ValueChanged<Offset> onUpdate;
  final VoidCallback onEnd;

  const _RightPortDragger({
    super.key,
    required this.accent,
    required this.startPos,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  @override
  State<_RightPortDragger> createState() => _RightPortDraggerState();
}

class _RightPortDraggerState extends State<_RightPortDragger> {
  Offset _cur = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) {
        _cur = widget.startPos;
        widget.onStart(_cur);
      },
      onPanUpdate: (d) {
        _cur = _cur + d.delta;
        widget.onUpdate(_cur);
      },
      onPanEnd: (_) => widget.onEnd(),
      child: _PortDot(color: widget.accent, filled: true),
    );
  }
}

// 포트 점(●)
class _PortDot extends StatelessWidget {
  final Color color;
  final bool filled;
  final bool highlight;
  const _PortDot(
      {required this.color, required this.filled, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final double size = highlight ? 18 : 14;
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: filled ? color : AppTokens.surface,
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
          boxShadow: AppTokens.cardShadow,
        ),
      ),
    );
  }
}

class _RunButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RunButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF97316),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow_rounded, size: 15, color: Colors.white),
            SizedBox(width: 3),
            Text('실행',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

// ---------------- 노드 추가 하단 바 ----------------
class _AddNodeBar extends StatelessWidget {
  final String blockId;
  const _AddNodeBar({required this.blockId});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<PlannerProvider>();
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.rLg),
        border: Border.all(color: AppTokens.border),
        boxShadow: AppTokens.softShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _addBtn(context, provider, CanvasNodeType.memo, '메모',
              Icons.sticky_note_2_outlined, const Color(0xFF64748B)),
          _addBtn(context, provider, CanvasNodeType.link, '링크',
              Icons.link_rounded, const Color(0xFF3B82F6)),
          _addBtn(context, provider, CanvasNodeType.file, '파일',
              Icons.insert_drive_file_outlined, const Color(0xFF10B981)),
          _addBtn(context, provider, CanvasNodeType.execute, '실행',
              Icons.play_arrow_rounded, const Color(0xFFF97316)),
        ],
      ),
    );
  }

  Widget _addBtn(BuildContext context, PlannerProvider provider,
      CanvasNodeType type, String label, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () {
          final count = provider.findBlock(blockId)!.nodes.length;
          final base = 80.0 + (count % 6) * 40;
          provider.addCanvasNode(blockId, type, x: base, y: base);
        },
        borderRadius: BorderRadius.circular(AppTokens.rSm),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- 페인터 ----------------
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final minor = Paint()
      ..color = const Color(0xFFEDEFF3)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = const Color(0xFFE0E4EA)
      ..strokeWidth = 1;
    const step = kCanvasGrid;
    int i = 0;
    for (double x = 0; x < size.width; x += step, i++) {
      canvas.drawLine(
          Offset(x, 0), Offset(x, size.height), i % 5 == 0 ? major : minor);
    }
    i = 0;
    for (double y = 0; y < size.height; y += step, i++) {
      canvas.drawLine(
          Offset(0, y), Offset(size.width, y), i % 5 == 0 ? major : minor);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EdgePainter extends CustomPainter {
  final TaskBlock block;
  final String? dragFromId;
  final Offset? dragCurrent;

  _EdgePainter({
    required this.block,
    this.dragFromId,
    this.dragCurrent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTokens.accent.withValues(alpha: 0.6)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    final dot = Paint()..color = AppTokens.accent;

    final byId = {for (final n in block.nodes) n.id: n};

    // 확정된 연결선: 출발 오른쪽중앙 → 도착 왼쪽중앙
    for (final e in block.edges) {
      final from = byId[e.fromId];
      final to = byId[e.toId];
      if (from == null || to == null) continue;
      final p1 = Offset(from.x + from.w, from.y + from.h / 2);
      final p2 = Offset(to.x, to.y + to.h / 2);
      _drawCurve(canvas, paint, p1, p2);
      canvas.drawCircle(p1, 3.5, dot);
      canvas.drawCircle(p2, 3.5, dot);
    }

    // 드래그 중 임시선
    if (dragFromId != null && dragCurrent != null) {
      final from = byId[dragFromId];
      if (from != null) {
        final p1 = Offset(from.x + from.w, from.y + from.h / 2);
        final tmp = Paint()
          ..color = AppTokens.accent.withValues(alpha: 0.4)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;
        _drawCurve(canvas, tmp, p1, dragCurrent!);
        canvas.drawCircle(dragCurrent!, 4, dot);
      }
    }
  }

  void _drawCurve(Canvas canvas, Paint paint, Offset p1, Offset p2) {
    final dx = (p2.dx - p1.dx).abs();
    final ctrl = math.max(40.0, dx / 2);
    final path = Path()
      ..moveTo(p1.dx, p1.dy)
      ..cubicTo(p1.dx + ctrl, p1.dy, p2.dx - ctrl, p2.dy, p2.dx, p2.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _EdgePainter oldDelegate) => true;
}
