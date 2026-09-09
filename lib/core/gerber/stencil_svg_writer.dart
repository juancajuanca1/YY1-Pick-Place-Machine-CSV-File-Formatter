import 'dart:math' as math;
import 'gerber_models.dart';

class StencilSvgWriter {
  const StencilSvgWriter._();
  static String write(
    ParsedGerberLayer layer, {
    bool mirror = false,
    GerberBounds? frameBounds,
  }) {
    final b = frameBounds ?? layer.bounds;
    if (b == null) throw StateError('The paste layer contains no geometry.');
    const margin = 2.0;
    final width = b.width + margin * 2, height = b.height + margin * 2;
    final body = layer.shapes.where((s) => s.dark).map(_shape).join('\n');
    final mirrorTransform = mirror
        ? 'translate(${_n(b.minX + b.maxX)} 0) scale(-1 1)'
        : '';
    return '''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="${_n(width)}mm" height="${_n(height)}mm" viewBox="${_n(b.minX - margin)} ${_n(-b.maxY - margin)} ${_n(width)} ${_n(height)}" preserveAspectRatio="xMidYMid meet" shape-rendering="geometricPrecision">
  <title>${layer.source.type.label} Cricut stencil</title>
  <desc>Exact 1:1 physical scale in millimeters. Paste apertures only; ordinary through-hole parts are excluded. Do not resize on import.</desc>
  <g id="stencil-cuts" fill="#000" stroke="#000" transform="scale(1 -1)"><g transform="$mirrorTransform">
$body
  </g></g>
</svg>''';
  }

  static String _shape(GerberShape s) {
    final p = s.points.first;
    switch (s.type) {
      case GerberShapeType.circle:
        return '<circle cx="${_n(p.x)}" cy="${_n(p.y)}" r="${_n(s.width / 2)}"/>';
      case GerberShapeType.rectangle:
      case GerberShapeType.obround:
        final rx = s.type == GerberShapeType.obround
            ? math.min(s.width, s.height) / 2
            : 0.0;
        return '<rect x="${_n(p.x - s.width / 2)}" y="${_n(p.y - s.height / 2)}" width="${_n(s.width)}" height="${_n(s.height)}"${rx > 0 ? ' rx="${_n(rx)}"' : ''}/>';
      case GerberShapeType.polygon:
        final count = math.max(3, s.vertices);
        final points = List.generate(count, (i) {
          final a = (s.rotation + i * 360 / count) * math.pi / 180;
          return '${_n(p.x + math.cos(a) * s.width / 2)},${_n(p.y + math.sin(a) * s.width / 2)}';
        });
        return '<polygon points="${points.join(' ')}"/>';
      case GerberShapeType.line:
        final q = s.points.last;
        return '<line x1="${_n(p.x)}" y1="${_n(p.y)}" x2="${_n(q.x)}" y2="${_n(q.y)}" fill="none" stroke-width="${_n(s.width)}" stroke-linecap="round"/>';
      case GerberShapeType.arc:
        final q = s.points.last, c = s.center!;
        final r = math.sqrt(math.pow(p.x - c.x, 2) + math.pow(p.y - c.y, 2));
        return '<path d="M ${_n(p.x)} ${_n(p.y)} A ${_n(r)} ${_n(r)} 0 0 ${s.clockwise ? 0 : 1} ${_n(q.x)} ${_n(q.y)}" fill="none" stroke-width="${_n(s.width)}"/>';
      case GerberShapeType.region:
        final d = StringBuffer('M ${_n(p.x)} ${_n(p.y)}');
        for (final q in s.points.skip(1)) {
          d.write(' L ${_n(q.x)} ${_n(q.y)}');
        }
        return '<path d="$d Z" fill-rule="evenodd"/>';
    }
  }

  static String _n(double v) => v
      .toStringAsFixed(5)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
