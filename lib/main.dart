import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:background_downloader/background_downloader.dart' as bg;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/launcher_icon');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  await bg.FileDownloader().configure(
    androidConfig: [(bg.Config.runInForeground, true)],
  );
  await bg.FileDownloader().trackTasks();
  bg.FileDownloader().configureNotification(
    running: const bg.TaskNotification('جارٍ تنزيل الفيديو', '{filename} • {progress}'),
    complete: const bg.TaskNotification('اكتمل التنزيل', '{filename}'),
    error: const bg.TaskNotification('تعذّر التنزيل', '{filename}'),
    paused: const bg.TaskNotification('التنزيل متوقف مؤقتاً', '{filename}'),
    progressBar: true,
  );
  runApp(const OmniLoaderApp());
}

class OmniLoaderApp extends StatelessWidget {
  const OmniLoaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.arefRuqaaTextTheme(ThemeData.dark().textTheme);

    return MaterialApp(
      title: 'تنزيل الفيديو',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'AE'),
      supportedLocales: const [
        Locale('ar', 'AE'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        textTheme: textTheme,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          surface: Color(0xFF1E293B),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class DownloadTaskItem {
  final int id;
  final String taskId;
  final String title;
  final String qualityLabel;
  final String totalSize;
  double progress;
  String status;
  String speed;

  DownloadTaskItem({
    required this.id,
    required this.taskId,
    required this.title,
    required this.qualityLabel,
    required this.totalSize,
    this.progress = 0.0,
    this.status = 'جاري التنزيل...',
    this.speed = '0 ك.ب/ث',
  });
}

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

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentTabIndex = 0;
  final TextEditingController _urlController = TextEditingController();
  final YoutubeExplode _yt = YoutubeExplode();
  final List<DownloadTaskItem> _tasks = [];
  final Map<String, bg.DownloadTask> _backgroundTasks = {};
  StreamSubscription<bg.TaskUpdate>? _downloadSubscription;
  int _taskCounter = 1;

  bool _isLoading = false;
  String? _videoTitle;
  String? _thumbnailUrl;
  String? _itemInfo;
  List<QualityOption> _options = [];
  dynamic _rawVideoTarget;

  @override
  void initState() {
    super.initState();
    _requestAppPermissions();
    _initializeDownloadEngine();
  }

  Future<void> _initializeDownloadEngine() async {
    final downloader = bg.FileDownloader();
    _downloadSubscription = downloader.updates.listen(_handleDownloadUpdate);
    await downloader.resumeFromBackground();
    await _restoreTasks();
  }

  Future<void> _restoreTasks() async {
    try {
      final records = await bg.FileDownloader().database.allRecords();
      final restored = <DownloadTaskItem>[];
      for (final dynamic record in records) {
        final dynamic nativeTask = record.task;
        if (nativeTask is! bg.DownloadTask) continue;
        Map<String, dynamic> meta = {};
        try { meta = Map<String, dynamic>.from(jsonDecode(nativeTask.metaData) as Map); } catch (_) {}
        final dynamic rawStatus = record.status;
        final dynamic rawProgress = record.progress;
        restored.add(DownloadTaskItem(
          id: _taskCounter++,
          taskId: nativeTask.taskId,
          title: (meta['title'] ?? nativeTask.displayName ?? nativeTask.filename).toString(),
          qualityLabel: (meta['quality'] ?? 'تنزيل فيديو').toString(),
          totalSize: (meta['size'] ?? 'غير محدد').toString(),
          progress: rawProgress is num ? rawProgress.toDouble().clamp(0.0, 1.0).toDouble() : 0.0,
          status: _statusText(rawStatus.toString()),
        ));
        _backgroundTasks[nativeTask.taskId] = nativeTask;
      }
      if (mounted && restored.isNotEmpty) {
        setState(() { _tasks..clear()..addAll(restored.reversed); });
      }
    } catch (e) { debugPrint('Restore downloads: $e'); }
  }

  String _statusText(String raw) {
    final value = raw.toLowerCase();
    if (value.contains('complete')) return 'مكتمل';
    if (value.contains('pause')) return 'متوقف مؤقتاً';
    if (value.contains('retry')) return 'بانتظار إعادة المحاولة';
    if (value.contains('running')) return 'جاري التنزيل';
    if (value.contains('enqueued')) return 'في قائمة الانتظار';
    if (value.contains('cancel')) return 'أُلغي';
    if (value.contains('notfound')) return 'المصدر غير موجود';
    return 'فشل التنزيل';
  }

  DownloadTaskItem? _itemForTask(String taskId) {
    for (final item in _tasks) { if (item.taskId == taskId) return item; }
    return null;
  }

  Future<void> _handleDownloadUpdate(bg.TaskUpdate update) async {
    final item = _itemForTask(update.task.taskId);
    if (item == null) return;
    if (update is bg.TaskProgressUpdate) {
      if (mounted) setState(() {
        item.progress = update.progress.clamp(0.0, 1.0).toDouble();
        if (update.hasNetworkSpeed) item.speed = update.networkSpeedAsString;
      });
      return;
    }
    if (update is bg.TaskStatusUpdate) {
      if (mounted) setState(() => item.status = _statusText(update.status.toString()));
      if (update.status == bg.TaskStatus.complete) {
        try {
          await bg.FileDownloader().moveToSharedStorage(
            update.task as bg.DownloadTask, bg.SharedStorage.downloads, directory: 'vd');
          if (mounted) setState(() => item.speed = 'تم الحفظ في مجلد Download/vd');
        } catch (e) {
          if (mounted) setState(() => item.speed = 'اكتمل، لكن تعذّر النقل إلى Downloads: $e');
        }
      } else if (update.status == bg.TaskStatus.failed && mounted) {
        setState(() => item.speed = 'تعذّر التنزيل؛ يمكنك إعادة المحاولة');
      }
    }
  }

  Future<void> _pauseTask(DownloadTaskItem item) async {
    final task = _backgroundTasks[item.taskId];
    if (task == null) return;
    final paused = await bg.FileDownloader().pause(task);
    if (!paused && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذا المصدر لا يدعم الإيقاف والاستئناف لهذا التنزيل.')));
    }
  }

  Future<void> _resumeTask(DownloadTaskItem item) async {
    final task = _backgroundTasks[item.taskId];
    if (task == null) return;
    final resumed = await bg.FileDownloader().resume(task);
    if (!resumed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر الاستئناف؛ قد لا يدعم المصدر طلبات Range.')));
    }
  }

  Future<void> _requestAppPermissions() async {
    await Permission.notification.request();
  }

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    _yt.close();
    _urlController.dispose();
    super.dispose();
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return "غير محدد";
    const suffixes = ["بايت", "ك.ب", "م.ب", "ج.ب", "ت.ب"];
    var i = 0;
    double dBytes = bytes.toDouble();
    while (dBytes >= 1024 && i < suffixes.length - 1) {
      dBytes /= 1024;
      i++;
    }
    return "${dBytes.toStringAsFixed(2)} ${suffixes[i]}";
  }

  Future<void> _updateNotification(int id, String title, int progress, bool isFinished) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'downloads_channel',
      'تنزيل الفيديوهات',
      channelDescription: 'إشعارات تقدم التنزيل في الخلفية',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: !isFinished,
      maxProgress: 100,
      progress: progress,
      ongoing: !isFinished,
      autoCancel: isFinished,
      icon: '@mipmap/launcher_icon',
    );
    final NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

