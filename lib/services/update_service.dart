import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ota_update/ota_update.dart';
import 'package:open_file/open_file.dart';
import 'package:puked/generated/l10n/app_localizations.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class UpdateService {
  static const String _owner = 'hkgood';
  static const String _repo = 'Puked';
  static const String _githubApiUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  // 下载源配置
  static const String _osgLabMirror = 'https://download.osglab.com/PukedAPK';
  static const String _githubRelease =
      'https://github.com/$_owner/$_repo/releases/download';

  // GitHub 镜像加速服务（国内优化）
  // 已测试可用且响应速度较快的镜像
  static const List<Map<String, String>> _githubMirrors = [
    {
      'name': 'GH-Proxy加速',
      'prefix': 'https://gh-proxy.com/',
    },
    {
      'name': 'GHProxy.net',
      'prefix': 'https://ghproxy.net/',
    },
    {
      'name': 'GHProxy.com',
      'prefix': 'https://ghproxy.com/',
    },
  ];

  // 防止重复下载的状态锁 (使用 SharedPreferences 持久化)
  static const String _downloadingKey = 'is_downloading_update';
  static const String _downloadStartTimeKey = 'download_start_time';
  static bool _isDownloading = false;

  // 镜像测试结果缓存
  static const String _mirrorCacheTimeKey = 'mirror_test_cache_time';
  static const int _mirrorCacheValidMinutes = 10; // 缓存有效期10分钟
  static Map<String, dynamic>? _cachedMirrorResult;

  /// 清理可能卡住的下载状态 (应用启动时调用)
  static Future<void> cleanupStaleDownloadState() async {
    final prefs = await SharedPreferences.getInstance();
    final isDownloading = prefs.getBool(_downloadingKey) ?? false;

    if (isDownloading) {
      final startTime = prefs.getInt(_downloadStartTimeKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsedMinutes = (now - startTime) / 1000 / 60;

      // 如果下载状态超过10分钟还没清除,认为是异常状态
      if (elapsedMinutes > 10) {
        debugPrint(
            '🧹 [Update] Cleaning stale download state (${elapsedMinutes.toInt()} minutes old)');
        await prefs.setBool(_downloadingKey, false);
        await prefs.remove(_downloadStartTimeKey);
        _isDownloading = false;
      }
    }
  }

  /// 检查是否有正在进行的下载任务
  // ignore: unused_element
  static Future<bool> _checkDownloadingState() async {
    final prefs = await SharedPreferences.getInstance();
    _isDownloading = prefs.getBool(_downloadingKey) ?? false;
    return _isDownloading;
  }

  /// 设置下载状态
  static Future<void> _setDownloadingState(bool isDownloading) async {
    _isDownloading = isDownloading;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_downloadingKey, isDownloading);

    if (isDownloading) {
      // 记录开始时间
      await prefs.setInt(
          _downloadStartTimeKey, DateTime.now().millisecondsSinceEpoch);
      debugPrint('🔒 [Update] Download state locked at ${DateTime.now()}');
    } else {
      // 清除开始时间
      await prefs.remove(_downloadStartTimeKey);
      debugPrint('🔓 [Update] Download state unlocked at ${DateTime.now()}');
    }
  }

  /// 请求安装未知来源应用的权限 (Android 8.0+)
  // ignore: unused_element
  static Future<bool> _requestInstallPermission(BuildContext context) async {
    if (!Platform.isAndroid) return true;

    // Android 8.0+ 需要 REQUEST_INSTALL_PACKAGES 权限
    if (await Permission.requestInstallPackages.isGranted) {
      return true;
    }

    final status = await Permission.requestInstallPackages.request();

    if (status.isGranted) {
      return true;
    } else if (status.isDenied || status.isPermanentlyDenied) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context);
        if (l10n != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.permission_not_granted),
              action: SnackBarAction(
                label: l10n.settings,
                onPressed: () => openAppSettings(),
              ),
              duration: const Duration(seconds: 5),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
      return false;
    }

    return false;
  }

  /// 智能选择最快的下载源（多镜像支持，带缓存）
  /// 返回：最快源的URL和源名称
  static Future<Map<String, String>> _selectFastestMirror(
      String version, String fileName) async {
    final osgLabUrl = '$_osgLabMirror/$fileName';
    final githubUrl = '$_githubRelease/v$version/$fileName';

    // 检查缓存
    final prefs = await SharedPreferences.getInstance();
    final cacheTime = prefs.getInt(_mirrorCacheTimeKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final cacheAgeMinutes = (now - cacheTime) / 1000 / 60;

    // 如果缓存有效（10分钟内），使用缓存结果
    if (_cachedMirrorResult != null &&
        cacheAgeMinutes < _mirrorCacheValidMinutes) {
      debugPrint(
          '✨ [Mirror] Using cached result (age: ${cacheAgeMinutes.toInt()} min)');
      debugPrint('   Selected: ${_cachedMirrorResult!['name']}');

      // 重新构建 URL（版本号可能变化）
      final cachedName = _cachedMirrorResult!['name'] as String;
      String finalUrl;

      if (cachedName == 'OSGLab镜像') {
        finalUrl = osgLabUrl;
      } else if (cachedName == 'GitHub') {
        finalUrl = githubUrl;
      } else {
        // 找到对应的镜像前缀
        final mirror = _githubMirrors.firstWhere(
          (m) => m['name'] == cachedName,
          orElse: () => {'prefix': '', 'name': cachedName},
        );
        finalUrl = '${mirror['prefix']}$githubUrl';
      }

      return {
        'url': finalUrl,
        'name': cachedName,
        'fallbackUrl':
            _cachedMirrorResult!['fallbackUrl'] as String? ?? osgLabUrl,
        'fallbackName':
            _cachedMirrorResult!['fallbackName'] as String? ?? 'OSGLab镜像',
      };
    }

    debugPrint('🔍 Testing download mirrors...');

    // 构建所有可能的下载源
    // 注意：OSGLab 镜像速度较慢，移到最后作为兜底
    final List<Future<Map<String, dynamic>>> mirrorTests = [
      _testMirrorSpeed(githubUrl, 'GitHub'),
    ];

    // 添加 GitHub 镜像加速服务（这些通常比自建服务器快）
    for (var mirror in _githubMirrors) {
      final mirrorUrl = '${mirror['prefix']}$githubUrl';
      mirrorTests.add(_testMirrorSpeed(mirrorUrl, mirror['name']!));
    }

    // OSGLab 作为最后的备选（速度较慢但稳定）
    mirrorTests.add(_testMirrorSpeed(osgLabUrl, 'OSGLab镜像'));

    // 并行测试所有源的速度
    final results = await Future.wait(mirrorTests);

    debugPrint('📊 [Mirror Test] All results:');
    for (var r in results) {
      if (r['available']) {
        debugPrint(
            '   - ${r['name']}: ${r['speed'].toStringAsFixed(1)} KB/s (score: ${r['duration']})');
      } else {
        debugPrint('   - ${r['name']}: UNAVAILABLE');
      }
    }

    // 过滤掉不可用的源，并按速度分数排序（分数越小越快）
    final availableResults =
        results.where((r) => r['available'] == true).toList();

    debugPrint('📊 [Mirror Test] Available count: ${availableResults.length}');

    if (availableResults.isEmpty) {
      // 如果所有镜像都不可用，尝试使用缓存（即使过期）
      if (_cachedMirrorResult != null) {
        debugPrint('⚠️ All mirrors unavailable, using EXPIRED cache');
        final cachedName = _cachedMirrorResult!['name'] as String;
        String finalUrl;

        if (cachedName == 'OSGLab镜像') {
          finalUrl = osgLabUrl;
        } else if (cachedName == 'GitHub') {
          finalUrl = githubUrl;
        } else {
          final mirror = _githubMirrors.firstWhere(
            (m) => m['name'] == cachedName,
            orElse: () => {'prefix': '', 'name': cachedName},
          );
          finalUrl = '${mirror['prefix']}$githubUrl';
        }

        return {
          'url': finalUrl,
          'name': cachedName,
          'fallbackUrl':
              _cachedMirrorResult!['fallbackUrl'] as String? ?? osgLabUrl,
          'fallbackName':
              _cachedMirrorResult!['fallbackName'] as String? ?? 'OSGLab镜像',
        };
      }

      // 如果没有缓存，返回 GitHub 直连作为兜底
      debugPrint('⚠️ All mirrors unavailable, falling back to GitHub');
      return {
        'url': githubUrl,
        'name': 'GitHub',
        'fallbackUrl': osgLabUrl,
        'fallbackName': 'OSGLab镜像',
      };
    }

    availableResults.sort((a, b) => a['duration'].compareTo(b['duration']));

    final fastest = availableResults.first;
    final fallback =
        availableResults.length > 1 ? availableResults[1] : results.last;

    debugPrint(
        '✅ Fastest: ${fastest['name']} (${fastest['speed'].toStringAsFixed(1)} KB/s)');
    debugPrint(
        '⏱️ Fallback: ${fallback['name']} (${fallback.containsKey('speed') ? '${fallback['speed'].toStringAsFixed(1)} KB/s' : 'N/A'})');

    if (availableResults.length > 2) {
      debugPrint('📊 Other available mirrors: ${availableResults.length - 1}');
    }

    // 保存到缓存
    final result = {
      'url': fastest['url'] as String,
      'name': fastest['name'] as String,
      'fallbackUrl': fallback['url'] as String,
      'fallbackName': fallback['name'] as String,
    };

    _cachedMirrorResult = result;
    await prefs.setInt(
        _mirrorCacheTimeKey, DateTime.now().millisecondsSinceEpoch);
    debugPrint(
        '💾 [Mirror] Result cached for ${_mirrorCacheValidMinutes} minutes');

    return result;
  }

  /// 测试单个镜像的实际下载速度
  /// 通过下载文件的前 512KB 来测试实际速度，而不是只测试 HEAD 请求
  static Future<Map<String, dynamic>> _testMirrorSpeed(
      String url, String name) async {
    debugPrint('🔍 [Mirror Test] Testing $name...');

    try {
      // 发起 GET 请求，限制下载前 512KB
      final request = http.Request('GET', Uri.parse(url));
      request.headers['Range'] = 'bytes=0-524287'; // 512KB

      final client = http.Client();
      final streamedResponse = await client.send(request).timeout(
            const Duration(seconds: 5),
          );

      if (streamedResponse.statusCode == 200 ||
          streamedResponse.statusCode == 206) {
        // 206 = Partial Content

        int bytesDownloaded = 0;
        final downloadStartTime = DateTime.now();

        // 监听数据流，计算下载速度
        await for (var chunk in streamedResponse.stream) {
          bytesDownloaded += chunk.length;

          // 下载够 256KB 就停止测试（足够评估速度）
          if (bytesDownloaded >= 262144) {
            break;
          }
        }

        final downloadDuration = DateTime.now().difference(downloadStartTime);
        final durationMs = downloadDuration.inMilliseconds;

        // 计算速度 (KB/s)
        final speedKBps =
            durationMs > 0 ? (bytesDownloaded / 1024) / (durationMs / 1000) : 0;

        // 使用速度的倒数作为 duration（速度越快，duration 越小）
        // 将 KB/s 转换为 duration：1000 / speedKBps
        final speedScore = speedKBps > 0 ? (1000 / speedKBps).round() : 999999;

        client.close();

        debugPrint(
            '✅ [Mirror Test] $name OK: ${speedKBps.toStringAsFixed(1)} KB/s (score: $speedScore)');

        return {
          'url': url,
          'name': name,
          'duration': speedScore, // 用速度分数排序
          'speed': speedKBps, // 实际速度
          'available': true,
        };
      } else {
        client.close();
        debugPrint(
            '⚠️ [Mirror Test] $name returned ${streamedResponse.statusCode}');
        return {
          'url': url,
          'name': name,
          'duration': 999999,
          'speed': 0,
          'available': false,
        };
      }
    } catch (e) {
      debugPrint('❌ [Mirror Test] $name FAILED: $e');
      return {
        'url': url,
        'name': name,
        'duration': 999999,
        'speed': 0,
        'available': false,
      };
    }
  }

  static Future<void> checkUpdate(BuildContext context,
      {bool showNoUpdate = false}) async {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return;

    try {
      // 从 GitHub 获取更新信息
      final response = await http
          .get(Uri.parse(_githubApiUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestTag = data['tag_name'] as String;
        final releaseNotes = (data['body'] ?? '') as String;
        final htmlUrl = (data['html_url'] ?? '') as String;

        // iOS 的跳转链接 (当前使用 TestFlight 链接)
        const String appStoreUrl = 'https://testflight.apple.com/join/e9E3RRBh';

        String? apkUrl;
        String? apkName;
        if (data['assets'] != null) {
          final assets = data['assets'] as List;
          final apkAsset = assets.firstWhere(
            (asset) => (asset['name'] as String).endsWith('.apk'),
            orElse: () => null,
          );
          if (apkAsset != null) {
            apkUrl = apkAsset['browser_download_url'] as String;
            apkName = apkAsset['name'] as String;
          }
        }

        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;
        final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

        // 解析远程版本和构建号
        String latestVersion = latestTag.replaceAll('v', '');
        int latestBuild = 0;

        // 优先从 Tag 中解析构建号 (e.g. v2.0.1+12)
        if (latestVersion.contains('+')) {
          final parts = latestVersion.split('+');
          latestVersion = parts[0];
          latestBuild = int.tryParse(parts[1]) ?? 0;
        }

        // 如果 Tag 里没有构建号，尝试从文件名中提取 (e.g. Puked-2.0.1+12.apk)
        if (latestBuild == 0 && apkName != null && apkName.contains('+')) {
          final match = RegExp(r'\+(\d+)').firstMatch(apkName);
          if (match != null) {
            latestBuild = int.tryParse(match.group(1)!) ?? 0;
          }
        }

        if (_isNewer(latestVersion, currentVersion,
            latestBuild: latestBuild, currentBuild: currentBuild)) {
          if (context.mounted) {
            String downloadUrl;
            String? mirrorName;

            if (Platform.isAndroid && apkName != null) {
              // Android: 智能选择最快的下载源
              final fileName = 'Puked-$latestVersion.apk';

              // 显示"正在选择最快下载源"提示
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.selecting_best_mirror),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );

              // 选择最快的镜像
              final mirrorInfo =
                  await _selectFastestMirror(latestVersion, fileName);
              downloadUrl = mirrorInfo['url']!;
              mirrorName = mirrorInfo['name']!;

              debugPrint('📥 Selected download source: $mirrorName');
            } else if (Platform.isIOS) {
              downloadUrl = appStoreUrl;
            } else {
              downloadUrl = apkUrl ?? htmlUrl;
            }

            _showUpdateDialog(
              context,
              latestTag,
              releaseNotes,
              downloadUrl,
              l10n,
              isApk: Platform.isAndroid,
              mirrorName: mirrorName,
            );
          }
        } else if (showNoUpdate) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.current_version),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
  }

  static bool _isNewer(String latestVersion, String currentVersion,
      {int latestBuild = 0, int currentBuild = 0}) {
    try {
      // 1. 对比版本名 (Major.Minor.Patch)
      // 过滤掉可能存在的构建号干扰，只取前三段数字
      List<int> latestParts = latestVersion
          .split('+')[0]
          .split('.')
          .take(3)
          .map((e) => int.tryParse(e) ?? 0)
          .toList();
      List<int> currentParts = currentVersion
          .split('+')[0]
          .split('.')
          .take(3)
          .map((e) => int.tryParse(e) ?? 0)
          .toList();

      for (int i = 0; i < 3; i++) {
        int l = i < latestParts.length ? latestParts[i] : 0;
        int c = i < currentParts.length ? currentParts[i] : 0;
        if (l > c) {
          debugPrint(
              '✅ Newer version detected by version name: $latestVersion > $currentVersion');
          return true;
        }
        if (l < c) {
          debugPrint(
              'ℹ️ Local version is newer than remote: $currentVersion > $latestVersion');
          return false;
        }
      }

      // 2. 如果版本名相同，对比构建号 (Case A)
      final isNewerBuild = latestBuild > currentBuild;
      debugPrint(
          '🔍 Comparing build numbers: remote($latestBuild) ${isNewerBuild ? ">" : "<="} local($currentBuild)');
      return isNewerBuild;
    } catch (e) {
      // 兜底：如果解析出错，仅当版本名或构建号不完全一致时（且非空）尝试更新
      return (latestVersion != currentVersion || latestBuild != currentBuild) &&
          latestVersion.isNotEmpty;
    }
  }

  static void _showUpdateDialog(BuildContext context, String version,
      String notes, String url, AppLocalizations l10n,
      {bool isApk = false, String? mirrorName}) {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            Text(
              l10n.new_version_found,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              version,
              style: TextStyle(
                color: colorScheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 24),
              Text(
                l10n.changelog,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    notes,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    l10n.later,
                    style: const TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    // 只负责打开官网，并带上锚点建议网页端弹出下载选择
                    final officialWebsite =
                        Uri.parse('https://puked.osglab.com/#download');
                    try {
                      if (await canLaunchUrl(officialWebsite)) {
                        await launchUrl(officialWebsite,
                            mode: LaunchMode.externalApplication);
                      }
                      // 打开官网后关闭 App 里的更新弹窗
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      debugPrint('⚠️ Could not launch official website: $e');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  child: const Text(
                    '打开官网',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  static void _showDownloadProgress(BuildContext context, String url,
      AppLocalizations l10n, String version, String? mirrorName) {
    final colorScheme = Theme.of(context).colorScheme;

    // 设置下载状态标志
    _setDownloadingState(true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) {
            // 用户通过返回键/手势关闭对话框时，重置下载状态
            if (didPop) {
              debugPrint('⚠️ [Update] User cancelled download');
              _setDownloadingState(false);
            }
          },
          child: AlertDialog(
            backgroundColor: colorScheme.surface,
            surfaceTintColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Column(
              children: [
                Text(
                  l10n.downloading_update,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  version,
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // 显示下载源
                if (mirrorName != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_download,
                          size: 16,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          mirrorName,
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            content: StreamBuilder<OtaEvent>(
              stream: OtaUpdate().execute(
                url,
                destinationFilename: 'puked_update.apk',
                androidProviderAuthority:
                    'com.osglab.puked.ota_update_provider',
                // 注意：sha256checksum 参数被注释，因为当前没有从 Release 中获取 SHA256
                // sha256checksum: expectedSha256,
              ),
              builder: (context, snapshot) {
                double progress = 0;
                String statusText = l10n.processing;
                bool isError = false;
                bool isConnecting =
                    snapshot.connectionState == ConnectionState.waiting;

                if (snapshot.hasData) {
                  final event = snapshot.data!;
                  debugPrint(
                      '📥 [Update] OTA Status: ${event.status}, Value: ${event.value}');

                  switch (event.status) {
                    case OtaStatus.DOWNLOADING:
                      final val = double.tryParse(event.value ?? '0') ?? 0;
                      progress = val;
                      statusText = l10n.downloading;
                      // 如果 progress 为 0，说明刚开始连接
                      if (progress <= 0) isConnecting = true;
                      break;
                    case OtaStatus.INSTALLING:
                      // 下载完成，尝试手动触发安装
                      statusText = l10n.processing;
                      progress = 100;

                      debugPrint(
                          '✅ [Update] Download completed, triggering installation manually');

                      // 清理下载状态
                      _setDownloadingState(false);

                      // 使用 open_file 手动触发安装（ota_update 插件有时不会自动触发）
                      _triggerManualInstall(context);

                      // 延迟关闭对话框
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (context.mounted) Navigator.of(context).pop();
                      });
                      break;
                    case OtaStatus.ALREADY_RUNNING_ERROR:
                      statusText = l10n.download_failed;
                      isError = true;
                      _setDownloadingState(false);
                      break;
                    case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
                      statusText = l10n.permission_not_granted;
                      isError = true;
                      _setDownloadingState(false);
                      break;
                    case OtaStatus.INTERNAL_ERROR:
                    case OtaStatus.DOWNLOAD_ERROR:
                    case OtaStatus.CHECKSUM_ERROR:
                      statusText = l10n.download_failed;
                      isError = true;
                      _setDownloadingState(false);
                      break;
                    default:
                      statusText = l10n.processing;
                  }
                } else if (snapshot.hasError) {
                  debugPrint('❌ OTA Error: ${snapshot.error}');
                  statusText = l10n.network_error;
                  isError = true;
                  _setDownloadingState(false);
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: isConnecting ? null : progress / 100,
                            minHeight: 12,
                            backgroundColor:
                                colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                colorScheme.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isConnecting ? '${l10n.processing}...' : statusText,
                          style: TextStyle(
                            fontSize: 13,
                            color: isError
                                ? Colors.red
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (!isConnecting)
                          Text(
                            '${progress.toInt()}%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                    if (isError)
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Column(
                          children: [
                            Text(
                              l10n.ensure_network_tip,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                onPressed: () {
                                  _setDownloadingState(false); // 用户关闭时重置状态
                                  Navigator.pop(context);
                                },
                                child: Text(
                                  l10n.back,
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// 手动触发 APK 安装
  /// 当 ota_update 插件不自动触发安装时，使用此方法
  static Future<void> _triggerManualInstall(BuildContext context) async {
    try {
      debugPrint('🔍 [Update] Searching for downloaded APK...');

      // 遍历所有可能的目录：internal cache, internal files, external cache, external files
      final List<String> searchPaths = [
        '/data/user/0/com.osglab.puked/cache',
        '/data/user/0/com.osglab.puked/files',
        '/storage/emulated/0/Android/data/com.osglab.puked/cache',
        '/storage/emulated/0/Android/data/com.osglab.puked/files',
      ];

      String? apkPath;

      for (final path in searchPaths) {
        final dir = Directory(path);
        if (await dir.exists()) {
          debugPrint('📂 [Update] Checking directory: $path');
          try {
            final files = dir.listSync();
            for (var file in files) {
              if (file.path.endsWith('.apk')) {
                // 检查文件大小，确保不是 0 字节
                final stat = await file.stat();
                if (stat.size > 1024 * 1024) {
                  // 大于 1MB 才是有效的 APK
                  apkPath = file.path;
                  debugPrint(
                      '📦 [Update] Found valid APK at: $apkPath (${(stat.size / 1024 / 1024).toStringAsFixed(1)} MB)');
                  break;
                }
              }
            }
          } catch (e) {
            debugPrint('⚠️ [Update] Could not list files in $path: $e');
          }
        }
        if (apkPath != null) break;
      }

      if (apkPath != null) {
        debugPrint('🚀 [Update] Opening APK with open_file plugin');
        final result = await OpenFile.open(apkPath);
        debugPrint(
            '📊 [Update] open_file result: ${result.type}, message: ${result.message}');

        if (result.type != ResultType.done) {
          // 如果还是失败，可能是权限问题，尝试第二次使用不同方式
          debugPrint(
              '🔄 [Update] Retrying installation with different approach...');
        }
      } else {
        debugPrint('❌ [Update] No valid APK file found anywhere!');
      }
    } catch (e) {
      debugPrint('❌ [Update] Error in manual install flow: $e');
    }
  }
}
