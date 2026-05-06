import '../models/placement_record.dart';

/// Defines the exact column contract for a YY1 import CSV.
abstract class MachineExportProfile {
  const MachineExportProfile();

  String get profileName;
  String get delimiter;
  String get lineEnding;

  /// The exact column header strings as they appear in the file.
  List<String> get headerColumns;

  /// Returns the preamble block that precedes the header/data rows.
  /// Return empty string if no preamble is needed.
  String preamble();

  Map<String, String> rowFields(PlacementRecord r);

  String serializeRow(Map<String, String> fields) =>
      headerColumns.map((h) => _escape(fields[h] ?? '', delimiter)).join(delimiter);

  String _escape(String s, String delim) {
    if (s.contains(delim) || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }
}

/// NeoDen YY1 native P&P CSV format.
///
/// Column order and names match the machine exactly (13 columns):
///   Designator, Comment, Footprint, Mid X(mm), Mid Y(mm) , Rotation,
///   Head , FeederNo, Mount Speed(%), Pick Height(mm), Place Height(mm),
///   Mode, Skip
///
/// The file also requires the fixed NEODEN preamble block so the machine
/// recognises it as a valid YY1 P&P file.
class Yy1ImportProfile extends MachineExportProfile {
  const Yy1ImportProfile();

  @override
  String get profileName => 'NeoDen YY1 Import';

  @override
  String get delimiter => ',';

  @override
  String get lineEnding => '\r\n';

  // The 13 column headers as they appear verbatim in the file.
  // Note the intentional trailing spaces on 'Mid Y(mm) ' and 'Head '
  // – they match the format the machine writes and reads.
  @override
  List<String> get headerColumns => const [
        'Designator',
        'Comment',
        'Footprint',
        'Mid X(mm)',
        'Mid Y(mm) ',
        'Rotation',
        'Head ',
        'FeederNo',
        'Mount Speed(%)',
        'Pick Height(mm)',
        'Place Height(mm)',
        'Mode',
        'Skip',
      ];

  /// Builds the required NEODEN preamble.  The separator blank lines use
  /// 13 commas (14 empty fields) exactly as the machine writes them.
  @override
  String preamble() {
    const nl = '\r\n';
    const blank = ',,,,,,,,,,,,,'; // 13 commas – machine format
    return 'NEODEN,YY1,P&P FILE,${',' * 10}$nl'
        '$blank$nl'
        'PanelizedPCB,UnitLength,0,UnitWidth,0,Rows,1,Columns,1,$nl'
        '$blank$nl'
        'Fiducial,1-X,0,1-Y,0,OverallOffsetX,0,OverallOffsetY,0,$nl'
        '$blank$nl'
        'NozzleChange,OFF,BeforeComponent,2,Head1,Drop,Station1,PickUp,Station3,$nl'
        'NozzleChange,OFF,BeforeComponent,1,Head1,Drop,Station3,PickUp,Station1,$nl'
        'NozzleChange,OFF,BeforeComponent,1,Head1,Drop,Station1,PickUp,Station1,$nl'
        'NozzleChange,OFF,BeforeComponent,1,Head1,Drop,Station1,PickUp,Station1,$nl'
        '$blank$nl';
  }

  @override
  Map<String, String> rowFields(PlacementRecord r) => {
        'Designator':       r.designator,
        'Comment':          r.value,
        'Footprint':        r.footprint,
        'Mid X(mm)':        _fmtXY(r.xMm),
        'Mid Y(mm) ':       _fmtXY(r.yMm),
        'Rotation':         _fmtRot(r.rotationDeg),
        'Head ':            '0',
        'FeederNo':         '${r.feederSlot ?? 1}',
        'Mount Speed(%)':   '${r.mountSpeed}',
        'Pick Height(mm)':  _fmtH(r.pickHeight),
        'Place Height(mm)': _fmtH(r.placeHeight),
        'Mode':             '1',
        'Skip':             r.enabled ? '0' : '1',
      };

  /// XY coordinates: 2 decimal places (matches sample: 31.23, 17.52)
  static String _fmtXY(double v) => v.toStringAsFixed(2);

  /// Rotation: 2 decimal places with sign (matches sample: -90.00)
  static String _fmtRot(double v) => v.toStringAsFixed(2);

  /// Heights: 1 decimal place (matches sample: 0.0)
  static String _fmtH(double v) => v.toStringAsFixed(1);
}
