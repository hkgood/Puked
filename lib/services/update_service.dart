import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ota_update/ota_update.dart';
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
        debugPrint('🧹 [Update] Cleaning stale download state (${elapsedMinutes.toInt()} minutes old)');
        await prefs.setBool(_downloadingKey, false);
        await prefs.remove(_downloadStartTimeKey);
        _isDownloading = false;
      }
    }
  }

  /// 检查是否有正在进行的下载任务
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
      await prefs.setInt(_downloadStartTimeKey, DateTime.now().millisecondsSinceEpoch);
      debugPrint('🔒 [Update] Download state locked at ${DateTime.now()}');
    } else {
      // 清除开始时间
      await prefs.remove(_downloadStartTimeKey);
      debugPrint('🔓 [Update] Download state unlocked at ${DateTime.now()}');
    }
  }

  /// 请求安装未知来源应用的权限 (Android 8.0+)
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

  /// 智能选择最快的下载源（多镜像支持）
  /// 返回：最快源的URL和源名称
  static Future<Map<String, String>> _selectFastestMirror(
      String version, String fileName) async {
    final osgLabUrl = '$_osgLabMirror/$fileName';
    final githubUrl = '$_githubRelease/v$version/$fileName';

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
      debugPrint('   - ${r['name']}: ${r['available'] ? '${r['duration']}ms' : 'UNAVAILABLE'}');
    }

    // 过滤掉不可用的源，并按响应时间排序
    final availableResults = results.where((r) => r['available'] == true).toList();
    
    debugPrint('📊 [Mirror Test] Available count: ${availableResults.length}');
    
    if (availableResults.isEmpty) {
      // 如果所有镜像都不可用，返回 GitHub 直连作为兜底
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
    final fallback = availableResults.length > 1 ? availableResults[1] : results.last;

    debugPrint('✅ Fastest: ${fastest['name']} (${fastest['duration']}ms)');
    debugPrint('⏱️ Fallback: ${fallback['name']} (${fallback['duration']}ms)');
    
    if (availableResults.length > 2) {
      debugPrint('📊 Other available mirrors: ${availableResults.length - 1}');
    }

    return {
      'url': fastest['url'] as String,
      'name': fastest['name'] as String,
      'fallbackUrl': fallback['url'] as String,
      'fallbackName': fallback['name'] as String,
    };
  }

  /// 测试单个镜像的响应速度
  static Future<Map<String, dynamic>> _testMirrorSpeed(
      String url, String name) async {
    final startTime = DateTime.now();
    
    debugPrint('🔍 [Mirror Test] Testing $name...');

    try {
      // 使用 HEAD 请求测试响应速度（不下载完整文件）
      // 缩短超时时间为 3 秒，加快测速
      final response =
          await http.head(Uri.parse(url)).timeout(const Duration(seconds: 3));

      final duration = DateTime.now().difference(startTime).inMilliseconds;

      if (response.statusCode == 200 || response.statusCode == 302) {
        debugPrint('✅ [Mirror Test] $name OK: ${duration}ms (status: ${response.statusCode})');
        return {
          'url': url,
          'name': name,
          'duration': duration,
          'available': true,
        };
      } else {
        debugPrint('⚠️ [Mirror Test] $name returned ${response.statusCode}');
        return {
          'url': url,
          'name': name,
          'duration': 999999, // 大数值，确保排到后面
          'available': false,
        };
      }
    } catch (e) {
      debugPrint('❌ [Mirror Test] $name FAILED: $e');
      return {
        'url': url,
        'name': name,
        'duration': 999999,
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
                  content: Text(l10n.selecting_best_mirror ?? '正在选择最快下载源...'),
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
          debugPrint('✅ Newer version detected by version name: $latestVersion > $currentVersion');
          return true;
        }
        if (l < c) {
          debugPrint('ℹ️ Local version is newer than remote: $currentVersion > $latestVersion');
          return false;
        }
      }

      // 2. 如果版本名相同，对比构建号 (Case A)
      final isNewerBuild = latestBuild > currentBuild;
      debugPrint('🔍 Comparing build numbers: remote($latestBuild) ${isNewerBuild ? ">" : "<="} local($currentBuild)');
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
                    // 检查是否已经在下载中
                    if (_isDownloading) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.downloading_update),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                      return;
                    }

                    if (Platform.isAndroid && isApk) {
                      // ✅ 先请求安装权限（在关闭对话框之前）
                      final hasPermission = await _requestInstallPermission(context);
                      if (!hasPermission) {
                        debugPrint('❌ [Update] Install permission denied');
                        return;
                      }
                      
                      // ✅ 权限通过后，再关闭对话框
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                      
                      debugPrint('✅ [Update] Install permission granted, starting download');
                      
                      // ✅ 使用新的 context 显示下载进度
                      if (context.mounted) {
                        _showDownloadProgress(context, url, l10n, version, mirrorName);
                      }
                    } else {
                      // 非 Android 或非 APK，直接关闭对话框并打开浏览器
                      Navigator.pop(context);
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
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
                  child: Text(
                    l10n.update_now,
                    style: const TextStyle(
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

  static void _showDownloadProgress(
      BuildContext context, String url, AppLocalizations l10n, String version, String? mirrorName) {
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
              androidProviderAuthority: 'com.osglab.puked.ota_update_provider',
              // 注意：sha256checksum 参数被注释，因为当前没有从 Release 中获取 SHA256
              // sha256checksum: expectedSha256,
            ),
            builder: (context, snapshot) {
              double progress = 0;
              String statusText = l10n.processing;
              bool isError = false;
              bool isConnecting = snapshot.connectionState == ConnectionState.waiting;

              if (snapshot.hasData) {
                final event = snapshot.data!;
                debugPrint('📥 [Update] OTA Status: ${event.status}, Value: ${event.value}');
                
                switch (event.status) {
                  case OtaStatus.DOWNLOADING:
                    final val = double.tryParse(event.value ?? '0') ?? 0;
                    progress = val;
                    statusText = l10n.downloading;
                    // 如果 progress 为 0，说明刚开始连接
                    if (progress <= 0) isConnecting = true;
                    break;
                  case OtaStatus.INSTALLING:
                    // 下载完成，插件即将触发安装 Intent
                    statusText = l10n.processing;
                    progress = 100;
                    
                    debugPrint('✅ [Update] Download completed, installation will start automatically');
                    
                    // 清理下载状态
                    _setDownloadingState(false);
                    
                    // 延迟关闭对话框，让用户看到"准备安装"的提示
                    // 注意：此时插件会自动触发系统安装对话框
                    Future.delayed(const Duration(milliseconds: 800), () {
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
                          backgroundColor: colorScheme.surfaceContainerHighest,
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
}
