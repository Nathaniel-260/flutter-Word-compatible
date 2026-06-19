/// Tracks the running block index so search-match highlighting and the search
/// index ([DocxWidgetGenerator.extractTextForSearch]) stay aligned: both walk
/// blocks in the same order and bump the counter once per paragraph / list item
/// / table-cell paragraph.
///
/// A lazily-built page (Plan §M.1) seeds the counter at its first body block so
/// the right matches inject without rebuilding earlier pages. Navigation no
/// longer uses per-block [GlobalKey]s — it scrolls to the match's *page*
/// (block→page map) — so this no longer holds a key registry (which cost RAM and
/// broke virtualization).
class BlockIndexCounter {
  BlockIndexCounter([this._value = 0]);

  int _value;

  int get value => _value;

  void increment() => _value++;
}
