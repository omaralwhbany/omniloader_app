import 'dart:io';
import 'models/download_task.dart';
import 'models/quality_option.dart';
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

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentTabIndex = 0;
  final TextEditingController _urlController = TextEditingController();
  final YoutubeExplode _yt = YoutubeExplode();
  final List<DownloadTask> _tasks = [];
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
  }

  Future<void> _requestAppPermissions() async {
    await Permission.notification.request();
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();
    await Permission.ignoreBatteryOptimizations.request();
  }

  @override
  void dispose() {
    _yt.close();
    _urlController.dispose();
    WakelockPlus.disable();
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
          label: 'صوت فقط (MP3)',
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

        for (var s in manifest.videoOnly) {
          final h = int.tryParse(s.videoResolution.height.toString()) ?? 0;
          if (h > 0 && !uniqueHeights.containsKey(h)) {
            uniqueHeights[h] = s;
          }
        }

        final sortedHeights = uniqueHeights.keys.toList()..sort();
        for (var h in sortedHeights) {
          final vStream = uniqueHeights[h]!;
          final totalBytes = vStream.size.totalBytes + bestAudio.size.totalBytes;
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
    await _requestAppPermissions();
    await WakelockPlus.enable(); // إبقاء المعالج نشطاً لمنع توقف التنزيل بالخلفية

    final task = DownloadTask(
      id: _taskCounter++,
      title: _videoTitle ?? 'مقطع فيديو',
      qualityLabel: opt.label,
      totalSize: opt.sizeStr,
    );

    setState(() {
      _tasks.insert(0, task);
      _currentTabIndex = 1;
      _videoTitle = null;
      _urlController.clear();
    });

    _executeDownloadWorker(task, opt);
  }

  Future<void> _executeDownloadWorker(DownloadTask task, QualityOption opt) async {
    final saveDir = Directory('/storage/emulated/0/Download/vd');
    if (!saveDir.existsSync()) {
      saveDir.createSync(recursive: true);
    }

    try {
      final safeTitle = task.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final ext = opt.isAudio ? 'mp3' : 'mp4';
      final filePath = '${saveDir.path}/$safeTitle.$ext';

      if (_rawVideoTarget is Video) {
        final video = _rawVideoTarget as Video;
        final manifest = await _yt.videos.streamsClient.getManifest(video.id);
        final streamInfo = opt.isAudio
            ? manifest.audioOnly.withHighestBitrate()
            : manifest.muxed.withHighestBitrate();

        final stream = _yt.videos.streamsClient.get(streamInfo);
        final file = File(filePath);
        final fileStream = file.openWrite();

        int downloaded = 0;
        final total = streamInfo.size.totalBytes;
        final stopwatch = Stopwatch()..start();

        await for (final data in stream) {
          fileStream.add(data);
          downloaded += data.length;

          if (stopwatch.elapsedMilliseconds >= 500) {
            final speedBytesPerSec = downloaded / (stopwatch.elapsedMilliseconds / 1000);
            final currentProgress = total > 0 ? (downloaded / total) : 0.0;
            final pct = (currentProgress * 100).toInt();

            setState(() {
              task.progress = currentProgress;
              task.speed = "${(speedBytesPerSec / (1024 * 1024)).toStringAsFixed(2)} م.ب/ث";
            });

            _updateNotification(task.id, task.title, pct, false);
            stopwatch.reset();
            downloaded = 0;
          }
        }

        await fileStream.flush();
        await fileStream.close();

        setState(() {
          task.progress = 1.0;
          task.status = 'مكتمل';
          task.speed = 'تم الحفظ في /Download/vd';
        });

        _updateNotification(task.id, task.title, 100, true);
      }
    } catch (e) {
      setState(() {
        task.status = 'فشل التنزيل';
        task.speed = e.toString();
      });
    } finally {
      if (_tasks.every((t) => t.status == 'مكتمل' || t.status == 'فشل التنزيل')) {
        WakelockPlus.disable();
      }
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
