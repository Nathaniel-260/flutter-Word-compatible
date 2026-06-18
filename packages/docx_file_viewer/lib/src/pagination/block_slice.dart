import 'package:docx_creator/docx_creator.dart';

/// One block placed on a page by the paginator (Plan §D.1).
///
/// A slice holds either a whole AST [block] (shared by reference) or a
/// **lightweight sub-block** produced when a paragraph/table straddles a page
/// boundary. The sub-block is a `copyWith` of the original that reuses every
/// non-boundary inline/row by reference and clones only the boundary run/row —
/// so a split costs O(1) small allocations, not a clone of the inline tree
/// (conscious deviation from the pure range model of §2.4.1, documented in
/// §8.2 #13). Either way the renderer just renders [block] directly.
class BlockSlice {
  const BlockSlice(this.block, this.height, {this.columnIndex = 0});

  /// The AST node to render: a whole document block, or a sliced sub-block
  /// (see the class doc). Shared by reference; never mutated.
  final DocxNode block;

  /// Measured height of this slice in logical pixels. A split head carries the
  /// block's before-spacing (not its after-spacing); a split tail carries the
  /// after-spacing (not the before-spacing).
  final double height;

  /// 0-based column index within the page (Plan §I). Zero for single-column
  /// pages and for the first column in multi-column layouts.
  final int columnIndex;

  BlockSlice copyWith({double? height, int? columnIndex}) => BlockSlice(
        block,
        height ?? this.height,
        columnIndex: columnIndex ?? this.columnIndex,
      );

  @override
  String toString() =>
      'BlockSlice(${block.runtimeType} h=${height.toStringAsFixed(1)} col=$columnIndex)';
}
