import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ota_update/ota_update.dart';
import 'package:puked/generated/l10n/app_localizations.dart';

class UpdateService {
  static const String _owner = 'hkgood';
  static const String _repo = 'Puked';
  static const String _githubApiUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  // 下载源配置
  static const String _osgLabMirror = 'https://download.osglab.com/PukedAPK';
  static const String _githubRelease =
      'https://github.com/$_owner/$_repo/releases/download';

  // 防止重复下载的状态锁
  static bool _isDownloading = false;

  /// 智能选择最快的下载源
  /// 返回：最快源的URL和源名称
  static Future<Map<String, String>> _selectFastestMirror(
      String version, String fileName) async {
    final osgLabUrl = '$_osgLabMirror/$fileName';
    final githubUrl = '$_githubRelease/v$version/$fileName';

    debugPrint('🔍 Testing download mirrors...');

    // 并行测试两个源的速度
    final results = await Future.wait([
      _testMirrorSpeed(osgLabUrl, 'OSGLab镜像'),
      _testMirrorSpeed(githubUrl, 'GitHub'),
    ]);

    // 按响应时间排序
    results.sort((a, b) => a['duration'].compareTo(b['duration']));

    final fastest = results.first;
    final fallback = results.last;

    debugPrint('✅ Fastest: ${fastest['name']} (${fastest['duration']}ms)');
    debugPrint('⏱️ Fallback: ${fallback['name']} (${fallback['duration']}ms)');

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

    try {
      // 使用 HEAD 请求测试响应速度（不下载完整文件）
      final response =
          await http.head(Uri.parse(url)).timeout(const Duration(seconds: 5));

      final duration = DateTime.now().difference(startTime).inMilliseconds;

      if (response.statusCode == 200 || response.statusCode == 302) {
        return {
          'url': url,
          'name': name,
          'duration': duration,
          'available': true,
        };
      } else {
        debugPrint('⚠️ $name returned ${response.statusCode}');
        return {
          'url': url,
          'name': name,
          'duration': 999999, // 大数值，确保排到后面
          'available': false,
        };
      }
    } catch (e) {
      debugPrint('❌ $name test failed: $e');
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

              debugPrint('📥 Selected download source: ${mirrorInfo['name']}');
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
        if (l > c) return true; // 情况 B: 远程大版本更新
        if (l < c) return false; // 情况 C: 远程版本更旧，拦截
      }

      // 2. 如果版本名相同，对比构建号 (Case A)
      return latestBuild > currentBuild;
    } catch (e) {
      // 兜底：如果解析出错，仅当版本名或构建号不完全一致时（且非空）尝试更新
      return (latestVersion != currentVersion || latestBuild != currentBuild) &&
          latestVersion.isNotEmpty;
    }
  }

  static void _showUpdateDialog(BuildContext context, String version,
      String notes, String url, AppLocalizations l10n,
      {bool isApk = false}) {
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
                    Navigator.pop(context);

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
                      _showDownloadProgress(context, url, l10n, version);
                    } else {
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
      BuildContext context, String url, AppLocalizations l10n, String version) {
    final colorScheme = Theme.of(context).colorScheme;

    // 设置下载状态标志
    _isDownloading = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
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
            ],
          ),
          content: StreamBuilder<OtaEvent>(
            stream: OtaUpdate().execute(
              url,
              destinationFilename: 'puked_update.apk',
              androidProviderAuthority: 'com.osglab.puked.ota_update_provider',
            ),
            builder: (context, snapshot) {
              double progress = 0;
              String statusText = '';
              bool isError = false;

              if (snapshot.hasData) {
                switch (snapshot.data!.status) {
                  case OtaStatus.DOWNLOADING:
                    progress =
                        double.tryParse(snapshot.data!.value ?? '0') ?? 0;
                    statusText = l10n.downloading;
                    break;
                  case OtaStatus.INSTALLING:
                    statusText = l10n.processing;
                    progress = 100;
                    Future.delayed(const Duration(seconds: 1), () {
                      _isDownloading = false; // 重置状态
                      if (context.mounted) Navigator.of(context).pop();
                    });
                    break;
                  case OtaStatus.ALREADY_RUNNING_ERROR:
                    statusText = l10n.download_failed;
                    isError = true;
                    _isDownloading = false; // 重置状态
                    break;
                  case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
                    statusText = l10n.permission_not_granted;
                    isError = true;
                    _isDownloading = false; // 重置状态
                    break;
                  case OtaStatus.INTERNAL_ERROR:
                  case OtaStatus.DOWNLOAD_ERROR:
                  case OtaStatus.CHECKSUM_ERROR:
                    statusText = l10n.download_failed;
                    isError = true;
                    _isDownloading = false; // 重置状态
                    break;
                  default:
                    statusText = l10n.processing;
                }
              } else if (snapshot.hasError) {
                statusText = l10n.network_error;
                isError = true;
                _isDownloading = false; // 重置状态
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
                          value: progress / 100,
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
                        statusText,
                        style: TextStyle(
                          fontSize: 13,
                          color: isError
                              ? Colors.red
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
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
                                _isDownloading = false; // 用户关闭时重置状态
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
        );
      },
    );
  }
}
