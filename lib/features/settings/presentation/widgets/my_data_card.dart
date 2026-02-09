import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:puked/common/utils/i18n.dart';
import 'package:puked/generated/l10n/app_localizations.dart';
import 'package:puked/features/settings/providers/my_stats_provider.dart';
import 'package:puked/features/arena/providers/arena_provider.dart';
import 'package:puked/common/widgets/brand_logo.dart';
import 'package:puked/features/auth/providers/auth_provider.dart';
import 'package:puked/services/pocketbase_service.dart';
import 'package:puked/common/theme/app_theme.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class MyDataCard extends ConsumerStatefulWidget {
  const MyDataCard({super.key});

  @override
  ConsumerState<MyDataCard> createState() => _MyDataCardState();
}

class _MyDataCardState extends ConsumerState<MyDataCard> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isCompressing = false; // 批量压缩状态标记

  /// 批量压缩数据库中所有用户的车辆认证图片
  Future<void> _compressAllCertificationImages() async {
    if (_isCompressing) return;

    final pb = ref.read(pbServiceProvider).pb;

    // 确认对话框
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('批量压缩认证图片'),
        content: const Text(
          '此操作将压缩所有用户的车辆认证图片（长边>2000px），处理时间较长，确认执行？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCompressing = true);

    try {
      // 获取所有用户
      final usersRecords = await pb.collection('users').getFullList(
            sort: '-created',
          );

      int totalProcessed = 0;
      int totalCompressed = 0;
      int totalSkipped = 0;
      int totalFailed = 0;

      for (final user in usersRecords) {
        final certImages = user.getListValue<String>('certification_images');
        if (certImages.isEmpty) continue;

        for (final imageFileName in certImages) {
          totalProcessed++;

          try {
            // 1. 下载原图
            final imageUrl = pb.files.getUrl(user, imageFileName).toString();
            final response = await http.get(Uri.parse(imageUrl));
            if (response.statusCode != 200) {
              debugPrint('[压缩] 下载失败: $imageFileName');
              totalFailed++;
              continue;
            }

            final originalBytes = response.bodyBytes;

            // 2. 检测尺寸
            final decodedImage = await decodeImageFromList(originalBytes);
            final width = decodedImage.width;
            final height = decodedImage.height;
            final longerSide = width > height ? width : height;

            // 3. 跳过已满足条件的图片
            if (longerSide <= 2000) {
              debugPrint('[压缩] 跳过: $imageFileName (${width}x$height)');
              totalSkipped++;
              continue;
            }

            // 4. 执行压缩
            final tempDir = await getTemporaryDirectory();
            final originalFile = File('${tempDir.path}/$imageFileName');
            await originalFile.writeAsBytes(originalBytes);

            int targetWidth, targetHeight;
            if (width > height) {
              targetWidth = 2000;
              targetHeight = (height * 2000 / width).round();
            } else {
              targetHeight = 2000;
              targetWidth = (width * 2000 / height).round();
            }

            final ext = path.extension(imageFileName).toLowerCase();
            final isJpg = ext == '.jpg' || ext == '.jpeg';

            final compressedBytes = await FlutterImageCompress.compressWithFile(
              originalFile.path,
              minWidth: targetWidth,
              minHeight: targetHeight,
              quality: isJpg ? 90 : 100,
            );

            if (compressedBytes == null) {
              totalFailed++;
              continue;
            }

            // 5. 重新上传（覆盖原文件）
            final compressedFile =
                File('${tempDir.path}/compressed_$imageFileName');
            await compressedFile.writeAsBytes(compressedBytes);

            final multipartFile = await http.MultipartFile.fromPath(
              'certification_images',
              compressedFile.path,
              filename: imageFileName, // 保持原文件名
            );

            await pb.collection('users').update(
              user.id,
              files: [multipartFile],
            );

            totalCompressed++;
            debugPrint(
                '[压缩] 成功: $imageFileName (${width}x$height -> ${targetWidth}x$targetHeight)');

            // 清理临时文件
            await originalFile.delete();
            await compressedFile.delete();
          } catch (e) {
            debugPrint('[压缩] 处理失败 $imageFileName: $e');
            totalFailed++;
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '压缩完成！处理: $totalProcessed 张，压缩: $totalCompressed 张，跳过: $totalSkipped 张，失败: $totalFailed 张',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('批量压缩失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCompressing = false);
    }
  }

  Future<void> _shareStatsCard(
      MyStats stats, I18n i18n, Rect? sharePositionOrigin) async {
    final auth = ref.read(authProvider);
    final pb = ref.read(pbServiceProvider);
    final container = ProviderScope.containerOf(context);

    // --- 终极全厂商黑体兼容栈 (Android & iOS) ---
    // 1. sans-serif: 安卓最通用的黑体关键字，映射各家定制字体 (OPPO Sans, MiSans, HarmonyOS Sans)
    // 2. sans-serif-medium: 解决安卓部分系统 bold 回退异常的专用关键字
    // 3. 显式列出各大厂商字体名，应对部分系统的离线渲染隔离
    final List<String> universalBlackStack = Platform.isIOS
        ? ['.AppleSystemUIFont', 'PingFang SC', 'Heiti SC']
        : [
            'sans-serif',
            'sans-serif-medium',
            'Roboto',
            'Noto Sans CJK SC',
            'Source Han Sans SC',
            'MiSans',
            'OPPOSans',
            'HarmonyOS Sans',
            'vivo Sans'
          ];

    final Widget poster = ProviderScope(
      parent: container,
      child: Theme(
        data: ThemeData(
          brightness: Brightness.light,
          primaryColor: Colors.blue,
          // 强制锁定全局字体
          fontFamily: universalBlackStack.first,
          fontFamilyFallback: universalBlackStack,
          textTheme: const TextTheme().apply(
            fontFamily: universalBlackStack.first,
            fontFamilyFallback: universalBlackStack,
            bodyColor: Colors.black,
            displayColor: Colors.black,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: DefaultTextStyle(
            style: TextStyle(
              fontFamily: universalBlackStack.first,
              fontFamilyFallback: universalBlackStack,
              color: Colors.black,
              decoration: TextDecoration.none,
              // 关键：显式设置 height 以减少字体内部间距导致的渲染偏移
              height: 1.2,
            ),
            child: Container(
              width: 375,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              decoration: const BoxDecoration(
                color: Color(0xFFF2F2F7),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. PUKED Logo & 文字 (垂直排布)
                  Column(
                    children: [
                      Image.asset('assets/images/logo.png',
                          width: 64, height: 60),
                      const SizedBox(height: 12),
                      const Text(
                        'PUKED',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'sans-serif-medium', // 强制触发安卓的中等粗体黑体
                          letterSpacing: 4,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // 2. 白色圆角内容卡片
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 用户信息行
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer, // 添加背景色
                              // 核心修复：使用 CachedNetworkImageProvider 缓存头像
                              backgroundImage: pb.currentAvatarUrl != null
                                  ? CachedNetworkImageProvider(
                                      pb.currentAvatarUrl!)
                                  : null,
                              child: pb.currentAvatarUrl == null
                                  ? Icon(
                                      Icons.person, // 换成实心图标
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    auth.user?.getStringValue('name') ?? 'User',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'ADAS Performance Data',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color:
                                          Colors.black.withValues(alpha: 0.4),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // 核心图表
                        SizedBox(
                          height: 160,
                          child: Stack(
                            children: [
                              PieChart(
                                PieChartData(
                                  sectionsSpace: 4,
                                  centerSpaceRadius: 50,
                                  sections: _buildChartSections(stats, context,
                                      forceLight: true),
                                ),
                              ),
                              const Center(
                                child: Icon(Icons.auto_awesome_motion_rounded,
                                    size: 24, color: Colors.blue),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        Row(
                          children: [
                            Expanded(
                                child: _buildPosterStatGrid(
                                    i18n.t('uploaded_mileage'),
                                    i18n.t('uploaded_mileage_val', args: [
                                      stats.totalMileage.toStringAsFixed(1)
                                    ]))),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _buildPosterStatGrid(
                                    i18n.t('mileage_contribution'),
                                    i18n.t('mileage_contribution_val', args: [
                                      (stats.contribution * 100)
                                          .toStringAsFixed(1)
                                    ]))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                                child: _buildPosterStatGrid(
                                    i18n.t('my_puked_rank'),
                                    i18n.t('my_puked_rank_val', args: [
                                      stats.rank.toString(),
                                      stats.totalUsers.toString()
                                    ]))),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _buildPosterStatGrid(
                                    i18n.t('my_puked_value'),
                                    i18n.t('my_puked_value_val', args: [
                                      stats.pukedValue.toStringAsFixed(1)
                                    ]))),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  Text(
                    'join the global autonomous driving community',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.black.withValues(alpha: 0.2),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    try {
      final Uint8List? imageBytes =
          await _screenshotController.captureFromWidget(
        poster, // 直接传递 poster，因为它已经包含了 ProviderScope 和 Material
        context: context,
        delay: const Duration(milliseconds: 400), // 增加延迟，确保网络头像和图标加载
      );

      if (imageBytes != null) {
        final directory = await getTemporaryDirectory();
        final imagePath = '${directory.path}/puked_stats.png';
        final imageFile = File(imagePath);
        await imageFile.writeAsBytes(imageBytes);

        await Share.shareXFiles(
          [XFile(imagePath)],
          text: 'My ADAS driving stats on PUKED!',
          sharePositionOrigin: sharePositionOrigin,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${i18n.t('share_failed')}: $e")),
        );
      }
    }
  }

  Widget _buildPosterStatGrid(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.black.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              fontFamily: 'sans-serif-medium', // 核心数值强制黑体粗体
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final i18n = ref.watch(i18nProvider);
    final statsAsync = ref.watch(myStatsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return statsAsync.when(
      data: (stats) {
        // 核心修复：即使 stats 是 null（理论上 provider 现在不会返回 null 了），
        // 也要显示卡片，避免在 Android 等平台上突然消失。
        if (stats == null) {
          return const SizedBox.shrink(); // 保险起见
        }
        return _buildCard(context, stats, i18n, l10n, isDark);
      },
      loading: () => _buildLoading(context),
      error: (err, stack) {
        debugPrint('[MyDataCard] Error: $err');
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Container(
      margin: EdgeInsets.zero,
      height: 200,
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildCard(BuildContext context, MyStats stats, I18n i18n,
      AppLocalizations l10n, bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF2C2C2E), const Color(0xFF1C1C1E)]
              : [Colors.white, const Color(0xFFF2F2F7)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          // 顶部标题栏
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.analytics_rounded,
                      size: 18, color: colorScheme.primary),
                ),
                const SizedBox(width: 10),
                Text(
                  i18n.t('my_data_uploaded'),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                // 【新增】图片压缩按钮 (仅SuperUser可见)
                if (ref.watch(authProvider).isSuperUser)
                  IconButton(
                    icon: _isCompressing
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.primary,
                            ),
                          )
                        : Icon(Icons.image_outlined,
                            size: 20, color: colorScheme.primary),
                    onPressed:
                        _isCompressing ? null : _compressAllCertificationImages,
                    tooltip: '压缩认证图片',
                  ),
                // 刷新按钮 (直接失效缓存，强制重新拉取 user_stats)
                IconButton(
                  icon: Icon(Icons.refresh_rounded,
                      size: 20, color: colorScheme.primary),
                  onPressed: () {
                    final auth = ref.read(authProvider);
                    if (auth.user != null) {
                      // 1. 失效个人的快照 Provider
                      ref.invalidate(userStatsEntryProvider(auth.user!.id));
                      // 2. 失效全局汇总 Provider
                      ref.invalidate(arenaStatsProvider);
                      // 3. 静默刷新用户信息
                      ref.read(authProvider.notifier).refreshUserFromServer();
                    }
                  },
                ),
                Builder(
                  builder: (context) => IconButton(
                    icon: Icon(Icons.share_rounded,
                        size: 20, color: colorScheme.primary),
                    onPressed: () {
                      final RenderBox? box =
                          context.findRenderObject() as RenderBox?;
                      final Rect? rect = box != null
                          ? box.localToGlobal(Offset.zero) & box.size
                          : null;
                      _shareStatsCard(stats, i18n, rect);
                    },
                  ),
                ),
              ],
            ),
          ),

          // 中部：大图表区域
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 24), // Increased padding
            child: SizedBox(
              height: 240, // Increased height
              child: Stack(
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 70, // Slightly larger
                      sections: _buildChartSections(stats, context),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          i18n.t('brand_distribution_desc'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurfaceVariant,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Icon(Icons.auto_awesome_motion_rounded,
                            size: 24, color: colorScheme.primary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 底部：2x2 网格指标
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.5,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildStatGridItem(
                  context,
                  i18n.t('uploaded_mileage'),
                  i18n.t('uploaded_mileage_val',
                      args: [stats.totalMileage.toStringAsFixed(1)]),
                  Icons.route_rounded,
                  Colors.blue,
                ),
                _buildStatGridItem(
                  context,
                  i18n.t('mileage_contribution'),
                  i18n.t('mileage_contribution_val',
                      args: [(stats.contribution * 100).toStringAsFixed(1)]),
                  Icons.pie_chart_outline_rounded,
                  Colors.teal,
                ),
                _buildStatGridItem(
                  context,
                  i18n.t('my_puked_rank'),
                  i18n.t('my_puked_rank_val', args: [
                    stats.rank.toString(),
                    stats.totalUsers.toString()
                  ]),
                  Icons.workspace_premium_rounded,
                  Colors.orange,
                ),
                _buildStatGridItem(
                  context,
                  i18n.t('my_puked_value'),
                  i18n.t('my_puked_value_val',
                      args: [stats.pukedValue.toStringAsFixed(1)]),
                  Icons.speed_rounded,
                  Colors.purple,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatGridItem(BuildContext context, String label,
      String formattedValue, IconData icon, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formattedValue,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildChartSections(
      MyStats stats, BuildContext context,
      {bool forceLight = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark =
        !forceLight && Theme.of(context).brightness == Brightness.dark;

    // 强制使用系统黑体系列
    const List<String> systemFallback = [
      '.SF UI Text',
      'Helvetica Neue',
      'Roboto',
      'Heiti SC',
      'PingFang SC',
      'sans-serif'
    ];

    final List<Color> chartColors = [
      const Color(0xFF007AFF),
      const Color(0xFF34C759),
      const Color(0xFFFF9500),
      const Color(0xFFAF52DE),
      const Color(0xFFFF3B30),
      const Color(0xFF5AC8FA),
      const Color(0xFFFFCC00),
    ];

    if (stats.brandDistribution.isEmpty) {
      return [
        PieChartSectionData(
          color: isDark
              ? colorScheme.surfaceContainerHighest
              : const Color(0xFFE5E5EA),
          value: 1,
          radius: 18,
          showTitle: false,
        ),
      ];
    }

    final total = stats.totalMileage;
    int colorIndex = 0;

    final sortedEntries = stats.brandDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 核心修复：智能防碰撞布局算法
    // 根据品牌数量和扇区大小，动态调整 Logo 距离
    final brandCount = sortedEntries.length;

    final sections = <PieChartSectionData>[];

    for (int i = 0; i < sortedEntries.length; i++) {
      final entry = sortedEntries[i];
      final color = chartColors[colorIndex % chartColors.length];
      colorIndex++;

      final percentage = entry.value / total;

      // 防碰撞策略：
      // 1. 小扇区(<10%): 使用更大的距离避让 (1.8)
      // 2. 中扇区(10%-20%): 中等距离 (1.5)
      // 3. 大扇区(>20%): 正常距离 (1.3)
      // 4. 品牌数量多时(>5个): 整体增加距离，使用分层布局
      double badgeDistance;
      if (brandCount > 5) {
        // 品牌多时: 奇偶分层布局，避免集中碰撞
        badgeDistance = (i % 2 == 0) ? 1.5 : 1.9;
      } else if (percentage < 0.1) {
        badgeDistance = 1.8;
      } else if (percentage < 0.2) {
        badgeDistance = 1.5;
      } else {
        badgeDistance = 1.3;
      }

      sections.add(PieChartSectionData(
        color: color,
        value: entry.value,
        radius: 28,
        showTitle: false,
        badgeWidget: _buildBrandBadge(
            entry.key, entry.value, AppLocalizations.of(context)!,
            forceLight: forceLight, fontFallback: systemFallback),
        badgePositionPercentageOffset: badgeDistance,
      ));
    }

    return sections;
  }

  Widget _buildBrandBadge(
      String brandKey, double mileage, AppLocalizations l10n,
      {bool forceLight = false, List<String>? fontFallback}) {
    final isDark =
        !forceLight && Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF3A3A3C) : Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 3),
              )
            ],
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          child: BrandLogo(
            brandName: brandKey,
            size: 34,
            showBackground: false,
            color: forceLight ? Colors.black : null,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color:
                (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            l10n.distance_unit(mileage.toStringAsFixed(1)),
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
