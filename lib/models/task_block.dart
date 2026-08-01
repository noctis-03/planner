/// 시간 문자열을 파싱해서 "분" 단위 정수로 변환.
/// 정렬 불가(시간 없음/형식 미상)면 매우 큰 값 반환 → 맨 뒤로.
int parseTimeToMinutes(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return 1 << 30;
  int h;
  int m;
  if (digits.length <= 2) {
    // "9" -> 9시, "18" -> 18시
    h = int.tryParse(digits) ?? 0;
    m = 0;
  } else if (digits.length == 3) {
    // "930" -> 9:30
    h = int.tryParse(digits.substring(0, 1)) ?? 0;
    m = int.tryParse(digits.substring(1)) ?? 0;
  } else {
    // "1850" -> 18:50 (앞 4자리 사용)
    h = int.tryParse(digits.substring(0, 2)) ?? 0;
    m = int.tryParse(digits.substring(2, 4)) ?? 0;
  }
  if (h > 23) h = 23;
  if (m > 59) m = 59;
  return h * 60 + m;
}

/// 사용자가 입력한 "0000" / "1850" / "9" 등을 "00:00" 형태로 자동 포맷.
/// 숫자가 하나도 없으면 원본 그대로 반환(예: "시간", "오전").
String autoFormatTime(String raw) {
  final trimmed = raw.trim();
  final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return trimmed;
  int h;
  int m;
  if (digits.length <= 2) {
    h = int.tryParse(digits) ?? 0;
    m = 0;
  } else if (digits.length == 3) {
    h = int.tryParse(digits.substring(0, 1)) ?? 0;
    m = int.tryParse(digits.substring(1)) ?? 0;
  } else {
    h = int.tryParse(digits.substring(0, 2)) ?? 0;
    m = int.tryParse(digits.substring(2, 4)) ?? 0;
  }
  if (h > 23) h = 23;
  if (m > 59) m = 59;
  final hh = h.toString().padLeft(2, '0');
  final mm = m.toString().padLeft(2, '0');
  return '$hh:$mm';
}

/// 캔버스 노드 종류
enum CanvasNodeType { memo, link, file, execute }

CanvasNodeType canvasNodeTypeFromString(String s) {
  switch (s) {
    case 'link':
      return CanvasNodeType.link;
    case 'file':
      return CanvasNodeType.file;
    case 'execute':
      return CanvasNodeType.execute;
    case 'memo':
    default:
      return CanvasNodeType.memo;
  }
}

String canvasNodeTypeToString(CanvasNodeType t) => t.name;

/// 캔버스 그리드 크기 (스냅 단위)
const double kCanvasGrid = 20.0;

/// 값을 그리드에 스냅
double snapToGrid(double v) => (v / kCanvasGrid).round() * kCanvasGrid;

/// 무한 캔버스의 노드
class CanvasNode {
  String id;
  CanvasNodeType type;
  double x;
  double y;
  double w;
  double h;
  String title;

  /// memo: 본문 텍스트 / link: URL / file: (설명)
  String text;

  /// file 노드 전용: 파일명 + 데이터(base64) 또는 경로
  String fileName;
  String fileData; // web: base64 dataURL, desktop: 파일 경로

  CanvasNode({
    required this.id,
    required this.type,
    this.x = 40,
    this.y = 40,
    this.w = 200,
    this.h = 140,
    this.title = '',
    this.text = '',
    this.fileName = '',
    this.fileData = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': canvasNodeTypeToString(type),
        'x': x,
        'y': y,
        'w': w,
        'h': h,
        'title': title,
        'text': text,
        'fileName': fileName,
        'fileData': fileData,
      };

  factory CanvasNode.fromJson(Map<String, dynamic> j) => CanvasNode(
        id: (j['id'] ?? '').toString(),
        type: canvasNodeTypeFromString((j['type'] ?? 'memo').toString()),
        x: (j['x'] is num) ? (j['x'] as num).toDouble() : 40,
        y: (j['y'] is num) ? (j['y'] as num).toDouble() : 40,
        w: (j['w'] is num) ? (j['w'] as num).toDouble() : 200,
        h: (j['h'] is num) ? (j['h'] as num).toDouble() : 140,
        title: (j['title'] ?? '').toString(),
        text: (j['text'] ?? '').toString(),
        fileName: (j['fileName'] ?? '').toString(),
        fileData: (j['fileData'] ?? '').toString(),
      );
}

/// 노드 간 연결선 (fromNode 출력포트 → toNode 입력포트)
class CanvasEdge {
  String fromId;
  String toId;

  CanvasEdge({required this.fromId, required this.toId});

  Map<String, dynamic> toJson() => {'from': fromId, 'to': toId};

  factory CanvasEdge.fromJson(Map<String, dynamic> j) => CanvasEdge(
        fromId: (j['from'] ?? '').toString(),
        toId: (j['to'] ?? '').toString(),
      );
}

/// 일정 블록 데이터 모델
class TaskBlock {
  String id;
  String categoryId;
  String time;
  String title;
  String desc;