    if (isFinished) {
      await flutterLocalNotificationsPlugin.show(
        id,
        'اكتمل التنزيل بنجاح',
        title,
        platformChannelSpecifics,
      );
    } else {
      await flutterLocalNotificationsPlugin.show(
        id,
        'جاري التنزيل: $progress%',
        title,
        platformChannelSpecifics,
      );
    }
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 95,
              height: 95,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF38BDF8), width: 2),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/logo.png',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.download, size: 45, color: Color(0xFF38BDF8)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'تنزيل الفيديو',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
            ),
            const SizedBox(height: 6),
            const Text(
              'الإصدار 1.0.0',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const Divider(color: Color(0xFF334155), height: 26),
            const Text(
              'تصميم وبرمجة:\nعمر الوهباني',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, height: 1.5),
            ),
            const SizedBox(height: 8),
            const SelectableText(
              'alwhbanymr090@gmail.com',
              style: TextStyle(fontSize: 13, color: Color(0xFF38BDF8)),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('إغلاق', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _fetchMetadata() async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) return;

    setState(() {
      _isLoading = true;
      _options.clear();
      _videoTitle = null;
    });

    try {
      if (rawUrl.contains('playlist')) {
        final playlist = await _yt.playlists.get(rawUrl);
        final videos = await _yt.playlists.getVideos(playlist.id).toList();

        int audioTotalBytes = 0;
        final Map<int, int> heightTotals = {144: 0, 240: 0, 360: 0, 480: 0, 720: 0, 1080: 0};

        for (var video in videos) {
          final manifest = await _yt.videos.streamsClient.getManifest(video.id);
          final bestAudio = manifest.audioOnly.withHighestBitrate();
          audioTotalBytes += bestAudio.size.totalBytes;

          for (var h in heightTotals.keys) {
            final vMatches = manifest.videoOnly.where((s) => s.videoQuality.index <= h);
            if (vMatches.isNotEmpty) {
              final bestV = vMatches.first;
              heightTotals[h] = heightTotals[h]! + bestV.size.totalBytes + bestAudio.size.totalBytes;
            }
          }
        }

        final List<QualityOption> opts = [];
        heightTotals.forEach((h, bytes) {
          if (bytes > 0) {
            opts.add(QualityOption(
              label: 'دقة ${h}p كحد أقصى',
              sizeStr: _formatSize(bytes),
              streamInfo: null,
            ));
          }
        });

        opts.add(QualityOption(
          label: 'صوت فقط',
          sizeStr: _formatSize(audioTotalBytes),
          streamInfo: null,
          isAudio: true,
        ));

        setState(() {
          _videoTitle = playlist.title;
          _thumbnailUrl = playlist.thumbnails.highResUrl;
          _itemInfo = 'قائمة تشغيل (${videos.length} مقطع)';
          _options = opts;
          _rawVideoTarget = videos;
          _isLoading = false;
        });
      } else {
        final video = await _yt.videos.get(rawUrl);
        final manifest = await _yt.videos.streamsClient.getManifest(video.id);
        final bestAudio = manifest.audioOnly.withHighestBitrate();

        final List<QualityOption> opts = [];
        final Map<int, VideoStreamInfo> uniqueHeights = {};

        for (var s in manifest.muxed) {
          final h = int.tryParse(s.videoResolution.height.toString()) ?? 0;
          if (h > 0 && !uniqueHeights.containsKey(h)) {
            uniqueHeights[h] = s;
          }
        }

        final sortedHeights = uniqueHeights.keys.toList()..sort();
        for (var h in sortedHeights) {
          final vStream = uniqueHeights[h]!;
          final totalBytes = vStream.size.totalBytes;
          opts.add(QualityOption(
            label: 'دقة ${h}p (${vStream.container.name.toUpperCase()})',
            sizeStr: _formatSize(totalBytes),
            streamInfo: vStream,
          ));
        }

        opts.add(QualityOption(
          label: 'صوت فقط (MP3)',
          sizeStr: _formatSize(bestAudio.size.totalBytes),
          streamInfo: bestAudio,
          isAudio: true,
        ));

        setState(() {
          _videoTitle = video.title;
          _thumbnailUrl = video.thumbnails.highResUrl;
          _itemInfo = 'مقطع فيديو (${video.duration?.inMinutes ?? 0} دقيقة)';
          _options = opts;
          _rawVideoTarget = video;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _startDownload(QualityOption opt) async {
    if (_rawVideoTarget is! Video) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تنزيل قوائم التشغيل سيُضاف في تحديث لاحق.')));
      return;
    }
    try {
      final video = _rawVideoTarget as Video;
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);
      final requestedHeight = int.tryParse(
        RegExp(r'(\d+)p').firstMatch(opt.label)?.group(1) ?? '');
      final dynamic streamInfo;
      if (opt.isAudio) {
        streamInfo = manifest.audioOnly.withHighestBitrate();
      } else {
        streamInfo = requestedHeight == null
            ? manifest.muxed.withHighestBitrate()
            : manifest.muxed.firstWhere(
                (s) => s.videoResolution.height == requestedHeight,
                orElse: () => manifest.muxed.withHighestBitrate(),
              );
      }
      final title = _videoTitle ?? video.title;
      final safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
      final rawExtension = streamInfo.container.name.toLowerCase();
      final extension = rawExtension == 'mp4' || rawExtension == 'webm' ? rawExtension : 'bin';
      final taskId = 'omni_${DateTime.now().millisecondsSinceEpoch}_$_taskCounter';
      final item = DownloadTaskItem(
        id: _taskCounter++, taskId: taskId, title: title,
        qualityLabel: opt.label, totalSize: opt.sizeStr);
      final nativeTask = bg.DownloadTask(
        taskId: taskId,
        url: streamInfo.url.toString(),
        filename: '$safeTitle.$extension',
        directory: 'vd',
        baseDirectory: bg.BaseDirectory.applicationDocuments,
        displayName: title,
        metaData: jsonEncode({
          'title': title, 'quality': opt.label, 'size': opt.sizeStr,
          'videoId': video.id.value,
        }),
        updates: bg.Updates.statusAndProgress,
        allowPause: true,
        retries: 5,
      );
      _backgroundTasks[taskId] = nativeTask;
      setState(() {
        _tasks.insert(0, item);
        _currentTabIndex = 1;
        _videoTitle = null;
        _urlController.clear();
      });
      final enqueued = await bg.FileDownloader().enqueue(nativeTask);
      if (!enqueued && mounted) setState(() {
        item.status = 'فشل التنزيل';
        item.speed = 'تعذّر إضافة المهمة إلى قائمة التنزيل.';
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذّر بدء التنزيل: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => const Icon(Icons.download, color: Color(0xFF38BDF8)),
              ),
            ),
            const SizedBox(width: 10),
            const Text('تنزيل الفيديو', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Color(0xFF38BDF8)),
            onPressed: _showAboutDialog,
            tooltip: 'حول التطبيق',
          ),
        ],
      ),
      body: _currentTabIndex == 0 ? _buildDownloadTab() : _buildTasksTab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        backgroundColor: const Color(0xFF1E293B),
        selectedItemColor: const Color(0xFF38BDF8),
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentTabIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.download), label: 'تنزيل جديد'),
          BottomNavigationBarItem(icon: Icon(Icons.list_alt), label: 'قائمة التنزيلات'),
        ],
      ),
    );
  }

  Widget _buildDownloadTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    hintText: 'الصق رابط الفيديو أو قائمة التشغيل...',
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isLoading ? null : _fetchMetadata,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.search),
              ),
            ],
          ),
          if (_videoTitle != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_thumbnailUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(_thumbnailUrl!, width: 90, height: 60, fit: BoxFit.cover),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_videoTitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            const SizedBox(height: 4),
                            Text(_itemInfo ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('اختر الدقة والحجم المطلوب:', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ..._options.map((opt) => Card(
                        color: const Color(0xFF0F172A),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          title: Text(opt.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(opt.sizeStr, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          trailing: const Icon(Icons.arrow_downward, color: Color(0xFF38BDF8), size: 18),
                          onTap: () => _startDownload(opt),
                        ),
                      )),
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildTasksTab() {
    if (_tasks.isEmpty) {
      return const Center(child: Text('لا توجد عمليات تنزيل نشطة', style: TextStyle(color: Colors.grey, fontSize: 16)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tasks.length,
      itemBuilder: (context, index) {
        final task = _tasks[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  Text(
                    task.status,
                    style: TextStyle(
                      color: task.status == 'مكتمل' ? Colors.green : const Color(0xFF38BDF8),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (task.status == 'جاري التنزيل' || task.status == 'في قائمة الانتظار' || task.status == 'بانتظار إعادة المحاولة')
                    IconButton(
                      tooltip: 'إيقاف مؤقت',
                      onPressed: () => _pauseTask(task),
                      icon: const Icon(Icons.pause_circle_outline, color: Color(0xFF38BDF8)),
                    )
                  else if (task.status == 'متوقف مؤقتاً')
                    IconButton(
                      tooltip: 'استئناف',
                      onPressed: () => _resumeTask(task),
                      icon: const Icon(Icons.play_circle_outline, color: Colors.green),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text('${task.qualityLabel} • الحجم: ${task.totalSize}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: task.progress,
                backgroundColor: const Color(0xFF0F172A),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF38BDF8)),
                minHeight: 6,
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${(task.progress * 100).toStringAsFixed(1)}%', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold)),
                  Text(task.speed, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              )
            ],
          ),
        );
      },
    );
  }
}
