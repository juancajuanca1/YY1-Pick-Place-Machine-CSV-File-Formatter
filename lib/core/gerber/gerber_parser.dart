import 'dart:convert';
import 'dart:math' as math;

import 'gerber_models.dart';

enum _Interpolation { linear, clockwise, counterClockwise }

class _Aperture {
  final String shape;
  final List<double> values;
  const _Aperture(this.shape, this.values);
}

class GerberParser {
  const GerberParser._();

  static ParsedGerberLayer parse(GerberLayerCandidate source) {
    final text = latin1
        .decode(source.bytes, allowInvalid: true)
        .replaceAll('\u0000', '');
    final shapes = <GerberShape>[];
    final warnings = <String>[];
    final apertures = <int, _Aperture>{};
    var unitScale = 1.0;
    var decimalsX = 4;
    var decimalsY = 4;
    var x = 0.0;
    var y = 0.0;
    var selectedAperture = 0;
    var dark = true;
    var region = false;
    var regionPoints = <GerberPoint>[];
    var interpolation = _Interpolation.linear;

    double coordinate(String raw, int decimals) {
      if (raw.contains('.')) return double.parse(raw) * unitScale;
      return int.parse(raw) / math.pow(10, decimals) * unitScale;
    }

    void process(String rawCommand, {required bool extended}) {
      var command = rawCommand.trim();
      if (command.isEmpty || command.startsWith('G04')) return;
      if (extended) {
        final fs = RegExp(
          r'FS[^X]*X(\d)(\d)Y(\d)(\d)',
          caseSensitive: false,
        ).firstMatch(command);
        if (fs != null) {
          decimalsX = int.parse(fs.group(2)!);
          decimalsY = int.parse(fs.group(4)!);
          return;
        }
        if (command.startsWith('MOIN')) {
          unitScale = 25.4;
          return;
        }
        if (command.startsWith('MOMM')) {
          unitScale = 1;
          return;
        }
        if (command.startsWith('LPD')) {
          dark = true;
          return;
        }
        if (command.startsWith('LPC')) {
          dark = false;
          warnings.add(
            'Clear-polarity geometry is omitted from Cricut cuts; verify the preview.',
          );
          return;
        }
        if (command.startsWith('SR') ||
            command.startsWith('LM') ||
            command.startsWith('LR') ||
            command.startsWith('LS')) {
          warnings.add(
            'Gerber step/repeat or transform encountered; verify the preview.',
          );
          return;
        }
        final ad = RegExp(
          r'^ADD(\d+)([^,]+)(?:,(.+))?$',
          caseSensitive: false,
        ).firstMatch(command);
        if (ad != null) {
          final shape = ad.group(2)!;
          final rawValues = (ad.group(3) ?? '')
              .split(RegExp(r'[Xx]'))
              .map(double.tryParse)
              .whereType<double>()
              .toList();
          final values = <double>[];
          for (var i = 0; i < rawValues.length; i++) {
            final isDimension = shape.toUpperCase() != 'P' || i == 0;
            values.add(isDimension ? rawValues[i] * unitScale : rawValues[i]);
          }
          apertures[int.parse(ad.group(1)!)] = _Aperture(shape, values);
          return;
        }
        if (command.startsWith('AM')) {
          warnings.add(
            'Aperture macro encountered; macro flashes are approximated.',
          );
        }
        return;
      }

      if (command.contains('G36')) {
        region = true;
        regionPoints = [GerberPoint(x, y)];
        command = command.replaceAll('G36', '');
      }
      if (command.contains('G37')) {
        if (regionPoints.length >= 3) {
          shapes.add(
            GerberShape(
              type: GerberShapeType.region,
              points: List.unmodifiable(regionPoints),
              dark: dark,
            ),
          );
        }
        region = false;
        regionPoints = [];
        return;
      }
      if (command.contains('G01')) interpolation = _Interpolation.linear;
      if (command.contains('G02')) interpolation = _Interpolation.clockwise;
      if (command.contains('G03')) {
        interpolation = _Interpolation.counterClockwise;
      }

      final d = RegExp(
        r'D(\d+)',
        caseSensitive: false,
      ).allMatches(command).lastOrNull?.group(1);
      if (d != null &&
          int.parse(d) >= 10 &&
          !RegExp(r'[XY]').hasMatch(command)) {
        selectedAperture = int.parse(d);
        return;
      }
      final xm = RegExp(r'X([+-]?\d+(?:\.\d+)?)').firstMatch(command);
      final ym = RegExp(r'Y([+-]?\d+(?:\.\d+)?)').firstMatch(command);
      final im = RegExp(r'I([+-]?\d+(?:\.\d+)?)').firstMatch(command);
      final jm = RegExp(r'J([+-]?\d+(?:\.\d+)?)').firstMatch(command);
      final nextX = xm == null ? x : coordinate(xm.group(1)!, decimalsX);
      final nextY = ym == null ? y : coordinate(ym.group(1)!, decimalsY);
      final operation = d == null ? 1 : int.parse(d);
      final aperture = apertures[selectedAperture];

      if (operation == 2) {
        x = nextX;
        y = nextY;
        if (region) regionPoints.add(GerberPoint(x, y));
        return;
      }
      if (operation == 3) {
        if (aperture == null) {
          warnings.add('Flash used undefined aperture D$selectedAperture.');
        } else {
          shapes.add(
            _flash(aperture, GerberPoint(nextX, nextY), dark, warnings),
          );
        }
        x = nextX;
        y = nextY;
        return;
      }
      if (operation == 1 && (xm != null || ym != null)) {
        if (region) {
          regionPoints.add(GerberPoint(nextX, nextY));
        } else {
          final stroke = aperture?.values.firstOrNull ?? 0;
          if (interpolation == _Interpolation.linear) {
            shapes.add(
              GerberShape(
                type: GerberShapeType.line,
                points: [GerberPoint(x, y), GerberPoint(nextX, nextY)],
                width: stroke,
                dark: dark,
              ),
            );
          } else {
            final i = im == null ? 0 : coordinate(im.group(1)!, decimalsX);
            final j = jm == null ? 0 : coordinate(jm.group(1)!, decimalsY);
            shapes.add(
              GerberShape(
                type: GerberShapeType.arc,
                points: [GerberPoint(x, y), GerberPoint(nextX, nextY)],
                center: GerberPoint(x + i, y + j),
                width: stroke,
                dark: dark,
                clockwise: interpolation == _Interpolation.clockwise,
              ),
            );
          }
        }
        x = nextX;
        y = nextY;
      }
    }

    var index = 0;
    while (index < text.length) {
      while (index < text.length && text[index].trim().isEmpty) {
        index++;
      }
      if (index >= text.length) break;
      if (text[index] == '%') {
        final end = text.indexOf('%', index + 1);
        if (end < 0) break;
        for (final command in text.substring(index + 1, end).split('*')) {
          process(command, extended: true);
        }
        index = end + 1;
      } else {
        final end = text.indexOf('*', index);
        if (end < 0) break;
        process(text.substring(index, end), extended: false);
        index = end + 1;
      }
    }
    return ParsedGerberLayer(
      source: source,
      shapes: shapes,
      warnings: warnings.toSet().toList(),
    );
  }

