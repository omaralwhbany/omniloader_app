import 'dart:io';
import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const OmniLoaderApp());
}

class OmniLoaderApp extends StatelessWidget {
  const OmniLoaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OmniLoader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF59E0B),
          surface: Color(0xFF1E293B),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class DownloadTask {
  final String title;
  final String qualityLabel;
  final String totalSize;
  double progress;
  String status;
  String speed;

  DownloadTask({
    required this.title,
    required this.qualityLabel,
    required this.totalSize,
    this.progress = 0.0,
    this.status = 'Running',
    this.speed = '0 KB/s',
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
  final List<DownloadTask> _tasks = [];

  bool _isLoading = false;
  String? _videoTitle;
  String? _thumbnailUrl;
  String? _itemInfo;
  List<QualityOption> _options = [];
  dynamic _rawVideoTarget;

  @override
  void dispose() {
    _yt.close();
    _urlController.dispose();
    super.dispose();
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return "Unknown";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = 0;
    double dBytes = bytes.toDouble();
    while (dBytes >= 1024 && i < suffixes.length - 1) {
      dBytes /= 1024;
      i++;
    }
    return "${dBytes.toStringAsFixed(2)} ${suffixes[i]}";
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
              label: '${h}p max',
              sizeStr: _formatSize(bytes),
              streamInfo: null,
            ));
          }
        });

        opts.add(QualityOption(
          label: 'Audio Only (MP3)',
          sizeStr: _formatSize(audioTotalBytes),
          streamInfo: null,
          isAudio: true,
        ));

        setState(() {
          _videoTitle = playlist.title;
          _thumbnailUrl = playlist.thumbnails.highResUrl;
          _itemInfo = 'Playlist (${videos.length} videos)';
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
            label: '${h}p (${vStream.container.name})',
            sizeStr: _formatSize(totalBytes),
            streamInfo: vStream,
          ));
        }

        opts.add(QualityOption(
          label: 'Audio Only (MP3)',
          sizeStr: _formatSize(bestAudio.size.totalBytes),
          streamInfo: bestAudio,
          isAudio: true,
        ));

        setState(() {
          _videoTitle = video.title;
          _thumbnailUrl = video.thumbnails.highResUrl;
          _itemInfo = 'Single Video (${video.duration?.inMinutes ?? 0} mins)';
          _options = opts;
          _rawVideoTarget = video;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _startDownload(QualityOption opt) async {
    await Permission.storage.request();
    await Permission.manageExternalStorage.request();

    final task = DownloadTask(
      title: _videoTitle ?? 'Unknown Video',
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
            setState(() {
              task.progress = total > 0 ? (downloaded / total) : 0.0;
              task.speed = "${(speedBytesPerSec / (1024 * 1024)).toStringAsFixed(2)} MB/s";
            });
            stopwatch.reset();
            downloaded = 0;
          }
        }

        await fileStream.flush();
        await fileStream.close();

        setState(() {
          task.progress = 1.0;
          task.status = 'Completed';
          task.speed = 'Done';
        });
      }
    } catch (e) {
      setState(() {
        task.status = 'Failed';
        task.speed = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.bolt, color: Color(0xFFF59E0B)),
            SizedBox(width: 8),
            Text('OmniLoader', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Text('/Download/vd', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          )
        ],
      ),
      body: _currentTabIndex == 0 ? _buildDownloadTab() : _buildTasksTab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        backgroundColor: const Color(0xFF1E293B),
        selectedItemColor: const Color(0xFFF59E0B),
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentTabIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.download), label: 'Download'),
          BottomNavigationBarItem(icon: Icon(Icons.task_alt), label: 'Tasks'),
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
                    hintText: 'Paste video or playlist URL...',
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFF59E0B)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _isLoading ? null : _fetchMetadata,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
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
                            Text(_videoTitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(_itemInfo ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('SELECT RESOLUTION & SIZE', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ..._options.map((opt) => Card(
                        color: const Color(0xFF0F172A),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          title: Text(opt.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text(opt.sizeStr, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          trailing: const Icon(Icons.arrow_downward, color: Color(0xFFF59E0B), size: 18),
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
      return const Center(child: Text('No active downloads', style: TextStyle(color: Colors.grey)));
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
                    child: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                  Text(task.status, style: TextStyle(color: task.status == 'Completed' ? Colors.green : const Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              Text('${task.qualityLabel} • ${task.totalSize}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: task.progress,
                backgroundColor: const Color(0xFF0F172A),
                valueColor: const AlwaysStoppedAnimation(Color(0xFFF59E0B)),
                minHeight: 6,
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${(task.progress * 100).toStringAsFixed(1)}%', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold)),
                  Text(task.speed, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              )
            ],
          ),
        );
      },
    );
  }
}
