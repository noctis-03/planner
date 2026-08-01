import 'dart:convert';
import 'package:flutter/foundation.dart';
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

  int _idCounter = 0;

  String _newId() {
    _idCounter++;
    return '${DateTime.now().microsecondsSinceEpoch}_$_idCounter';
  }

  String newId() => _newId();

  // ---------- 초기화 ----------
  Future<void> init() async {
    final loaded = await _loadFromStorage();
    if (!loaded) {
      _buildDefault();
    }
    // 앱을 껐다 켜도 날짜 기준으로 만료된 일회용 블록 자동 정리 +
    // 완료 표시 자동 해제 처리
    final changed = _purgeExpired(DateTime.now());
    await _loadPresetNames();
    notifyListeners();
    if (changed > 0) save();
  }

  /// 만료된 일회용 블록 제거 + 완료 표시 자동 해제. 변경된 개수 반환.
  int _purgeExpired(DateTime now) {
    int count = 0;
    for (final d in days) {
      final before = d.blocks.length;
      d.blocks.removeWhere((b) => b.isExpired(now));
      count += before - d.blocks.length;
      // 완료 표시 자동 해제 (완료한 날의 다음날 00:00 이후)
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

  /// 외부(주기적 타이머 등)에서 만료 정리를 트리거
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
      // expiry 계산은 블록이 days에 들어간 뒤 다시
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

  /// X 버튼 동작:
  ///  - 일회용 블록: 즉시 삭제
  ///  - 완료되지 않은 일반 블록: 완료 표시로 전환
  ///  - 이미 완료된 블록: 삭제
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

  /// 일회용(임시) 블록 토글.
  /// 켜면: 이 블록이 놓인 요일의 "오늘"이 지나는 시점(다음 날 00:00)을 만료로 설정.
  /// 요일 컬럼이 아닌 보관함에 있으면 배치 시점 기준 7일 뒤 만료(대략).
  void toggleOneTime(String blockId) {
    final b = findBlock(blockId);
    if (b == null) return;
    if (b.oneTime) {
      // 해제
      b.oneTime = false;
      b.expiresAt = null;
    } else {
      b.oneTime = true;
      b.expiresAt = _computeExpiry(blockId).toIso8601String();
    }
    notifyListeners();
    save();
  }

  /// 블록이 놓인 요일 인덱스를 찾아 만료 시점을 계산.
  /// day_i (월=0..일=6). 오늘 포함 가장 가까운 해당 요일의 "다음 날 00:00"이 만료.
  DateTime _computeExpiry(String blockId) {
    final now = DateTime.now();
    final today0 = DateTime(now.year, now.month, now.day);

    // 이 블록이 속한 요일 인덱스 탐색
    int? dayIdx;
    for (final d in days) {
      if (d.blocks.any((e) => e.id == blockId)) {
        // day_0 .. day_6 형태에서 인덱스 파싱
        final m = RegExp(r'day_(\d+)').firstMatch(d.id);
        if (m != null) dayIdx = int.tryParse(m.group(1)!);
        break;
      }
    }

    if (dayIdx == null) {
      // 보관함 등: 배치 후 7일간 유지
      return today0.add(const Duration(days: 8));
    }

    // 오늘의 요일 인덱스 (월=0)
    final todayIdx = now.weekday - 1;
    // 오늘 포함, 앞으로 해당 요일까지 남은 일수 (0~6)
    final daysUntil = (dayIdx - todayIdx + 7) % 7;
    // 그 요일 당일 자정 + 1일 = "오늘 표시가 떨어지는 시점"
    final targetDay = today0.add(Duration(days: daysUntil));
    return targetDay.add(const Duration(days: 1));
  }

  /// 외부에서 직접 데이터 수정 후 갱신용
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
  /// 특정 요일 블록을 시간 순으로 정렬 (시간 없는 블록은 뒤로)
  void sortDayByTime(String dayId) {
    final d = days.firstWhere((e) => e.id == dayId);
    d.blocks.sort((a, b) => a.minutes.compareTo(b.minutes));
    notifyListeners();
    save();
  }

  /// 모든 요일 블록 시간 순 정렬
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

    // 같은 리스트 내 이동일 때 인덱스 보정
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

    // 일회용 블록이 다른 위치로 이동하면 만료 시점을 새 요일 기준으로 재계산
    if (moving.oneTime) {
      moving.expiresAt = _computeExpiry(moving.id).toIso8601String();
    }

    notifyListeners();
    save();
  }

  // ---------- 블록 복사(Ctrl + 드래그 드롭) ----------
  /// 블록을 완전히 복제(캔버스 노드/엣지까지). 새 ID 부여.
  TaskBlock _cloneBlock(TaskBlock src) {
    final newBlockId = _newId();

    // 노드 ID 재발급 매핑
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
      // 복사본은 완료 상태를 리셋 (새 블록이니까)
      completed: false,
      completedAt: null,
      nodes: newNodes,
      edges: newEdges,
    );
  }

  /// 블록을 지정 위치에 "복사"해서 삽입 (원본은 그대로).
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

    // 일회용 복사본이면 새 위치 기준으로 만료 재계산
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
    // 위치는 자주 바뀌므로 save는 드래그 종료 시점에만
  }

  /// 드래그 종료 시 그리드에 스냅 + 저장
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
    final exists = b.edges
        .any((e) => e.fromId == fromId && e.toId == toId);
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

  /// execute 노드에 연결된 하위 노드들 반환 (실행 대상)
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

  /// 현재 상태를 이름으로 저장
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

  /// 프리셋 불러오기 (현재 상태 덮어씀)
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
