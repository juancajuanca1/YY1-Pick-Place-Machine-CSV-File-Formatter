/// A source-format-agnostic representation of a delimited placement file.
class TabularRow {
  final List<String> cells;
  final int originalLineIndex;

  const TabularRow({required this.cells, required this.originalLineIndex});

  String operator [](int i) => (i >= 0 && i < cells.length) ? cells[i].trim() : '';
  int get length => cells.length;
}

class TabularDocument {
  final String fileName;
  final List<String> headers; // lowercased, trimmed
  final List<String> originalHeaders; // raw header strings
  final List<TabularRow> rows;
  final String delimiter;
  final List<String> rawLines;

  const TabularDocument({
    required this.fileName,
    required this.headers,
    required this.originalHeaders,
    required this.rows,
    required this.delimiter,
    required this.rawLines,
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
