import 'package:flutter/material.dart';

/// 일정 카테고리 정의 (주간 일정용) - 미니멀 플랫 대응
class TaskCategory {
  final String id;
  final String label;

  /// 좌측 accent 바 / 점 색 (플랫, 차분한 채도)
  final Color color;

  /// 카드 내부 은은한 배경 틴트 (아주 연함)
  final Color tint;

  const TaskCategory({
    required this.id,
    required this.label,
    required this.color,
    required this.tint,
  });
}

/// 카테고리 목록 (순환 순서 유지) - 미니멀 파스텔/뮤트 톤
const List<TaskCategory> kCategories = [
  TaskCategory(
    id: 'empty',
    label: '없음',
    color: Color(0xFFB0B7C3),
    tint: Color(0xFFF4F5F7),
  ),
  TaskCategory(
    id: 'work',
    label: '업무',
    color: Color(0xFF3B82F6), // 블루
    tint: Color(0xFFEFF5FF),
  ),
  TaskCategory(
    id: 'meeting',
    label: '회의',
    color: Color(0xFFF97316), // 오렌지
    tint: Color(0xFFFFF3EA),
  ),
  TaskCategory(
    id: 'study',
    label: '공부',
    color: Color(0xFF8B5CF6), // 퍼플
    tint: Color(0xFFF5F0FF),
  ),
  TaskCategory(
    id: 'exercise',
    label: '운동',
    color: Color(0xFF10B981), // 그린
    tint: Color(0xFFEBFBF4),
  ),
  TaskCategory(
    id: 'appointment',
    label: '약속',
    color: Color(0xFFEC4899), // 핑크
    tint: Color(0xFFFDF0F7),
  ),
  TaskCategory(
    id: 'rest',
    label: '휴식',
    color: Color(0xFF06B6D4), // 청록
    tint: Color(0xFFEAFAFD),
  ),
  TaskCategory(
    id: 'etc',
    label: '기타',
    color: Color(0xFF64748B), // 슬레이트
    tint: Color(0xFFF1F3F6),
  ),
];

TaskCategory categoryById(String id) {
  return kCategories.firstWhere(
    (c) => c.id == id,
    orElse: () => kCategories.first,
  );
}

/// 다음 카테고리 id 반환 (순환)
String nextCategoryId(String currentId) {
  final idx = kCategories.indexWhere((c) => c.id == currentId);
  final nextIdx = (idx + 1) % kCategories.length;
  return kCategories[nextIdx].id;
}
