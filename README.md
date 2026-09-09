# NeoDen YY1 Pick-and-Place Formatter

Desktop Flutter utility that normalizes placement exports and writes the
NeoDen YY1 P&P CSV format.

Supported inputs include conventional header-based CSV/POS/TXT exports and
headerless Autodesk Fusion 360/EAGLE placement CSVs in this order:

```text
Designator, X, Y, Rotation, Value, Footprint
```

For headerless files, `_front`, `_top`, `_back`, and `_bottom` filename tokens
are used to determine the board side; top is the fallback when no side is
available. Components remain groupable by value, footprint, and side even when
the value is not a package size (for example `10uF`).

Fiducials are detected from common references and names (`FD`, `FID`,
`fiducial`, `feducial`, registration mark, tooling mark). Right-click a row on
the assignment screen to mark it as a fiducial, treat it as a component, or
return to automatic detection.

The home screen also provides a Cricut stencil generator. Select a complete
Gerber output folder and the application classifies Gerber X2 metadata plus
Fusion 360, Altium, KiCad, EasyEDA, and EAGLE filename conventions. Only top
and bottom paste layers become cuts; copper, mask, silkscreen, drill, and
ordinary through-hole geometry are ignored. Gerber files are read as raw bytes,
parsed into millimeter vector geometry, previewed, and exported as Cricut SVG.

## Development

```bash
flutter pub get
flutter run -d linux
```

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
