class DownloadTask {
  final int id;
  final String title;
  final String qualityLabel;
  final String totalSize;
  double progress;
  String status;
  String speed;

  DownloadTask({
    required this.id,
    required this.title,
    required this.qualityLabel,
    required this.totalSize,
    this.progress = 0.0,
    this.status = 'جاري التنزيل...',
    this.speed = '0 ك.ب/ث',
  });
}