  /// 일회용(임시) 블록 여부. 해당 요일의 "오늘"이 지나면 자동 삭제.
  bool oneTime;

  /// 일회용 블록의 만료 시각(ISO8601). 이 시각을 지나면 삭제.
  /// null이면 만료 없음(일반 블록).
  String? expiresAt;

  /// 완료 처리됨 여부
  bool completed;

  /// 완료 처리한 시각(ISO8601). 이 시각의 "다음 날 00:00" 이후엔 자동 해제.
  String? completedAt;

  /// 무한 캔버스 노드/엣지 (더블클릭 워크스페이스)
  List<CanvasNode> nodes;
  List<CanvasEdge> edges;

  TaskBlock({
    required this.id,
    this.categoryId = 'empty',
    this.time = '',
    this.title = '새 일정',
    this.desc = '',
    this.oneTime = false,
    this.expiresAt,
    this.completed = false,
    this.completedAt,
    List<CanvasNode>? nodes,
    List<CanvasEdge>? edges,
  })  : nodes = nodes ?? [],
        edges = edges ?? [];

  /// 만료 시각을 지났는지 (now 기준)
  bool isExpired(DateTime now) {
    if (!oneTime || expiresAt == null) return false;
    final exp = DateTime.tryParse(expiresAt!);
    if (exp == null) return false;
    return !now.isBefore(exp); // now >= exp
  }

  /// 완료 표시가 자동 해제되어야 하는지 (완료한 다음날 00:00 지났는지)
  bool shouldClearCompletion(DateTime now) {
    if (!completed || completedAt == null) return false;
    final at = DateTime.tryParse(completedAt!);
    if (at == null) return false;
    // 완료한 날의 다음날 00:00
    final nextDay0 =
        DateTime(at.year, at.month, at.day).add(const Duration(days: 1));
    return !now.isBefore(nextDay0);
  }

  /// 정렬용 분 단위 시간
  int get minutes => parseTimeToMinutes(time);

  /// 캔버스에 내용이 있는지 (배지 표시용)
  bool get hasCanvas => nodes.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'cat': categoryId,
        'time': time,
        'title': title,
        'desc': desc,
        'oneTime': oneTime,
        'expiresAt': expiresAt,
        'completed': completed,
        'completedAt': completedAt,
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'edges': edges.map((e) => e.toJson()).toList(),
      };

  factory TaskBlock.fromJson(Map<String, dynamic> json) {
    return TaskBlock(
      id: (json['id'] ?? DateTime.now().microsecondsSinceEpoch.toString())
          .toString(),
      categoryId: (json['cat'] ?? 'empty').toString(),
      time: (json['time'] ?? '').toString(),
      title: (json['title'] ?? '새 일정').toString(),
      desc: (json['desc'] ?? '').toString(),
      oneTime: json['oneTime'] == true,
      expiresAt: json['expiresAt']?.toString(),
      completed: json['completed'] == true,
      completedAt: json['completedAt']?.toString(),
      nodes: ((json['nodes'] ?? []) as List)
          .map((e) => CanvasNode.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      edges: ((json['edges'] ?? []) as List)
          .map((e) => CanvasEdge.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  TaskBlock copyWith({
    String? id,
    String? categoryId,
    String? time,
    String? title,
    String? desc,
    bool? oneTime,
    String? expiresAt,
    bool? completed,
    String? completedAt,
  }) {
    return TaskBlock(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      time: time ?? this.time,
      title: title ?? this.title,
      desc: desc ?? this.desc,
      oneTime: oneTime ?? this.oneTime,
      expiresAt: expiresAt ?? this.expiresAt,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
      nodes: nodes,
      edges: edges,
    );
  }
}

/// 요일 컬럼 (하루)
class DayColumn {
  String id;
  String dayLabel; // 예: 월요일
  String subLabel; // 예: 메모/부제
  List<TaskBlock> blocks;

  DayColumn({
    required this.id,
    required this.dayLabel,
    this.subLabel = '',
    List<TaskBlock>? blocks,
  }) : blocks = blocks ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'dayLabel': dayLabel,
        'subLabel': subLabel,
        'blocks': blocks.map((b) => b.toJson()).toList(),
      };

  factory DayColumn.fromJson(Map<String, dynamic> json) {
    return DayColumn(
      id: (json['id'] ?? '').toString(),
      dayLabel: (json['dayLabel'] ?? '요일').toString(),
      subLabel: (json['subLabel'] ?? '').toString(),
      blocks: ((json['blocks'] ?? []) as List)
          .map((e) => TaskBlock.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

/// 보관함 행 (카테고리별 후보 담아두기)
class PoolRow {
  String id;
  String title;
  List<TaskBlock> blocks;

  PoolRow({
    required this.id,
    required this.title,
    List<TaskBlock>? blocks,
  }) : blocks = blocks ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'blocks': blocks.map((b) => b.toJson()).toList(),
      };

  factory PoolRow.fromJson(Map<String, dynamic> json) {
    return PoolRow(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '보관함').toString(),
      blocks: ((json['blocks'] ?? []) as List)
          .map((e) => TaskBlock.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
