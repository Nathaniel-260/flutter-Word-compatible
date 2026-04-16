import '../css_style.dart';
import '../render_node.dart';

/// Resolved constraints mapping down to Points (pt).
class BoxConstraints {
  final double? width;
  final double? height;

  const BoxConstraints({this.width, this.height});
}

/// A node in the layout tree.
/// It wraps a RenderNode with explicitly resolved CSS properties
/// such as calculated constraints (width/height), margins, and exact displays.
class LayoutNode {
  final RenderNode originalNode;
  final CSSStyle computedStyle;
  final BoxConstraints constraints;
  final List<LayoutNode> children;

  LayoutNode({
    required this.originalNode,
    required this.computedStyle,
    required this.constraints,
    List<LayoutNode>? children,
  }) : children = children ?? [];

  String get tagName => originalNode.tagName;
  String? get text => originalNode.text;
  Display get display => computedStyle.display ?? originalNode.display;
  Map<String, String> get attributes => originalNode.attributes;
  CSSStyle get style => computedStyle;
}
