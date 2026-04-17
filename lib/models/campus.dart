enum Campus {
  aus,
  acet;

  String get basePath {
    switch (this) {
      case Campus.aus:
        return '/aus';
      case Campus.acet:
        return '/acet';
    }
  }

  static Campus fromName(String? name) {
    if (name == null) return Campus.aus;
    final lower = name.toLowerCase();
    if (lower == 'acet' || lower == 'acet college') {
      return Campus.acet;
    }
    return Campus.aus;
  }

  String get label {
    switch (this) {
      case Campus.aus:
        return 'AUS';
      case Campus.acet:
        return 'ACET';
    }
  }
}
