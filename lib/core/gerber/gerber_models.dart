import 'dart:math' as math;

enum GerberLayerType { topPaste, bottomPaste, outline, other }

extension GerberLayerTypeLabel on GerberLayerType {
  String get label => switch (this) {
    GerberLayerType.topPaste => 'Top paste',
    GerberLayerType.bottomPaste => 'Bottom paste',
    GerberLayerType.outline => 'Board outline',
    GerberLayerType.other => 'Other',
  };
}

class GerberLayerCandidate {
  final String path;
  final String fileName;
  final List<int> bytes;
  final GerberLayerType type;
  final double confidence;
  final String reason;

  const GerberLayerCandidate({
    required this.path,
    required this.fileName,
    required this.bytes,
    required this.type,
    required this.confidence,
    required this.reason,
  });
}

class GerberPoint {
  final double x;
  final double y;
  const GerberPoint(this.x, this.y);
}

class GerberBounds {
  final double minX, minY, maxX, maxY;
  const GerberBounds(this.minX, this.minY, this.maxX, this.maxY);
  double get width => maxX - minX;
  double get height => maxY - minY;

  GerberBounds include(GerberBounds b) => GerberBounds(
    math.min(minX, b.minX),
    math.min(minY, b.minY),
    math.max(maxX, b.maxX),
    math.max(maxY, b.maxY),
  );
}

enum GerberShapeType { circle, rectangle, obround, polygon, line, arc, region }

class GerberShape {
  final GerberShapeType type;
  final List<GerberPoint> points;
  final double width;
  final double height;
  final bool dark;
  final bool clockwise;
  final GerberPoint? center;
  final int vertices;
  final double rotation;

  const GerberShape({
    required this.type,
    required this.points,
    this.width = 0,
    this.height = 0,
    this.dark = true,
    this.clockwise = false,
    this.center,
    this.vertices = 0,
    this.rotation = 0,
  });

  GerberBounds get bounds {
    if (points.isEmpty) return const GerberBounds(0, 0, 0, 0);
    var minX = points.first.x;
    var maxX = minX;
    var minY = points.first.y;
    var maxY = minY;
    for (final p in points.skip(1)) {
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }
    final padX = width / 2;
    final padY = (height == 0 ? width : height) / 2;
    if (type == GerberShapeType.arc && center != null) {
      final radius = math.sqrt(
        math.pow(points.first.x - center!.x, 2) +
            math.pow(points.first.y - center!.y, 2),
      );
      minX = math.min(minX, center!.x - radius);
      maxX = math.max(maxX, center!.x + radius);
      minY = math.min(minY, center!.y - radius);
      maxY = math.max(maxY, center!.y + radius);
    }
    return GerberBounds(minX - padX, minY - padY, maxX + padX, maxY + padY);
  }
}

class ParsedGerberLayer {
  final GerberLayerCandidate source;
  final List<GerberShape> shapes;
  final List<String> warnings;
  const ParsedGerberLayer({
    required this.source,
    required this.shapes,
    required this.warnings,
  });

  GerberBounds? get bounds {
    if (shapes.isEmpty) return null;
    var result = shapes.first.bounds;
    for (final shape in shapes.skip(1)) {
      result = result.include(shape.bounds);
    }
    return result;
  }
}

class GerberStencilProject {
  final String sourceDirectory;
  final List<GerberLayerCandidate> files;
  final ParsedGerberLayer? top;
  final ParsedGerberLayer? bottom;
  final ParsedGerberLayer? outline;
  final List<String> warnings;
  const GerberStencilProject({
    required this.sourceDirectory,
    required this.files,
    this.top,
    this.bottom,
    this.outline,
    this.warnings = const [],
  });
}
