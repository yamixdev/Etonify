class UrlTestProgressState {
  const UrlTestProgressState({
    this.isRunning = false,
    this.isCancelled = false,
    this.total = 0,
    this.working = 0,
    this.failed = 0,
  });

  static const idle = UrlTestProgressState();

  final bool isRunning;
  final bool isCancelled;
  final int total;
  final int working;
  final int failed;

  int get tested => (working + failed).clamp(0, total);
  int get pending => (total - tested).clamp(0, total);

  bool get hasResults => total > 0 && (isRunning || isCancelled || tested > 0);

  UrlTestProgressState copyWith({
    bool? isRunning,
    bool? isCancelled,
    int? total,
    int? working,
    int? failed,
  }) {
    return UrlTestProgressState(
      isRunning: isRunning ?? this.isRunning,
      isCancelled: isCancelled ?? this.isCancelled,
      total: total ?? this.total,
      working: working ?? this.working,
      failed: failed ?? this.failed,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UrlTestProgressState &&
          runtimeType == other.runtimeType &&
          isRunning == other.isRunning &&
          isCancelled == other.isCancelled &&
          total == other.total &&
          working == other.working &&
          failed == other.failed;

  @override
  int get hashCode =>
      Object.hash(isRunning, isCancelled, total, working, failed);
}
