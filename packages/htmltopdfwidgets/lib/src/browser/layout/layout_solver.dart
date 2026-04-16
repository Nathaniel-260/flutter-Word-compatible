import '../css_style.dart';
import '../render_node.dart';
import 'layout_node.dart';
import 'unit_converter.dart';

class LayoutSolver {
  /// Solves the layout tree from a RenderNode root.
  LayoutNode solve(RenderNode root) {
    return _resolveNode(root, parentWidth: null);
  }

  LayoutNode _resolveNode(RenderNode node, {double? parentWidth}) {
    // 1. Resolve explicit width/height parameters from the computed style
    double? resolvedWidth;
    if (node.style.width != null) {
      resolvedWidth =
          node.style.width; // Already converted to Pt by UnitConverter
    } else {
      // Check legacy attributes
      final widthAttr = node.attributes['width'];
      if (widthAttr != null) {
        resolvedWidth = UnitConverter.parseAndConvertToPt(widthAttr,
            parentWidth: parentWidth);
      }
    }

    double? resolvedHeight;
    if (node.style.height != null) {
      resolvedHeight = node.style.height; // Already in Pt
    } else {
      final heightAttr = node.attributes['height'];
      if (heightAttr != null) {
        resolvedHeight = UnitConverter.parseAndConvertToPt(
            heightAttr); // no parentHeight context typically
      }
    }

    final constraints =
        BoxConstraints(width: resolvedWidth, height: resolvedHeight);

    // 2. Resolve children recursively
    final resolvedChildren = node.children
        .map((child) =>
            _resolveNode(child, parentWidth: resolvedWidth ?? parentWidth))
        .toList();

    return LayoutNode(
      originalNode: node,
      computedStyle: node.style
          .merge(CSSStyle(width: resolvedWidth, height: resolvedHeight)),
      constraints: constraints,
      children: resolvedChildren,
    );
  }
}
