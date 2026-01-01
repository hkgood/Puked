import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ota_update/ota_update.dart';
import 'package:puked/generated/l10n/app_localizations.dart';

class UpdateService {
  static const String _owner = 'hkgood';
  static const String _repo = 'Puked';
  static const String _apiUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  static Future<void> checkUpdate(BuildContext context,
      {bool showNoUpdate = false}) async {
    // iOS 不需要应用内更新功能，统一由 App Store 处理
    if (Platform.isIOS) return;

    final l10n = AppLocalizations.of(context);
    if (l10n == null) return;

    try {
      final response = await http.get(Uri.parse(_apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestTag = data['tag_name'] as String;
        final latestVersion = latestTag.replaceAll('v', '');
        final releaseNotes = data['body'] as String;
        final htmlUrl = data['html_url'] as String;

        String? apkUrl;
        if (data['assets'] != null) {
          final assets = data['assets'] as List;
          final apkAsset = assets.firstWhere(
            (asset) => (asset['name'] as String).endsWith('.apk'),
            orElse: () => null,
          );
          if (apkAsset != null) {
            apkUrl = apkAsset['browser_download_url'] as String;
          }
        }

        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

        if (_isNewer(latestVersion, currentVersion)) {
          if (context.mounted) {
            _showUpdateDialog(
                context, latestTag, releaseNotes, apkUrl ?? htmlUrl, l10n,
                isApk: apkUrl != null);
          }
        } else if (showNoUpdate) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.localeName == 'zh'
                    ? '当前已是最新版本'
                    : 'Already up to date'),
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

  static bool _isNewer(String latest, String current) {
    try {
      List<int> latestParts =
          latest.split('.').take(3).map((e) => int.tryParse(e) ?? 0).toList();
      List<int> currentParts =
          current.split('.').take(3).map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < 3; i++) {
        int l = i < latestParts.length ? latestParts[i] : 0;
        int c = i < currentParts.length ? currentParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
    } catch (e) {
      return latest != current;
    }
    return false;
  }

  static void _showUpdateDialog(BuildContext context, String version,
      String notes, String url, AppLocalizations l10n,
      {bool isApk = false}) {
    final isZh = l10n.localeName == 'zh';
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
              isZh ? '发现新版本' : 'New Version Found',
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
                isZh ? '更新内容' : 'Changelog',
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
                    isZh ? '稍后再说' : 'Later',
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
                    isZh ? '立即更新' : 'Update Now',
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
    final isZh = l10n.localeName == 'zh';
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              title: Column(
                children: [
                  Text(
                    isZh ? '正在下载更新' : 'Downloading Update',
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
                  androidProviderAuthority:
                      'com.osglab.puked.ota_update_provider',
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
                        statusText = isZh ? '正在下载...' : 'Downloading...';
                        break;
                      case OtaStatus.INSTALLING:
                        statusText =
                            isZh ? '正在准备安装...' : 'Preparing to install...';
                        progress = 100;
                        Future.delayed(const Duration(seconds: 1), () {
                          if (context.mounted) Navigator.of(context).pop();
                        });
                        break;
                      case OtaStatus.ALREADY_RUNNING_ERROR:
                        statusText =
                            isZh ? '已有下载任务正在运行' : 'Download already running';
                        isError = true;
                        break;
                      case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
                        statusText = isZh ? '缺少安装权限' : 'Permission not granted';
                        isError = true;
                        break;
                      case OtaStatus.INTERNAL_ERROR:
                      case OtaStatus.DOWNLOAD_ERROR:
                      case OtaStatus.CHECKSUM_ERROR:
                        statusText = isZh
                            ? '下载失败，请稍后重试'
                            : 'Download failed, please try again';
                        isError = true;
                        break;
                      default:
                        statusText = isZh ? '处理中...' : 'Processing...';
                    }
                  } else if (snapshot.hasError) {
                    statusText = isZh
                        ? '发生错误: ${snapshot.error}'
                        : 'Error: ${snapshot.error}';
                    isError = true;
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
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: colorScheme.errorContainer,
                                foregroundColor: colorScheme.onErrorContainer,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                isZh ? '关闭' : 'Close',
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
