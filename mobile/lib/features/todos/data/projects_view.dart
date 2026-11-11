/// How projects are shown in the Tasks tab (Settings → Preferences).
enum ProjectsView {
  /// The glossy folders in a grid (the original look).
  folders,

  /// One flat row per project with a progress bar.
  list,

  /// Flat cards in a grid with a progress bar.
  cards,

  /// Chips above the task list; no separate projects screen.
  chips;

  static const fallback = ProjectsView.list;

  static ProjectsView of(Object? raw) {
    final index = raw is int ? raw : -1;
    return index >= 0 && index < values.length ? values[index] : fallback;
  }
}
