import 'package:flutter/material.dart';

/// 일정 카테고리 정의 (주간 일정용) - 파스텔 톤 (더 진하게)
class TaskCategory {
  final String id;
  final String label;

  /// 좌측 accent 바 / 점 색 (파스텔, 진한 채도)
  final Color color;

  /// 카드 내부 은은한 배경 틴트
  final Color tint;

  const TaskCategory({
    required this.id,
    required this.label,
    required this.color,
    required this.tint,
  });
}

/// 카테고리 목록 (순환 순서 유지) - 파스텔 팔레트 (더 진하게)
const List<TaskCategory> kCategories = [
  TaskCategory(
    id: 'empty',
    label: '없음',
    color: Color(0xFFA6AEBD),
    tint: Color(0xFFF4F5F8),
  ),
  TaskCategory(
    id: 'work',
    label: '업무',
    color: Color(0xFF5285D1), // 파스텔 블루 (진하게)
    tint: Color(0xFFE8F0FA),
  ),
  TaskCategory(
    id: 'meeting',
    label: '회의',
    color: Color(0xFFEA8646), // 파스텔 피치 오렌지 (진하게)
    tint: Color(0xFFFBEBDD),
  ),
  TaskCategory(
    id: 'study',
    label: '공부',
    color: Color(0xFF8A6BD1), // 파스텔 라벤더 (진하게)
    tint: Color(0xFFEEE8F8),
  ),
  TaskCategory(
    id: 'exercise',
    label: '운동',
    color: Color(0xFF4FAE7C), // 파스텔 민트 그린 (진하게)
    tint: Color(0xFFE3F2EA),
  ),
  TaskCategory(
    id: 'appointment',
    label: '약속',
    color: Color(0xFFE56F92), // 파스텔 핑크 (진하게)
    tint: Color(0xFFFBE6ED),
  ),
  TaskCategory(
    id: 'rest',
    label: '휴식',
    color: Color(0xFF4FA8B5), // 파스텔 스카이 청록 (진하게)
    tint: Color(0xFFE3F1F4),
  ),
  TaskCategory(
    id: 'etc',
    label: '기타',
    color: Color(0xFF747F91), // 파스텔 슬레이트 (진하게)
    tint: Color(0xFFEEF0F4),
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