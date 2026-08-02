import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_block.dart';
import '../models/category.dart';

/// 드래그 소스 위치 참조
class BlockLocation {
  /// 'day' 또는 'pool'
  final String containerType;
  final String containerId;

  const BlockLocation(this.containerType, this.containerId);
}

class PlannerProvider extends ChangeNotifier {
  static const String _storageKey = 'weekly_planner_v1';
  static const String _presetKey = 'weekly_planner_presets_v1';

  List<DayColumn> days = [];
  List<PoolRow> pools = [];

  /// 저장된 프리셋 이름 목록 (표시용)
  List<String> presetNames = [];

  /// 현재 hover 중인 블록의 시간 (분 단위). null이면 hover 없음.
  int? hoverMinutes;

  /// hover 시간에 대응하여 각 요일에서 하이라이트할 블록 ID 집합.
  Set<String> hoverMatchedIds = <String>{};

  /// "정렬" 요청 카운터. 값이 바뀌면 각 요일 컬럼이 매칭 블록을
  /// 화면 상단 근처로 스크롤 정렬합니다.
  int alignTick = 0;

  /// 현재 정렬 기준 시간 (분). 클릭한 카드의 시간.
  int? alignMinutes;

  /// 정렬 요청을 발생시킨 원본 요일 id (참고용).
  String? alignOriginDayId;

  /// (구) 매칭 블록의 화면 글로벌 좌표. 하위호환용 — 지금은 사용 안 함.
  final Map<String, Offset> blockCenters = {};
  final Map<String, Offset> blockLefts = {};
  final Map<String, Offset> blockRights = {};

  /// 요일 id → 그 요일에서 매칭된 블록 위젯을 감싸는 KeyedSubtree 의 GlobalKey.
  /// 오버레이가 매 프레임 여기서 RenderBox 를 조회해 실시간 좌표를 계산한다.
  final Map<String, GlobalKey> matchedKeys = {};
  /// 요일 id → 그 요일 컬럼의 세로 스크롤 컨트롤러.
/// 오버레이가 매 프레임 곡선 좌표를 갱신하기 위해 이 컨트롤러들을 구독한다.
final Map<String, ScrollController> dayScrollControllers = {};

void registerDayScrollController(String dayId, ScrollController ctrl) {
  final prev = dayScrollControllers[dayId];
  if (prev == ctrl) return;
  dayScrollControllers[dayId] = ctrl;
  notifyListeners();
}

void unregisterDayScrollController(String dayId) {
  if (dayScrollControllers.remove(dayId) != null) {
    notifyListeners();
  }
}


  int _idCounter = 0;

  String _newId() {
    _idCounter++;
    return '${DateTime.now().microsecondsSinceEpoch}_$_idCounter';
  }

  String newId() => _newId();

  // ---------- 매칭 GlobalKey 등록 ----------
  void registerMatchedKey(String dayId, GlobalKey key) {
    final prev = matchedKeys[dayId];
    if (prev == key) return;
    matchedKeys[dayId] = key;
    notifyListeners();
  }

  void unregisterMatchedKey(String dayId) {
    if (matchedKeys.remove(dayId) != null) {
      notifyListeners();
    }
  }

  void _clearAllMatchedKeys() {
    if (matchedKeys.isEmpty) return;
    matchedKeys.clear();
  }

  // ---------- hover 매칭 ----------
  void setHoverMinutes(int? m) {
    if (hoverMinutes == m) return;
    hoverMinutes = m;
    _recomputeHoverMatches();
    if (m == null) {
      blockCenters.clear();
      blockLefts.clear();
      blockRights.clear();
      _clearAllMatchedKeys();
    }
    notifyListeners();
  }

