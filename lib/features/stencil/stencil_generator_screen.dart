import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/gerber/gerber_models.dart';
import '../../core/gerber/gerber_stencil_service.dart';
import '../../core/gerber/stencil_svg_writer.dart';
import '../home/home_navigation_button.dart';

class StencilGeneratorScreen extends StatefulWidget {
  const StencilGeneratorScreen({super.key});
  @override
  State<StencilGeneratorScreen> createState() => _StencilGeneratorScreenState();
}

class _StencilGeneratorScreenState extends State<StencilGeneratorScreen> {
  GerberStencilProject? _project;
  bool _loading = false, _mirrorBottom = true;
  bool _isDragging = false;
  String? _error;

  Future<void> _chooseFolder() async {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Gerber fabrication folder',
    );
    if (path == null) return;
    await _handleFolder(path);
  }

  Future<void> _handleFolder(String path) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final project = await GerberStencilService.loadDirectory(path);
      if (mounted) setState(() => _project = project);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not read Gerber folder: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _exportBoth() async {
    final project = _project;
    if (project == null || (project.top == null && project.bottom == null)) {
      return;
    }
    final directory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Choose folder for 1:1 Cricut stencil SVGs',
    );
    if (directory == null) return;
    final saved = <String>[];
    if (project.top != null) {
      final path = await _availablePath(directory, 'stencil_top.svg');
      await File(path).writeAsBytes(
        utf8.encode(
          StencilSvgWriter.write(
            project.top!,
            frameBounds: project.outline?.bounds,
          ),
        ),
        flush: true,
      );
      saved.add(File(path).uri.pathSegments.last);
    }
    if (project.bottom != null) {
      final path = await _availablePath(directory, 'stencil_bottom.svg');
      await File(path).writeAsBytes(
        utf8.encode(
          StencilSvgWriter.write(
            project.bottom!,
            mirror: _mirrorBottom,
            frameBounds: project.outline?.bounds,
          ),
        ),
        flush: true,
      );
      saved.add(File(path).uri.pathSegments.last);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Generated ${saved.join(' and ')} at 1:1 scale in mm'),
        ),
      );
    }
  }

  Future<void> _export(ParsedGerberLayer layer, bool mirror) async {
    final side = layer.source.type == GerberLayerType.topPaste
        ? 'top'
        : 'bottom';
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save $side Cricut stencil',
      fileName: 'stencil_$side.svg',
      type: FileType.custom,
      allowedExtensions: const ['svg'],
    );
    if (path == null) return;
    final output = path.toLowerCase().endsWith('.svg') ? path : '$path.svg';
    await File(output).writeAsBytes(
      utf8.encode(
        StencilSvgWriter.write(
          layer,
          mirror: mirror,
          frameBounds: _project?.outline?.bounds,
        ),
      ),
      flush: true,
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Saved $output')));
    }
  }

  Future<String> _availablePath(String directory, String fileName) async {
    final separator = Platform.pathSeparator;
    final stem = fileName.substring(0, fileName.length - 4);
    var path = '$directory$separator$fileName';
    var suffix = 2;
    while (await File(path).exists()) {
      path = '$directory$separator${stem}_$suffix.svg';
      suffix++;
    }
    return path;
  }

  @override
  Widget build(BuildContext context) {
    final project = _project;
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 100,
        leading: const HomeNavigationButton(),
        title: const Text('Cricut Stencil Generator'),
      ),
      body: project == null
          ? _buildLanding(context)
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _loading ? null : _chooseFolder,
                        icon: const Icon(Icons.folder_open),
                        label: const Text('Select Gerber Folder'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: Text(project.sourceDirectory)),
                      if (_loading) const CircularProgressIndicator(),
                      const SizedBox(width: 12),
                      FilledButton.tonalIcon(
                        onPressed: _exportBoth,
                        icon: const Icon(Icons.file_download_outlined),
                        label: const Text('Export Both SVGs'),
                      ),
                    ],
                  ),
                  if (_error != null) _Message(_error!, error: true),
                  ...[
                    if (project.warnings.isNotEmpty)
                      _Message(project.warnings.join('  ')),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _SidePanel(
                              title: 'Top stencil',
                              layer: project.top,
                              onExport: project.top == null
                                  ? null
                                  : () => _export(project.top!, false),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _SidePanel(
                              title: 'Bottom stencil',
                              layer: project.bottom,
                              mirror: _mirrorBottom,
                              onMirrorChanged: (v) =>
                                  setState(() => _mirrorBottom = v),
                              onExport: project.bottom == null
                                  ? null
                                  : () =>
                                        _export(project.bottom!, _mirrorBottom),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ExpansionTile(
                      title: Text(
                        '${project.files.length} Gerber files inspected',
                      ),
                      children: project.files
                          .map(
                            (f) => ListTile(
                              dense: true,
                              title: Text(f.fileName),
                              subtitle: Text(
                                '${f.type.label} · ${(f.confidence * 100).round()}% · ${f.reason}',
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildLanding(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(
                  Icons.content_cut_rounded,
                  size: 56,
                  color: colors.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Cricut Stencil Generator',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Import a complete Gerber folder from Fusion 360, Altium, '
                  'EasyEDA, KiCad, EAGLE, or another RS-274X tool.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Output units: millimeters (mm) • SVG physical size: exact 1:1 scale',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 36),
                DropTarget(
                  onDragDone: (details) async {
                    setState(() => _isDragging = false);
                    if (details.files.isEmpty) return;
                    final path = details.files.first.path;
                    if (await FileSystemEntity.isDirectory(path)) {
                      await _handleFolder(path);
                    } else if (mounted) {
                      setState(
                        () => _error =
                            'Please drop the Gerber folder, not an individual file.',
                      );
                    }
                  },
                  onDragEntered: (_) => setState(() => _isDragging = true),
                  onDragExited: (_) => setState(() => _isDragging = false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: double.infinity,
                    height: 210,
                    decoration: BoxDecoration(
                      color: _isDragging
                          ? colors.primaryContainer
                          : colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isDragging
                            ? colors.primary
                            : colors.outlineVariant,
                        width: _isDragging ? 2.5 : 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_copy_outlined,
                          size: 52,
                          color: _isDragging
                              ? colors.primary
                              : colors.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _isDragging
                              ? 'Drop the Gerber folder!'
                              : 'Drag & drop your Gerber folder here',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: _isDragging
                                    ? colors.primary
                                    : colors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Top Paste + Bottom Paste • raw Gerber bytes',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: const [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('or'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _chooseFolder,
                    icon: const Icon(Icons.folder_open_rounded),
                    label: const Text('Select Gerber Folder'),
                  ),
                ),
                if (_loading) ...[
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                ],
                if (_error != null) _Message(_error!, error: true),
                const SizedBox(height: 18),
                Text(
                  'Only paste-mask apertures become cuts. The preview fits the window; '
                  'the exported SVG retains exact millimeter dimensions at 1:1 scale.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SidePanel extends StatelessWidget {
  final String title;
  final ParsedGerberLayer? layer;
  final bool mirror;
  final ValueChanged<bool>? onMirrorChanged;
  final VoidCallback? onExport;
  const _SidePanel({
    required this.title,
    this.layer,
    this.mirror = false,
    this.onMirrorChanged,
    this.onExport,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (layer != null)
            Text(
              '${layer!.source.fileName} · '
              '${layer!.shapes.where((s) => s.dark).length} cuts · '
              '${(layer!.source.confidence * 100).round()}% confidence',
            ),
          const SizedBox(height: 12),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: layer == null
                  ? const Center(child: Text('Not found'))
                  : CustomPaint(
                      painter: _GerberPainter(layer!, mirror: mirror),
                    ),
            ),
          ),
          if (onMirrorChanged != null)
            CheckboxListTile(
              value: mirror,
              onChanged: (v) => onMirrorChanged!(v ?? true),
              contentPadding: EdgeInsets.zero,
              title: const Text('Mirror for physical bottom-face cutting'),
            ),
          FilledButton.icon(
            onPressed: onExport,
            icon: const Icon(Icons.save_alt),
            label: const Text('Export Cricut SVG'),
          ),
          if (layer?.warnings.isNotEmpty ?? false)
            Text(
              layer!.warnings.join(' '),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
    ),
  );
}

class _GerberPainter extends CustomPainter {
  final ParsedGerberLayer layer;
  final bool mirror;
  _GerberPainter(this.layer, {required this.mirror});
  @override
  void paint(Canvas canvas, Size size) {
    final b = layer.bounds;
    if (b == null || b.width <= 0 || b.height <= 0) return;
    final scale = math.min(size.width / b.width, size.height / b.height) * .92;
    canvas.translate(
      (size.width - b.width * scale) / 2,
      (size.height + b.height * scale) / 2,
    );
    canvas.scale(scale, -scale);
    canvas.translate(-b.minX, -b.minY);
    if (mirror) {
      canvas.translate(b.minX + b.maxX, 0);
      canvas.scale(-1, 1);
    }
    for (final s in layer.shapes.where((shape) => shape.dark)) {
      final paint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill;
      final p = s.points.first;
      switch (s.type) {
        case GerberShapeType.circle:
          canvas.drawCircle(Offset(p.x, p.y), s.width / 2, paint);
        case GerberShapeType.rectangle:
        case GerberShapeType.obround:
          final rect = Rect.fromCenter(
            center: Offset(p.x, p.y),
            width: s.width,
            height: s.height,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              rect,
              Radius.circular(
                s.type == GerberShapeType.obround
                    ? math.min(s.width, s.height) / 2
                    : 0,
              ),
            ),
            paint,
          );
        case GerberShapeType.line:
        case GerberShapeType.arc:
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = s.width
            ..strokeCap = StrokeCap.round;
          canvas.drawLine(
            Offset(p.x, p.y),
            Offset(s.points.last.x, s.points.last.y),
            paint,
          );
        case GerberShapeType.region:
          final path = Path()..moveTo(p.x, p.y);
          for (final q in s.points.skip(1)) {
            path.lineTo(q.x, q.y);
          }
          canvas.drawPath(path..close(), paint);
        case GerberShapeType.polygon:
          final path = Path();
          final count = math.max(3, s.vertices);
          for (var i = 0; i < count; i++) {
            final a = (s.rotation + i * 360 / count) * math.pi / 180;
            final q = Offset(
              p.x + math.cos(a) * s.width / 2,
              p.y + math.sin(a) * s.width / 2,
            );
            i == 0 ? path.moveTo(q.dx, q.dy) : path.lineTo(q.dx, q.dy);
          }
          canvas.drawPath(path..close(), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GerberPainter old) =>
      old.layer != layer || old.mirror != mirror;
}

class _Message extends StatelessWidget {
  final String text;
  final bool error;
  const _Message(this.text, {this.error = false});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(12),
    color: error
        ? Theme.of(context).colorScheme.errorContainer
        : Theme.of(context).colorScheme.secondaryContainer,
    child: Text(text),
  );
}
