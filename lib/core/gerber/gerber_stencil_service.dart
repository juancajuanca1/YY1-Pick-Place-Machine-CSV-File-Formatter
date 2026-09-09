import 'gerber_layer_classifier.dart';
import 'gerber_models.dart';
import 'gerber_parser.dart';

class GerberStencilService {
  const GerberStencilService._();
  static Future<GerberStencilProject> loadDirectory(String directory) async {
    final files = await GerberLayerClassifier.scanDirectory(directory);
    GerberLayerCandidate? best(GerberLayerType type) {
      for (final file in files) {
        if (file.type == type) return file;
      }
      return null;
    }

    final topFile = best(GerberLayerType.topPaste);
    final bottomFile = best(GerberLayerType.bottomPaste);
    final outlineFile = best(GerberLayerType.outline);
    final top = topFile == null ? null : GerberParser.parse(topFile);
    final bottom = bottomFile == null ? null : GerberParser.parse(bottomFile);
    final outline = outlineFile == null
        ? null
        : GerberParser.parse(outlineFile);
    final warnings = <String>[];
    if (topFile == null) warnings.add('No top paste Gerber was detected.');
    if (bottomFile == null) {
      warnings.add('No bottom paste Gerber was detected.');
    }
    if (top != null && top.shapes.isEmpty) {
      warnings.add('${topFile!.fileName} has no supported paste geometry.');
    }
    if (bottom != null && bottom.shapes.isEmpty) {
      warnings.add('${bottomFile!.fileName} has no supported paste geometry.');
    }
    return GerberStencilProject(
      sourceDirectory: directory,
      files: files,
      top: top,
      bottom: bottom,
      outline: outline,
      warnings: warnings,
    );
  }
}