  void _recomputeHoverMatches() {
    final target = hoverMinutes;
    if (target == null) {
      hoverMatchedIds = <String>{};
      return;
    }
    final matched = <String>{};
    for (final d in days) {
      final timed =
          d.blocks.where((b) => b.time.trim().isNotEmpty).toList();
      if (timed.isEmpty) continue;

      // 1) 정확히 같은 시간
      TaskBlock? exact;
      for (final b in timed) {
        if (b.minutes == target) {
          exact = b;
          break;
        }
      }
      if (exact != null) {
        matched.add(exact.id);
        continue;
      }

      // 2) target 이전 중 가장 가까운
      TaskBlock? prev;
      for (final b in timed) {
        if (b.minutes < target) {
          if (prev == null || b.minutes > prev.minutes) {
            prev = b;
          }
        }
      }
      if (prev != null) {
        matched.add(prev.id);
      }
    }
    hoverMatchedIds = matched;
  }

  /// 카드 클릭 → 그 시간을 기준으로 매칭 블록들을 각 요일에서 상단으로 정렬.
  void requestAlignByMinutes(int minutes, {String? originDayId}) {
    blockCenters.clear();
    blockLefts.clear();
    blockRights.clear();
    _clearAllMatchedKeys();
    alignMinutes = minutes;
    alignOriginDayId = originDayId;
    hoverMinutes = minutes;
    _recomputeHoverMatches();
    alignTick++;
    notifyListeners();
  }

  /// (구) 매칭 블록의 중심 좌표 등록. 하위호환용.
  void updateBlockCenter(String dayId, Offset? center) {
    if (center == null) {
      if (blockCenters.remove(dayId) != null) notifyListeners();
    } else {
      final prev = blockCenters[dayId];
      if (prev == null || (prev - center).distanceSquared > 0.25) {
        blockCenters[dayId] = center;
        notifyListeners();
      }
    }
  }

  /// (구) 매칭 블록의 좌측/우측 중앙 좌표를 등록. 하위호환용.
  void updateBlockEdges(String dayId, Offset? left, Offset? right) {
    bool changed = false;

    if (left == null) {
      if (blockLefts.remove(dayId) != null) changed = true;
    } else {
      final prev = blockLefts[dayId];
      if (prev == null || (prev - left).distanceSquared > 0.25) {
        blockLefts[dayId] = left;
        changed = true;
      }
    }

    if (right == null) {
      if (blockRights.remove(dayId) != null) changed = true;
    } else {
      final prev = blockRights[dayId];
      if (prev == null || (prev - right).distanceSquared > 0.25) {
        blockRights[dayId] = right;
        changed = true;
      }
    }

    if (changed) notifyListeners();
  }

  void clearBlockCenters() {
    if (blockCenters.isEmpty &&
        blockLefts.isEmpty &&
        blockRights.isEmpty) return;
    blockCenters.clear();
    blockLefts.clear();
    blockRights.clear();
    notifyListeners();
  }

  // ---------- 초기화 ----------
  Future<void> init() async {
    final loaded = await _loadFromStorage();
    if (!loaded) {
      _buildDefault();
    }
    final changed = _purgeExpired(DateTime.now());
    await _loadPresetNames();
    notifyListeners();
    if (changed > 0) save();
  }

  int _purgeExpired(DateTime now) {
    int count = 0;
    for (final d in days) {
      final before = d.blocks.length;
      d.blocks.removeWhere((b) => b.isExpired(now));
      count += before - d.blocks.length;
      for (final b in d.blocks) {
        if (b.shouldClearCompletion(now)) {
          b.completed = false;
          b.completedAt = null;
          count++;
        }
      }
    }
    for (final p in pools) {
      final before = p.blocks.length;
      p.blocks.removeWhere((b) => b.isExpired(now));
      count += before - p.blocks.length;
      for (final b in p.blocks) {
        if (b.shouldClearCompletion(now)) {
          b.completed = false;
          b.completedAt = null;
          count++;
        }
      }
    }
    return count;
  }

  void purgeExpiredNow() {
    final changed = _purgeExpired(DateTime.now());
    if (changed > 0) {
      notifyListeners();
      save();
    }
  }

