/// Represents a supported university campus portal.
enum Campus {
  aus(basePath: '/aus', label: 'AUS'),
  acet(basePath: '/acet', label: 'ACET');

  const Campus({required this.basePath, required this.label});

  /// The URL path prefix for all portal endpoints of this campus.
  final String basePath;

  /// User-facing short name shown in the UI selector.
  final String label;

  /// Returns the [Campus] for the given [name], defaulting to [aus].
  static Campus fromName(String? name) {
    return Campus.values.firstWhere(
      (c) => c.name == name,
      orElse: () => Campus.aus,
    );
  }
}
