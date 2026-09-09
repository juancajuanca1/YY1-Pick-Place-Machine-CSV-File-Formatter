import '../models/tabular_document.dart';
import '../models/board_side.dart';

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

    // Find an explicit header. YY1 files can have a metadata preamble, while
    // Fusion 360/EAGLE may export six-column placement data with no header.
    String headerRaw = nonCommentLines.first;
    var foundExplicitHeader = false;
    for (final line in nonCommentLines) {
      if (_looksLikeHeader(line)) {
        headerRaw = line;
        foundExplicitHeader = true;
        break;
      }
    }
    final delimiter = _detectDelimiter(
      foundExplicitHeader ? headerRaw : nonCommentLines.first,
    );

    final firstCells = _splitLine(nonCommentLines.first, delimiter);
    final isHeaderlessPlacement =
        !foundExplicitHeader && _looksLikePlacementRow(firstCells);

    final originalHeaders = isHeaderlessPlacement
        ? _syntheticHeaders(firstCells.length)
        : _splitLine(headerRaw, delimiter);
    final headers = originalHeaders.map((h) => h.toLowerCase().trim()).toList();

    // Find the raw-line index of the header so we only take rows below it
    int headerRawIndex = isHeaderlessPlacement
        ? rawLines.indexWhere((l) => l == nonCommentLines.first) - 1
        : rawLines.indexWhere((l) => l == headerRaw);
    if (headerRawIndex < 0 && !isHeaderlessPlacement) headerRawIndex = 0;

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
      inferredSide: _inferSideFromFileName(fileName),
      hasSyntheticHeaders: isHeaderlessPlacement,
    );
  }

  static bool _looksLikeHeader(String line) {
    final lower = line.toLowerCase();
    const terms = [
      'designator',
      'reference',
      'refdes',
      'mid x',
      'posx',
      'center x',
      'rotation',
      'orientation',
      'footprint',
      'package',
    ];
    return terms.where(lower.contains).length >= 2 ||
        lower.contains('designator');
  }

  static bool _looksLikePlacementRow(List<String> cells) {
    if (cells.length < 4) return false;
    final designator = RegExp(r'^[A-Za-z]{1,6}\d+[A-Za-z]?$');
    return designator.hasMatch(cells[0].trim()) &&
        double.tryParse(cells[1].trim()) != null &&
        double.tryParse(cells[2].trim()) != null &&
        double.tryParse(cells[3].trim()) != null;
  }

  static List<String> _syntheticHeaders(int count) {
    const fusionOrder = [
      'Designator',
      'X',
      'Y',
      'Rotation',
      'Value',
      'Footprint',
    ];
    return List.generate(
      count,
      (i) => i < fusionOrder.length ? fusionOrder[i] : 'Column ${i + 1}',
    );
  }

  static BoardSide _inferSideFromFileName(String fileName) {
    final stem = fileName.toLowerCase().replaceAll(RegExp(r'\.[^.]+$'), '');
    final tokens = stem.split(RegExp(r'[^a-z0-9]+')).toSet();
    if (tokens.any({'bottom', 'back', 'rear', 'bot', 'b'}.contains)) {
      return BoardSide.bottom;
    }
    if (tokens.any({'top', 'front', 'component', 't'}.contains)) {
      return BoardSide.top;
    }
    return BoardSide.unknown;
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
