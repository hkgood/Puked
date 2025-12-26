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
  static const String _apiUrl = 'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  static Future<void> checkUpdate(BuildContext context, {bool showNoUpdate = false}) async {
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
            _showUpdateDialog(context, latestTag, releaseNotes, apkUrl ?? htmlUrl, l10n, isApk: apkUrl != null);
          }
        } else if (showNoUpdate) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.localeName == 'zh' ? '当前已是最新版本' : 'Already up to date'),
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
      List<int> latestParts = latest.split('.').take(3).map((e) => int.tryParse(e) ?? 0).toList();
      List<int> currentParts = current.split('.').take(3).map((e) => int.tryParse(e) ?? 0).toList();

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

  static void _showUpdateDialog(
    BuildContext context, 
    String version, 
    String notes, 
    String url, 
    AppLocalizations l10n,
    {bool isApk = false}
  ) {
    final isZh = l10n.localeName == 'zh';
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isZh ? '发现新版本 $version' : 'New Version Found $version',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isZh ? '更新内容：' : 'What\'s New:', 
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Text(notes, style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isZh ? '稍后再说' : 'Later', style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (Platform.isAndroid && isApk) {
                _showDownloadProgress(context, url, l10n);
              } else {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(isZh ? '立即更新' : 'Update Now'),
          ),
        ],
      ),
    );
  }

  static void _showDownloadProgress(BuildContext context, String url, AppLocalizations l10n) {
    final isZh = l10n.localeName == 'zh';
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(isZh ? '正在下载更新...' : 'Downloading Update...'),
              content: StreamBuilder<OtaEvent>(
                stream: OtaUpdate().execute(
                  url, 
                  destinationFilename: 'puked_update.apk',
                  androidProviderAuthority: 'com.example.puked.ota_update_provider',
                ),
                builder: (context, snapshot) {
                  double progress = 0;
                  String statusText = '';
                  
                  if (snapshot.hasData) {
                    switch (snapshot.data!.status) {
                      case OtaStatus.DOWNLOADING:
                        statusText = isZh ? '正在下载: ${snapshot.data!.value}%' : 'Downloading: ${snapshot.data!.value}%';
                        progress = double.tryParse(snapshot.data!.value ?? '0') ?? 0;
                        break;
                      case OtaStatus.INSTALLING:
                        statusText = isZh ? '正在准备安装...' : 'Preparing to install...';
                        progress = 100;
                        Future.delayed(const Duration(seconds: 1), () {
                          if (context.mounted) Navigator.of(context).pop();
                        });
                        break;
                      case OtaStatus.ALREADY_RUNNING_ERROR:
                        statusText = isZh ? '已有下载任务正在运行' : 'Download already running';
                        break;
                      case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
                        statusText = isZh ? '缺少安装权限' : 'Permission not granted';
                        break;
                      case OtaStatus.INTERNAL_ERROR:
                      case OtaStatus.DOWNLOAD_ERROR:
                      case OtaStatus.CHECKSUM_ERROR:
                        statusText = isZh ? '下载失败，请稍后重试' : 'Download failed, please try again';
                        break;
                      default:
                        statusText = isZh ? '处理中...' : 'Processing...';
                    }
                  } else if (snapshot.hasError) {
                    statusText = isZh ? '发生错误: ${snapshot.error}' : 'Error: ${snapshot.error}';
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: progress / 100,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                      ),
                      const SizedBox(height: 16),
                      Text(statusText, style: const TextStyle(fontSize: 14)),
                      if (snapshot.hasError || (snapshot.hasData && snapshot.data!.status.index > OtaStatus.INSTALLING.index))
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text(isZh ? '关闭' : 'Close'),
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
