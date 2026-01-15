import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:puked/common/utils/i18n.dart';
import 'package:puked/features/settings/providers/my_stats_provider.dart';
import 'package:puked/common/widgets/brand_logo.dart';
import 'package:puked/features/auth/providers/auth_provider.dart';
import 'package:puked/services/pocketbase_service.dart';
import 'package:puked/common/theme/app_theme.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class MyDataCard extends ConsumerStatefulWidget {
  const MyDataCard({super.key});

  @override
  ConsumerState<MyDataCard> createState() => _MyDataCardState();
}

class _MyDataCardState extends ConsumerState<MyDataCard> {
  final ScreenshotController _screenshotController = ScreenshotController();

  Future<void> _shareStatsCard(MyStats stats, I18n i18n) async {
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
                      Image.asset('assets/images/logo.png', width: 64, height: 60),
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
                              backgroundColor: Theme.of(context).colorScheme.primaryContainer, // 添加背景色
                              backgroundImage: pb.currentAvatarUrl != null ? NetworkImage(pb.currentAvatarUrl!) : null,
                              child: pb.currentAvatarUrl == null ? Icon(
                                Icons.person, // 换成实心图标
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                              ) : null,
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
                                      color: Colors.black.withValues(alpha: 0.4),
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
                                  sections: _buildChartSections(stats, context, forceLight: true),
                                ),
                              ),
                              const Center(
                                child: Icon(Icons.auto_awesome_motion_rounded, size: 24, color: Colors.blue),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        Row(
                          children: [
                            Expanded(child: _buildPosterStatGrid(i18n.t('uploaded_mileage'), i18n.t('uploaded_mileage_val', args: [stats.totalMileage.toStringAsFixed(1)]))),
                            const SizedBox(width: 12),
                            Expanded(child: _buildPosterStatGrid(i18n.t('mileage_contribution'), i18n.t('mileage_contribution_val', args: [(stats.contribution * 100).toStringAsFixed(1)]))),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _buildPosterStatGrid(i18n.t('my_puked_rank'), i18n.t('my_puked_rank_val', args: [stats.rank.toString(), stats.totalUsers.toString()]))),
                            const SizedBox(width: 12),
                            Expanded(child: _buildPosterStatGrid(i18n.t('my_puked_value'), i18n.t('my_puked_value_val', args: [stats.pukedValue.toStringAsFixed(1)]))),
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
      final Uint8List? imageBytes = await _screenshotController.captureFromWidget(
        poster, // 直接传递 poster，因为它已经包含了 ProviderScope 和 Material
        context: context,
        delay: const Duration(milliseconds: 400), // 增加延迟，确保网络头像和图标加载
      );

      if (imageBytes != null) {
        final directory = await getTemporaryDirectory();
        final imagePath = '${directory.path}/puked_stats.png';
        final imageFile = File(imagePath);
        await imageFile.writeAsBytes(imageBytes);

        await Share.shareXFiles([XFile(imagePath)], text: 'My ADAS driving stats on PUKED!');
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
    final i18n = ref.watch(i18nProvider);
    final statsAsync = ref.watch(myStatsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return statsAsync.when(
      data: (stats) => _buildCard(context, stats, i18n, isDark),
      loading: () => _buildLoading(context),
      error: (err, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Container(
      margin: EdgeInsets.zero,
      height: 200,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildCard(BuildContext context, MyStats stats, I18n i18n, bool isDark) {
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
                  child: Icon(Icons.analytics_rounded, size: 18, color: colorScheme.primary),
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
                IconButton(
                  icon: Icon(Icons.share_rounded, size: 20, color: colorScheme.primary),
                  onPressed: () => _shareStatsCard(stats, i18n),
                ),
              ],
            ),
          ),
          
          // 中部：大图表区域
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24), // Increased padding
            child: SizedBox(
              height: 180, // Increased height
              child: Stack(
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 55, // Slightly larger
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
                        Icon(Icons.auto_awesome_motion_rounded, size: 20, color: colorScheme.primary),
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
                  i18n.t('uploaded_mileage_val', args: [stats.totalMileage.toStringAsFixed(1)]),
                  Icons.route_rounded,
                  Colors.blue,
                ),
                _buildStatGridItem(
                  context,
                  i18n.t('mileage_contribution'),
                  i18n.t('mileage_contribution_val', args: [(stats.contribution * 100).toStringAsFixed(1)]),
                  Icons.pie_chart_outline_rounded,
                  Colors.teal,
                ),
                _buildStatGridItem(
                  context,
                  i18n.t('my_puked_rank'),
                  i18n.t('my_puked_rank_val', args: [stats.rank.toString(), stats.totalUsers.toString()]),
                  Icons.workspace_premium_rounded,
                  Colors.orange,
                ),
                _buildStatGridItem(
                  context,
                  i18n.t('my_puked_value'),
                  i18n.t('my_puked_value_val', args: [stats.pukedValue.toStringAsFixed(1)]),
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

  Widget _buildStatGridItem(
    BuildContext context, 
    String label, 
    String formattedValue, 
    IconData icon, 
    Color color
  ) {
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

  List<PieChartSectionData> _buildChartSections(MyStats stats, BuildContext context, {bool forceLight = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = !forceLight && Theme.of(context).brightness == Brightness.dark;
    
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
          color: isDark ? colorScheme.surfaceContainerHighest : const Color(0xFFE5E5EA),
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

    return sortedEntries.map((entry) {
      final color = chartColors[colorIndex % chartColors.length];
      colorIndex++;
      
      final percentage = entry.value / total;
      
      return PieChartSectionData(
        color: color,
        value: entry.value,
        radius: 22,
        showTitle: false,
        badgeWidget: percentage > 0.05 ? _buildBrandBadge(entry.key, entry.value, forceLight: forceLight, fontFallback: systemFallback) : null,
        badgePositionPercentageOffset: 1.6,
      );
    }).toList();
  }

  Widget _buildBrandBadge(String brandKey, double mileage, {bool forceLight = false, List<String>? fontFallback}) {
    final isDark = !forceLight && Theme.of(context).brightness == Brightness.dark;
    final onSurface = forceLight ? Colors.black : Theme.of(context).colorScheme.onSurface;

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
              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          child: BrandLogo(
            brandName: brandKey,
            size: 26,
            showBackground: false,
            color: forceLight ? Colors.black : null,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${mileage.toStringAsFixed(1)}km',
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