  static GerberShape _flash(
    _Aperture a,
    GerberPoint point,
    bool dark,
    List<String> warnings,
  ) {
    final type = a.shape.toUpperCase();
    final w = a.values.firstOrNull ?? 0;
    final h = a.values.length > 1 ? a.values[1] : w;
    if (type == 'C') {
      return GerberShape(
        type: GerberShapeType.circle,
        points: [point],
        width: w,
        height: w,
        dark: dark,
      );
    }
    if (type == 'R') {
      return GerberShape(
        type: GerberShapeType.rectangle,
        points: [point],
        width: w,
        height: h,
        dark: dark,
      );
    }
    if (type == 'O') {
      return GerberShape(
        type: GerberShapeType.obround,
        points: [point],
        width: w,
        height: h,
        dark: dark,
      );
    }
    if (type == 'P') {
      return GerberShape(
        type: GerberShapeType.polygon,
        points: [point],
        width: w,
        height: w,
        dark: dark,
        vertices: a.values.length > 1 ? a.values[1].round() : 6,
        rotation: a.values.length > 2 ? a.values[2] : 0,
      );
    }
    warnings.add('Aperture macro "$type" approximated as a circle.');
    return GerberShape(
      type: GerberShapeType.circle,
      points: [point],
      width: w,
      height: w,
      dark: dark,
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
  T? get lastOrNull => isEmpty ? null : last;
}
