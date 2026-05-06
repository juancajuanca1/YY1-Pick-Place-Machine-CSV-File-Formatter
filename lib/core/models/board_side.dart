enum BoardSide {
  top,
  bottom,
  unknown;

  static BoardSide fromString(String raw) {
    final s = raw.toLowerCase().trim();
    if (s == 'top' || s == 't' || s == 'f' || s == 'f.cu' || s == 'front') {
      return BoardSide.top;
    }
    if (s == 'bottom' || s == 'bot' || s == 'b' || s == 'b.cu' || s == 'back') {
      return BoardSide.bottom;
    }
    return BoardSide.unknown;
  }

  String get label {
    switch (this) {
      case BoardSide.top:
        return 'Top';
      case BoardSide.bottom:
        return 'Bottom';
      case BoardSide.unknown:
        return 'Unknown';
    }
  }
}
