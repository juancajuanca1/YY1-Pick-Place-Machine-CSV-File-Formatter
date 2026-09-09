import 'dart:convert';
import 'dart:io';

import 'gerber_models.dart';

class GerberLayerClassifier {
  const GerberLayerClassifier._();

  static Future<List<GerberLayerCandidate>> scanDirectory(
    String directory,
  ) async {
    final result = <GerberLayerCandidate>[];
    await for (final entity in Directory(directory).list(recursive: true)) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (!_mayBeGerber(name)) continue;
      final bytes = await entity.readAsBytes();
      final content = latin1.decode(bytes, allowInvalid: true);
      if (!_looksLikeGerber(content)) continue;
      result.add(classify(entity.path, name, bytes, content));
    }
    result.sort((a, b) => b.confidence.compareTo(a.confidence));
    return result;
  }

  static GerberLayerCandidate classify(
    String path,
    String name,
    List<int> bytes,
    String content,
  ) {
    final x2 = RegExp(
      r'%TF\.FileFunction,([^*%]+)',
      caseSensitive: false,
    ).firstMatch(content)?.group(1)?.toLowerCase();
    if (x2 != null) {
      if (x2.contains('paste') && x2.contains('top')) {
        return _candidate(
          path,
          name,
          bytes,
          GerberLayerType.topPaste,
          1,
          'Gerber X2 FileFunction',
        );
      }
      if (x2.contains('paste') &&
          (x2.contains('bot') || x2.contains('bottom'))) {
        return _candidate(
          path,
          name,
          bytes,
          GerberLayerType.bottomPaste,
          1,
          'Gerber X2 FileFunction',
        );
      }
      if (x2.contains('profile')) {
        return _candidate(
          path,
          name,
          bytes,
          GerberLayerType.outline,
          1,
          'Gerber X2 FileFunction',
        );
      }
    }

    final lower = name.toLowerCase();
    final stem = lower.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    final compact = stem.replaceAll(' ', '');
    if (lower.endsWith('.gtp')) {
      return _candidate(
        path,
        name,
        bytes,
        GerberLayerType.topPaste,
        .98,
        'Altium top-paste extension (.GTP)',
      );
    }
    if (lower.endsWith('.gbp')) {
      return _candidate(
        path,
        name,
        bytes,
        GerberLayerType.bottomPaste,
        .98,
        'Altium bottom-paste extension (.GBP)',
      );
    }
    const topAliases = [
      'fpaste',
      'toppaste',
      'pastetop',
      'solderpastetop',
      'stenciltop',
      'tcream',
      'creamtop',
    ];
    const bottomAliases = [
      'bpaste',
      'bottompaste',
      'pastebottom',
      'solderpastebottom',
      'stencilbottom',
      'bcream',
      'creambottom',
    ];
    if (topAliases.any(compact.contains)) {
      return _candidate(
        path,
        name,
        bytes,
        GerberLayerType.topPaste,
        .9,
        'recognized top-paste filename',
      );
    }
    if (bottomAliases.any(compact.contains)) {
      return _candidate(
        path,
        name,
        bytes,
        GerberLayerType.bottomPaste,
        .9,
        'recognized bottom-paste filename',
      );
    }
    if (compact.contains('edgecuts') ||
        compact.contains('boardoutline') ||
        compact.contains('profile') ||
        lower.endsWith('.gko') ||
        lower.endsWith('.gm1')) {
      return _candidate(
        path,
        name,
        bytes,
        GerberLayerType.outline,
        .85,
        'recognized board-profile filename',
      );
    }
    return _candidate(
      path,
      name,
      bytes,
      GerberLayerType.other,
      .25,
      'valid Gerber; layer function not identified',
    );
  }

  static GerberLayerCandidate _candidate(
    String path,
    String name,
    List<int> bytes,
    GerberLayerType type,
    double confidence,
    String reason,
  ) => GerberLayerCandidate(
    path: path,
    fileName: name,
    bytes: bytes,
    type: type,
    confidence: confidence,
    reason: reason,
  );

  static bool _mayBeGerber(String name) {
    final lower = name.toLowerCase();
    return RegExp(r'\.(gbr|ger|pho|art|gtp|gbp|gko|gm\d+)$').hasMatch(lower);
  }

  static bool _looksLikeGerber(String content) =>
      content.contains('%FS') ||
      content.contains('%MO') ||
      (content.contains('D01*') && content.contains('D02*'));
}
