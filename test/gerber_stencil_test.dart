import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:neoden_yy1_formatter/core/gerber/gerber_layer_classifier.dart';
import 'package:neoden_yy1_formatter/core/gerber/gerber_models.dart';
import 'package:neoden_yy1_formatter/core/gerber/gerber_parser.dart';
import 'package:neoden_yy1_formatter/core/gerber/stencil_svg_writer.dart';

const gerber = '''G04 paste test*
%FSLAX24Y24*%
%MOMM*%
%TF.FileFunction,Paste,Top*%
%ADD10R,1.200X0.800*%
D10*
X100000Y200000D03*
X120000Y200000D03*
M02*''';

void main() {
  test('classifies X2 metadata before filename', () {
    final bytes = latin1.encode(gerber);
    final result = GerberLayerClassifier.classify(
      '/tmp/unknown.gbr',
      'unknown.gbr',
      bytes,
      gerber,
    );
    expect(result.type, GerberLayerType.topPaste);
    expect(result.confidence, 1);
  });

  test('reads byte data into dimensionally accurate paste flashes and SVG', () {
    final bytes = latin1.encode(gerber);
    final source = GerberLayerClassifier.classify(
      '/tmp/paste.gbr',
      'paste.gbr',
      bytes,
      gerber,
    );
    final layer = GerberParser.parse(source);
    expect(layer.shapes, hasLength(2));
    expect(layer.shapes.first.type, GerberShapeType.rectangle);
    expect(layer.shapes.first.points.first.x, closeTo(10, .00001));
    expect(layer.shapes.first.points.first.y, closeTo(20, .00001));
    expect(layer.shapes.first.width, closeTo(1.2, .00001));
    expect(layer.shapes.first.height, closeTo(.8, .00001));
    final svg = StencilSvgWriter.write(layer);
    expect(svg, contains('width="1.2"'));
    expect(svg, contains('mm"'));
    expect(svg, contains('stencil-cuts'));
    expect(svg, contains('Exact 1:1 physical scale in millimeters'));

    final framedSvg = StencilSvgWriter.write(
      layer,
      frameBounds: const GerberBounds(0, 0, 30, 20),
    );
    expect(framedSvg, contains('width="34mm"'));
    expect(framedSvg, contains('height="24mm"'));
  });

  test('recognizes common vendor paste filenames', () {
    for (final name in [
      'board.GTP',
      'board-F_Paste.gbr',
      'solderpaste_top.gbr',
      'StencilTop.gbr',
      'tCream.gbr',
    ]) {
      final result = GerberLayerClassifier.classify(
        '/tmp/$name',
        name,
        latin1.encode(gerber),
        '',
      );
      expect(result.type, GerberLayerType.topPaste, reason: name);
    }
  });
}
