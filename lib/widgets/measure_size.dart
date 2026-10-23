import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Tells its parent how big its child turned out to be, each time that size
/// changes (reported right after the frame, never during layout).
class MeasureSize extends SingleChildRenderObjectWidget {
  const MeasureSize({
    super.key,
    required this.onChange,
    required Widget super.child,
  });

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureSize(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderMeasureSize renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _RenderMeasureSize extends RenderProxyBox {
  _RenderMeasureSize(this.onChange);

  ValueChanged<Size> onChange;
  Size? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final measured = child?.size ?? Size.zero;
    if (measured == _reported) return;
    _reported = measured;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(measured));
  }
}