  void _buildDefault() {
    const dayNames = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];
    days = List.generate(
      7,
      (i) => DayColumn(
        id: 'day_$i',
        dayLabel: dayNames[i],
        subLabel: '',
        blocks: [],
      ),
    );
    pools = [
      PoolRow(id: _newId(), title: '할 일 후보', blocks: []),
      PoolRow(id: _newId(), title: '아이디어', blocks: []),
      PoolRow(id: _newId(), title: '미정 일정', blocks: []),
    ];

    if (const bool.fromEnvironment('SEED_ONETIME')) {
      final today = DateTime.now().weekday - 1;
      days[today].blocks.add(TaskBlock(
          id: _newId(),
          title: '일반 일정',
          time: '0900',
          categoryId: 'work'));
      final ot = TaskBlock(
          id: _newId(),
          title: '일회용 일정',
          time: '1400',
          categoryId: 'meeting',
          oneTime: true);
      ot.expiresAt = _computeExpiry(ot.id).toIso8601String();
      days[today].blocks.add(ot);
      ot.expiresAt = _computeExpiryForDayIdx(today).toIso8601String();
    }
  }

  DateTime _computeExpiryForDayIdx(int dayIdx) {
    final now = DateTime.now();
    final today0 = DateTime(now.year, now.month, now.day);
    final todayIdx = now.weekday - 1;
    final daysUntil = (dayIdx - todayIdx + 7) % 7;
    return today0.add(Duration(days: daysUntil + 1));
  }

  // ---------- 블록 CRUD ----------
  TaskBlock createBlank() {
    return TaskBlock(id: _newId());
  }

  void addBlockToDay(String dayId) {
    final d = days.firstWhere((e) => e.id == dayId);
    d.blocks.add(createBlank());
    notifyListeners();
    save();
  }

  void addBlockToPool(String poolId) {
    final p = pools.firstWhere((e) => e.id == poolId);
    p.blocks.add(createBlank());
    notifyListeners();
    save();
  }

  void deleteBlock(String blockId) {
    for (final d in days) {
      d.blocks.removeWhere((b) => b.id == blockId);
    }
    for (final p in pools) {
      p.blocks.removeWhere((b) => b.id == blockId);
    }
    notifyListeners();
    save();
  }

  void toggleCompleteOrDelete(String blockId) {
    final b = findBlock(blockId);
    if (b == null) return;

    if (b.oneTime) {
      deleteBlock(blockId);
      return;
    }

    if (b.completed) {
      deleteBlock(blockId);
      return;
    }

    b.completed = true;
    b.completedAt = DateTime.now().toIso8601String();
    notifyListeners();
    save();
  }

  void updateBlockField(String blockId,
      {String? time, String? title, String? desc}) {
    final b = findBlock(blockId);
    if (b == null) return;
    if (time != null) b.time = time;
    if (title != null) b.title = title;
    if (desc != null) b.desc = desc;
    notifyListeners();
    save();
  }

  void cycleCategory(String blockId) {
    final b = findBlock(blockId);
    if (b == null) return;
    b.categoryId = nextCategoryId(b.categoryId);
    notifyListeners();
    save();
  }

  void setCategory(String blockId, String categoryId) {
    final b = findBlock(blockId);
    if (b == null) return;
    b.categoryId = categoryId;
    notifyListeners();
    save();
  }

  void toggleOneTime(String blockId) {
    final b = findBlock(blockId);
    if (b == null) return;
    if (b.oneTime) {
      b.oneTime = false;
      b.expiresAt = null;
    } else {
      b.oneTime = true;
      b.expiresAt = _computeExpiry(blockId).toIso8601String();
    }
    notifyListeners();
    save();
  }

  DateTime _computeExpiry(String blockId) {
    final now = DateTime.now();
    final today0 = DateTime(now.year, now.month, now.day);

    int? dayIdx;
    for (final d in days) {
      if (d.blocks.any((e) => e.id == blockId)) {
        final m = RegExp(r'day_(\d+)').firstMatch(d.id);
        if (m != null) dayIdx = int.tryParse(m.group(1)!);
        break;
      }
    }

    if (dayIdx == null) {
      return today0.add(const Duration(days: 8));
    }

    final todayIdx = now.weekday - 1;
    final daysUntil = (dayIdx - todayIdx + 7) % 7;
    final targetDay = today0.add(Duration(days: daysUntil));
    return targetDay.add(const Duration(days: 1));
  }

  void notifyDirty() {
    notifyListeners();
    save();
  }

  TaskBlock? findBlock(String blockId) {
    for (final d in days) {
      for (final b in d.blocks) {
        if (b.id == blockId) return b;
      }
    }
    for (final p in pools) {
      for (final b in p.blocks) {
        if (b.id == blockId) return b;
      }
    }
    return null;
  }

  List<TaskBlock> _containerBlocks(String type, String id) {
    if (type == 'day') {
      return days.firstWhere((e) => e.id == id).blocks;
    } else {
      return pools.firstWhere((e) => e.id == id).blocks;
    }
  }

  // ---------- 시간 정렬 ----------
  void sortDayByTime(String dayId) {
    final d = days.firstWhere((e) => e.id == dayId);
    d.blocks.sort((a, b) => a.minutes.compareTo(b.minutes));
    notifyListeners();
    save();
  }

  void sortAllDaysByTime() {
    for (final d in days) {
      d.blocks.sort((a, b) => a.minutes.compareTo(b.minutes));
    }
    notifyListeners();
    save();
  }

  void sortPoolByTime(String poolId) {
    final p = pools.firstWhere((e) => e.id == poolId);
    p.blocks.sort((a, b) => a.minutes.compareTo(b.minutes));
    notifyListeners();
    save();
  }

  // ---------- 드래그앤드롭 이동 ----------
  void moveBlock({
    required String blockId,
    required String targetType,
    required String targetId,
    int? targetIndex,
  }) {
    TaskBlock? moving;
    int? sourceIndex;
    List<TaskBlock>? sourceList;

    for (final d in days) {
      final idx = d.blocks.indexWhere((b) => b.id == blockId);
      if (idx != -1) {
        sourceList = d.blocks;
        sourceIndex = idx;
        moving = d.blocks[idx];
        break;
      }
    }
    if (moving == null) {
      for (final p in pools) {
        final idx = p.blocks.indexWhere((b) => b.id == blockId);
        if (idx != -1) {
          sourceList = p.blocks;
          sourceIndex = idx;
          moving = p.blocks[idx];
          break;
        }
      }
    }
    if (moving == null || sourceList == null || sourceIndex == null) return;

    final target = _containerBlocks(targetType, targetId);

    int? insertAt = targetIndex;
    if (identical(sourceList, target) &&
        insertAt != null &&
        insertAt > sourceIndex) {
      insertAt -= 1;
    }

    sourceList.removeAt(sourceIndex);

    if (insertAt == null || insertAt < 0 || insertAt > target.length) {
      target.add(moving);
    } else {
      target.insert(insertAt, moving);
    }

    if (moving.oneTime) {
      moving.expiresAt = _computeExpiry(moving.id).toIso8601String();
    }

    notifyListeners();
    save();
  }

  // ---------- 블록 복사(Ctrl + 드래그 드롭) ----------
  TaskBlock _cloneBlock(TaskBlock src) {
    final newBlockId = _newId();

    final idMap = <String, String>{};
    final newNodes = src.nodes.map((n) {
      final nid = _newId();
      idMap[n.id] = nid;
      return CanvasNode(
        id: nid,
        type: n.type,
        x: n.x,
        y: n.y,
        w: n.w,
        h: n.h,
        title: n.title,
        text: n.text,
        fileName: n.fileName,
        fileData: n.fileData,
      );
    }).toList();

    final newEdges = src.edges
        .map((e) => CanvasEdge(
              fromId: idMap[e.fromId] ?? e.fromId,
              toId: idMap[e.toId] ?? e.toId,
            ))
        .toList();

    return TaskBlock(
      id: newBlockId,
      categoryId: src.categoryId,
      time: src.time,
      title: src.title,
      desc: src.desc,
      oneTime: src.oneTime,
      expiresAt: src.expiresAt,
      completed: false,
      completedAt: null,
      nodes: newNodes,
      edges: newEdges,
    );
  }

  void copyBlockTo({
    required String blockId,
    required String targetType,
    required String targetId,
    int? targetIndex,
  }) {
    final src = findBlock(blockId);
    if (src == null) return;

    final clone = _cloneBlock(src);
    final target = _containerBlocks(targetType, targetId);

    if (targetIndex == null ||
        targetIndex < 0 ||
        targetIndex > target.length) {
      target.add(clone);
    } else {
      target.insert(targetIndex, clone);
    }

    if (clone.oneTime) {
      clone.expiresAt = _computeExpiry(clone.id).toIso8601String();
    }

    notifyListeners();
    save();
  }

  // ---------- 요일 편집 ----------
  void updateDayLabel(String dayId, {String? dayLabel, String? subLabel}) {
    final d = days.firstWhere((e) => e.id == dayId);
    if (dayLabel != null) d.dayLabel = dayLabel;
    if (subLabel != null) d.subLabel = subLabel;
    notifyListeners();
    save();
  }

  // ---------- 보관함 행 ----------
  void addPoolRow() {
    pools.add(PoolRow(id: _newId(), title: '새 카테고리', blocks: []));
    notifyListeners();
    save();
  }

  void deletePoolRow(String poolId) {
    pools.removeWhere((e) => e.id == poolId);
    notifyListeners();
    save();
  }

  void updatePoolTitle(String poolId, String title) {
    final p = pools.firstWhere((e) => e.id == poolId);
    p.title = title;
    notifyListeners();
    save();
  }

  // ---------- 캔버스 노드/엣지 CRUD ----------
  CanvasNode addCanvasNode(String blockId, CanvasNodeType type,
      {double x = 60, double y = 60}) {
    final b = findBlock(blockId)!;
    String defTitle;
    switch (type) {
      case CanvasNodeType.memo:
        defTitle = '메모';
        break;
      case CanvasNodeType.link:
        defTitle = '링크';
        break;
      case CanvasNodeType.file:
        defTitle = '파일';
        break;
      case CanvasNodeType.execute:
        defTitle = '실행';
        break;
    }
    final node = CanvasNode(
      id: _newId(),
      type: type,
      x: snapToGrid(x),
      y: snapToGrid(y),
      title: defTitle,
    );
    b.nodes.add(node);
    notifyListeners();
    save();
    return node;
  }

  void updateCanvasNodePos(String blockId, String nodeId, double x, double y) {
    final b = findBlock(blockId);
    if (b == null) return;
    final n = b.nodes.firstWhere((e) => e.id == nodeId);
    n.x = x < 0 ? 0 : x;
    n.y = y < 0 ? 0 : y;
    notifyListeners();
  }

  void snapCanvasNode(String blockId, String nodeId) {
    final b = findBlock(blockId);
    if (b == null) return;
    final n = b.nodes.firstWhere((e) => e.id == nodeId);
    n.x = snapToGrid(n.x);
    n.y = snapToGrid(n.y);
    notifyListeners();
    save();
  }

  void resizeCanvasNode(String blockId, String nodeId, double w, double h) {
    final b = findBlock(blockId);
    if (b == null) return;
    final n = b.nodes.firstWhere((e) => e.id == nodeId);
    n.w = w < 140 ? 140 : w;
    n.h = h < 100 ? 100 : h;
    notifyListeners();
  }

  void snapCanvasNodeSize(String blockId, String nodeId) {
    final b = findBlock(blockId);
    if (b == null) return;
    final n = b.nodes.firstWhere((e) => e.id == nodeId);
    final sw = snapToGrid(n.w);
    final sh = snapToGrid(n.h);
    n.w = sw < 140 ? 140 : sw;
    n.h = sh < 100 ? 100 : sh;
    notifyListeners();
    save();
  }

  void updateCanvasNode(String blockId, String nodeId,
      {String? title, String? text, String? fileName, String? fileData}) {
    final b = findBlock(blockId);
    if (b == null) return;
    final n = b.nodes.firstWhere((e) => e.id == nodeId);
    if (title != null) n.title = title;
    if (text != null) n.text = text;
    if (fileName != null) n.fileName = fileName;
    if (fileData != null) n.fileData = fileData;
    notifyListeners();
    save();
  }

  void deleteCanvasNode(String blockId, String nodeId) {
    final b = findBlock(blockId);
    if (b == null) return;
    b.nodes.removeWhere((e) => e.id == nodeId);
    b.edges.removeWhere((e) => e.fromId == nodeId || e.toId == nodeId);
    notifyListeners();
    save();
  }

  void addCanvasEdge(String blockId, String fromId, String toId) {
    if (fromId == toId) return;
    final b = findBlock(blockId);
    if (b == null) return;
    final exists =
        b.edges.any((e) => e.fromId == fromId && e.toId == toId);
    if (exists) return;
    b.edges.add(CanvasEdge(fromId: fromId, toId: toId));
    notifyListeners();
    save();
  }

  void deleteCanvasEdge(String blockId, String fromId, String toId) {
    final b = findBlock(blockId);
    if (b == null) return;
    b.edges.removeWhere((e) => e.fromId == fromId && e.toId == toId);
    notifyListeners();
    save();
  }

  void canvasChanged() {
    notifyListeners();
    save();
  }

  List<CanvasNode> connectedTargets(String blockId, String executeNodeId) {
    final b = findBlock(blockId);
    if (b == null) return [];
    final targetIds = b.edges
        .where((e) => e.fromId == executeNodeId)
        .map((e) => e.toId)
        .toSet();
    return b.nodes.where((n) => targetIds.contains(n.id)).toList();
  }

  // ---------- 저장/불러오기 (현재 상태) ----------
  Map<String, dynamic> _toJson() => {
        'version': 1,
        'savedAt': DateTime.now().toIso8601String(),
        'days': days.map((d) => d.toJson()).toList(),
        'pools': pools.map((p) => p.toJson()).toList(),
      };

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_toJson()));
    } catch (e) {
      if (kDebugMode) debugPrint('save error: $e');
    }
  }

  Future<bool> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return false;
      _applyJson(jsonDecode(raw) as Map<String, dynamic>);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('load error: $e');
      return false;
    }
  }

  void _applyJson(Map<String, dynamic> data) {
    final dayList = (data['days'] ?? []) as List;
    final poolList = (data['pools'] ?? []) as List;
    days = dayList
        .map((e) => DayColumn.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    pools = poolList
        .map((e) => PoolRow.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    if (days.isEmpty) _buildDefault();
  }

  Future<bool> reload() async {
    final ok = await _loadFromStorage();
    if (ok) notifyListeners();
    return ok;
  }

  void resetAll() {
    _buildDefault();
    notifyListeners();
    save();
  }

  // ---------- 다중 프리셋 ----------
  Future<Map<String, dynamic>> _readAllPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_presetKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw));
    } catch (_) {
      return {};
    }
  }

  Future<void> _loadPresetNames() async {
    final all = await _readAllPresets();
    presetNames = all.keys.toList()..sort();
  }

  Future<void> savePreset(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final all = await _readAllPresets();
    all[trimmed] = _toJson();
    await prefs.setString(_presetKey, jsonEncode(all));
    await _loadPresetNames();
    notifyListeners();
  }

  Future<bool> loadPreset(String name) async {
    final all = await _readAllPresets();
    final data = all[name];
    if (data == null) return false;
    _applyJson(Map<String, dynamic>.from(data));
    notifyListeners();
    save();
    return true;
  }

  Future<void> deletePreset(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _readAllPresets();
    all.remove(name);
    await prefs.setString(_presetKey, jsonEncode(all));
    await _loadPresetNames();
    notifyListeners();
  }
}
