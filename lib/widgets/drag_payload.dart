/// 드래그되는 블록의 정보
class DragPayload {
  final String blockId;

  /// true 면 복사, false 면 이동 (기본값: 이동)
  final bool copy;

  const DragPayload(this.blockId, {this.copy = false});
}
