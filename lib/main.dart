import 'dart:io';
import 'models/download_task.dart';
import 'models/quality_option.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/generated/app_localizations.dart';
import 'l10n/locale_controller.dart';
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

  final localeController = LocaleController();
  await localeController.load();
  runApp(OmniLoaderApp(localeController: localeController));
}

class OmniLoaderApp extends StatelessWidget {
  final LocaleController localeController;
  const OmniLoaderApp({super.key, required this.localeController});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: localeController,
      builder: (context, _) {
        final baseTheme = ThemeData.dark();
        return MaterialApp(
          title: 'OmniLoader',
          debugShowCheckedModeBanner: false,
          locale: localeController.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: baseTheme.copyWith(
            scaffoldBackgroundColor: const Color(0xFF0F172A),
            textTheme: baseTheme.textTheme.apply(fontFamily: 'ArefRuqaa'),
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF38BDF8),
              surface: Color(0xFF1E293B),
            ),
          ),
          home: MainScreen(localeController: localeController),
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  final LocaleController localeController;
  const MainScreen({super.key, required this.localeController});

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
    final l10n = AppLocalizations.of(context)!;
    if (bytes <= 0) return l10n.unknown;
    final suffixes = [l10n.bytes, l10n.kilobytes, l10n.megabytes, l10n.gigabytes, l10n.terabytes];
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
      AppLocalizations.of(context)!.downloadingVideos,
      channelDescription: AppLocalizations.of(context)!.notificationDescription,
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
        AppLocalizations.of(context)!.downloadCompleted,
        title,
        platformChannelSpecifics,
      );
    } else {
      await flutterLocalNotificationsPlugin.show(
        id,
        AppLocalizations.of(context)!.notificationProgress(progress),
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
            Text(
              AppLocalizations.of(context)!.appTitle,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.of(context)!.version,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const Divider(color: Color(0xFF334155), height: 26),
            Text(
              AppLocalizations.of(context)!.designedBy,
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
              child: Text(AppLocalizations.of(context)!.close, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
              label: AppLocalizations.of(context)!.playlistMaxQuality(h),
              sizeStr: _formatSize(bytes),
              streamInfo: null,
            ));
          }
        });

        opts.add(QualityOption(
          label: AppLocalizations.of(context)!.audioOnly + ' (MP3)',
          sizeStr: _formatSize(audioTotalBytes),
          streamInfo: null,
          isAudio: true,
        ));

        setState(() {
          _videoTitle = playlist.title;
          _thumbnailUrl = playlist.thumbnails.highResUrl;
          _itemInfo = AppLocalizations.of(context)!.playlistInfo(videos.length);
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
            label: AppLocalizations.of(context)!.videoQuality(h, vStream.container.name.toUpperCase()),
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
          _itemInfo = AppLocalizations.of(context)!.videoInfo(video.duration?.inMinutes ?? 0);
          _options = opts;
          _rawVideoTarget = video;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.error(e.toString())), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _startDownload(QualityOption opt) async {
    await _requestAppPermissions();
    await WakelockPlus.enable(); // إبقاء المعالج نشطاً لمنع توقف التنزيل بالخلفية

    final task = DownloadTask(
      id: _taskCounter++,
      title: _videoTitle ?? AppLocalizations.of(context)!.appTitle,
      qualityLabel: opt.label,
      totalSize: opt.sizeStr,
      status: AppLocalizations.of(context)!.downloading,
      speed: AppLocalizations.of(context)!.zeroSpeed,
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
              task.speed = AppLocalizations.of(context)!.speedMegabytesPerSecond((speedBytesPerSec / (1024 * 1024)).toStringAsFixed(2));
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
          task.status = AppLocalizations.of(context)!.completed;
          task.speed = AppLocalizations.of(context)!.savedTo;
        });

        _updateNotification(task.id, task.title, 100, true);
      }
    } catch (e) {
      setState(() {
        task.status = AppLocalizations.of(context)!.failed;
        task.speed = e.toString();
      });
    } finally {
      if (_tasks.every((t) => t.status == AppLocalizations.of(context)!.completed || t.status == AppLocalizations.of(context)!.failed)) {
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
            Text(AppLocalizations.of(context)!.appTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19)),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Color(0xFF38BDF8)),
            onPressed: _showAboutDialog,
            tooltip: AppLocalizations.of(context)!.about,
          ),
          PopupMenuButton<String>(
            tooltip: AppLocalizations.of(context)!.language,
            icon: const Icon(Icons.language, color: Color(0xFF38BDF8)),
            onSelected: (code) => widget.localeController.setLocale(Locale(code)),
            itemBuilder: (context) => [
              PopupMenuItem(value: 'ar', child: Text(AppLocalizations.of(context)!.arabic)),
              PopupMenuItem(value: 'en', child: Text(AppLocalizations.of(context)!.english)),
            ],
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
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.download), label: AppLocalizations.of(context)!.newDownload),
          BottomNavigationBarItem(icon: const Icon(Icons.list_alt), label: AppLocalizations.of(context)!.downloadList),
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
                    hintText: AppLocalizations.of(context)!.pasteUrl,
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
                  Text(AppLocalizations.of(context)!.selectQuality, style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 14, fontWeight: FontWeight.bold)),
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
      return Center(child: Text(AppLocalizations.of(context)!.noActiveDownloads, style: const TextStyle(color: Colors.grey, fontSize: 16)));
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
                      color: task.status == AppLocalizations.of(context)!.completed ? Colors.green : const Color(0xFF38BDF8),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('${task.qualityLabel} • ${AppLocalizations.of(context)!.sizeLabel(task.totalSize)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
