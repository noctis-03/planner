import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 자식을 [scale] 배로 스케일해서 그리고,
/// 자식의 자연 크기에 [scale] 을 곱한 크기를 자기 자신의 크기로 사용한다.
/// → 카드의 가로세로 비율이 유지되면서, 부모 레이아웃은 스케일된 실제 크기를 반영.
class ZoomedBox extends SingleChildRenderObjectWidget {
  final double scale;

  const ZoomedBox({
    super.key,
    required this.scale,
    required Widget super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderZoomedBox(scale: scale);

  @override
  void updateRenderObject(BuildContext context, _RenderZoomedBox renderObject) {
    renderObject.scale = scale;
  }
}

class _RenderZoomedBox extends RenderShiftedBox {
  double _scale;

  _RenderZoomedBox({required double scale})
      : _scale = scale,
        super(null);

  double get scale => _scale;
  set scale(double v) {
    if (_scale == v) return;
    _scale = v;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    // 자식은 원본 크기로 레이아웃. 부모 제약을 zoom 으로 나눠서 넘겨줌 →
    // zoom>1 이면 자식이 더 큰 공간 안에서 원본 크기로 잡히고,
    // zoom<1 이면 자식이 더 작은 공간 안에서 원본 크기로 잡힘.
    final childConstraints = BoxConstraints(
      minWidth: constraints.minWidth / _scale,
      maxWidth: constraints.maxWidth == double.infinity
          ? double.infinity
          : constraints.maxWidth / _scale,
      minHeight: constraints.minHeight / _scale,
      maxHeight: constraints.maxHeight == double.infinity
          ? double.infinity
          : constraints.maxHeight / _scale,
    );
    child.layout(childConstraints, parentUsesSize: true);

    final childSize = child.size;
    final scaledWidth = childSize.width * _scale;
    final scaledHeight = childSize.height * _scale;

    size = constraints.constrain(Size(scaledWidth, scaledHeight));

    final data = child.parentData! as BoxParentData;
    data.offset = Offset.zero;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final transform = Matrix4.identity()..scale(_scale, _scale, 1);
    context.pushTransform(needsCompositing, offset, transform,
        (PaintingContext ctx, Offset off) {
      ctx.paintChild(child, off);
    });
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = this.child;
    if (child == null) return false;
    return result.addWithPaintTransform(
      transform: Matrix4.identity()..scale(_scale, _scale, 1),
      position: position,
      hitTest: (BoxHitTestResult res, Offset transformed) {
        return child.hitTest(res, position: transformed);
      },
    );
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    transform.scale(_scale, _scale, 1);
  }
}
