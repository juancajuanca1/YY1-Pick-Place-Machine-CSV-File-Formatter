import 'board_side.dart';

/// A source-format-agnostic representation of a delimited placement file.
class TabularRow {
  final List<String> cells;
  final int originalLineIndex;

  const TabularRow({required this.cells, required this.originalLineIndex});

  String operator [](int i) =>
      (i >= 0 && i < cells.length) ? cells[i].trim() : '';
  int get length => cells.length;
}

class TabularDocument {
  final String fileName;
  final List<String> headers; // lowercased, trimmed
  final List<String> originalHeaders; // raw header strings
  final List<TabularRow> rows;
  final String delimiter;
  final List<String> rawLines;

  /// Side inferred from a vendor filename such as *_front.csv or *_bottom.pos.
  final BoardSide inferredSide;

  /// True when the source had no header and canonical headers were synthesized.
  final bool hasSyntheticHeaders;

  const TabularDocument({
    required this.fileName,
    required this.headers,
    required this.originalHeaders,
    required this.rows,
    required this.delimiter,
    required this.rawLines,
    this.inferredSide = BoardSide.unknown,
    this.hasSyntheticHeaders = false,
  });

  int get columnCount => headers.length;
  int get rowCount => rows.length;

  /// Sample up to [n] values from column [colIndex] for semantic inference.
  List<String> sampleColumn(int colIndex, {int n = 20}) {
    return rows
        .where((r) => colIndex < r.length)
        .take(n)
        .map((r) => r[colIndex])
        .where((v) => v.isNotEmpty)
        .toList();
  }
}
