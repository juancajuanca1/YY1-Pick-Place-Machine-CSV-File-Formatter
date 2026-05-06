import '../models/tabular_document.dart';

/// Converts raw file text into a TabularDocument.
/// Handles comma, tab, and semicolon delimiters, comment lines, and BOM.
class FileIngestor {
  static TabularDocument ingest({
    required String content,
    required String fileName,
  }) {
    // Strip BOM
    var text = content;
    if (text.startsWith('\uFEFF')) text = text.substring(1);

    final rawLines = text.split(RegExp(r'\r?\n'));

    // Skip leading comment/blank lines; also skip YY1 machine-metadata rows
    // (NEODEN header, PanelizedPCB, Fiducial, NozzleChange etc.) by looking
    // for the first line that contains "designator" – the actual data header.
    final nonCommentLines = rawLines
        .where((l) => l.trim().isNotEmpty && !l.trim().startsWith('#'))
        .toList();

    if (nonCommentLines.isEmpty) {
      return TabularDocument(
        fileName: fileName,
        headers: [],
        originalHeaders: [],
        rows: [],
        delimiter: ',',
        rawLines: rawLines,
      );
    }

    // Find the header row: prefer the first line containing "designator"
    // (case-insensitive). Falls back to the very first non-comment line.
    String headerRaw = nonCommentLines.first;
    for (final line in nonCommentLines) {
      if (line.toLowerCase().contains('designator')) {
        headerRaw = line;
        break;
      }
    }
    final delimiter = _detectDelimiter(headerRaw);

    final originalHeaders = _splitLine(headerRaw, delimiter);
    final headers = originalHeaders.map((h) => h.toLowerCase().trim()).toList();

    // Find the raw-line index of the header so we only take rows below it
    int headerRawIndex = rawLines.indexWhere((l) => l == headerRaw);
    if (headerRawIndex < 0) headerRawIndex = 0;

    // Build rows from lines strictly after the header
    final rows = <TabularRow>[];
    for (int i = headerRawIndex + 1; i < rawLines.length; i++) {
      final raw = rawLines[i].trim();
      if (raw.isEmpty || raw.startsWith('#')) continue;
      final cells = _splitLine(raw, delimiter);
      if (cells.every((c) => c.trim().isEmpty)) continue;
      rows.add(TabularRow(cells: cells, originalLineIndex: i));
    }

    return TabularDocument(
      fileName: fileName,
      headers: headers,
      originalHeaders: originalHeaders,
      rows: rows,
      delimiter: delimiter,
      rawLines: rawLines,
    );
  }

  static String _detectDelimiter(String line) {
    final counts = {
      ',': _countOutsideQuotes(line, ','),
      '\t': _countOutsideQuotes(line, '\t'),
      ';': _countOutsideQuotes(line, ';'),
    };
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  static int _countOutsideQuotes(String line, String ch) {
    int count = 0;
    bool inQ = false;
    for (int i = 0; i < line.length; i++) {
      if (line[i] == '"') inQ = !inQ;
      if (!inQ && line[i] == ch) count++;
    }
    return count;
  }

  static List<String> _splitLine(String line, String delimiter) {
    final result = <String>[];
    final buf = StringBuffer();
    bool inQ = false;
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQ = !inQ;
      } else if (!inQ && line.substring(i, i + delimiter.length) == delimiter) {
        result.add(buf.toString().trim());
        buf.clear();
        i += delimiter.length - 1;
      } else {
        buf.write(ch);
      }
    }
    result.add(buf.toString().trim());
    return result;
  }
}
