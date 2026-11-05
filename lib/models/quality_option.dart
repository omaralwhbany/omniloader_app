class QualityOption {
  final String label;
  final String sizeStr;
  final dynamic streamInfo;
  final bool isAudio;

  QualityOption({
    required this.label,
    required this.sizeStr,
    required this.streamInfo,
    this.isAudio = false,
  });
}
