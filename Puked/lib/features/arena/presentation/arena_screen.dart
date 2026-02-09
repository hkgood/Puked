import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:puked/common/widgets/brand_logo.dart';
import 'package:puked/common/widgets/brand_selection.dart';
import '../providers/arena_provider.dart';
import 'package:puked/common/utils/i18n.dart';

class ArenaScreen extends ConsumerStatefulWidget {
  const ArenaScreen({super.key});

  @override
  ConsumerState<ArenaScreen> createState() => _ArenaScreenState();
}

class _ArenaScreenState extends ConsumerState<ArenaScreen> {
  // 状态变量
  bool _groupByBrand = true; // 卡片1的 toggle
  bool _leaderboardWeekly = true; // 里程榜 toggle
  String _rankingScenario = 'city'; // 场景排名 toggle
  String _weeklyScenario = 'city'; // 🆕 周度场景排名 toggle
  String? _card2Brand;
  String? _card3Brand;
  String? _card3Version;

  @override
  void initState() {
    super.initState();
    // 移除 WidgetsBinding.instance.addPostFrameCallback，
    // 改为由 arenaStatsProvider 内部处理初始化加载，
    // 这样点击 Tab 切换时不会重复触发请求。
  }

  Future<void> _onRefresh() async {
    // 手动刷新时强制更新 (触发云端重新计算)
    await ref.read(arenaStatsProvider.notifier).refresh(force: true);
  }

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(i18nProvider);
    final statsAsync = ref.watch(arenaStatsProvider);
    final arena = ref.watch(arenaProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.t('arena')),
        actions: [
          // 右上角刷新按钮：根据加载状态进入动画状态
          _SyncButton(
            isLoading: statsAsync.isLoading,
            onPressed: _onRefresh,
          ),
        ],
      ),
      body: SafeArea(
        left: true,
        right: true,
        top: false,
        bottom: false,
        child: statsAsync.when(
          skipLoadingOnReload: true,
          // ✅ loading 时：如果有旧数据就显示旧数据，否则显示加载动画
          loading: () => statsAsync.hasValue
              ? _buildArenaContent(arena, i18n)
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: SizedBox(
                            width: 48,
                            height: 48,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme.of(context).colorScheme.primary),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        i18n.t('syncing'),
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        i18n.t('fetching_arena_data'),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        i18n.t('arena_mileage_requirement'),
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.5),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
          // ✅ error 时：优先显示旧数据
          error: (err, stack) => statsAsync.hasValue
              ? _buildArenaContent(arena, i18n)
              : ListView(
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.7,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            Text('Error: $err'),
                            TextButton(
                              onPressed: _onRefresh,
                              child: Text(i18n.t('retry')),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
          data: (stats) => _buildArenaContent(arena, i18n),
        ),
      ),
    );
  }

  Widget _buildArenaContent(ArenaService arena, dynamic i18n) {
    // 检查是否正在后台刷新
    final statsAsync = ref.watch(arenaStatsProvider);
    final isRefreshing = statsAsync.isLoading && statsAsync.hasValue;

    return arena.stats.isEmpty
        ? ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.leaderboard_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 16),
                      Text(i18n.t('no_trips_yet'),
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.outline)),
                    ],
                  ),
                ),
              ),
            ],
          )
        : RefreshIndicator(
            onRefresh: _onRefresh,
            child: Stack(
              children: [
                SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  child: Column(
                    children: [
                      // ✅ 后台刷新提示（不显眼）
                      if (isRefreshing)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Theme.of(context).colorScheme.primary),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                i18n.t('syncing'),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // 🆕 周度卡片区域 - 置顶显示
                      _buildWeeklyComfortRankingCard(arena, i18n),
                      const SizedBox(height: 16),
                      _buildWeeklyMileageCard(arena, i18n),
                      const SizedBox(height: 16),
                      // 全时段卡片
                      _buildCard1(arena, i18n),
                      const SizedBox(height: 16),
                      _buildScenarioRankingCard(arena, i18n),
                      const SizedBox(height: 16),
                      _buildUserLeaderboardCard(arena, i18n),
                      const SizedBox(height: 16),
                      _buildTotalMileageCard(arena, i18n),
                      const SizedBox(height: 16),
                      _buildCard2(arena, i18n),
                      const SizedBox(height: 16),
                      _buildCard3(arena, i18n),
                      const SizedBox(height: 32),
                      // 底部提示文字
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            i18n.t('arena_mileage_requirement').toUpperCase(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.5),
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          );
  }

  // 统一的标题样式 (使用 bold 替代 w900)
  TextStyle _headerStyle(BuildContext context) => TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 17,
        color: Theme.of(context).colorScheme.onSurface,
      );

  // 统一的单位样式
  TextStyle _unitStyle(BuildContext context) => TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
      );

  // --- 用户里程贡献榜 ---
  Widget _buildUserLeaderboardCard(ArenaService arena, dynamic i18n) {
    final data = arena.getUserLeaderboard(weekly: _leaderboardWeekly);
    final maxVal = data.isNotEmpty ? data.first.totalKm : 1.0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(i18n.t('arena_leaderboard_title'),
                      style: _headerStyle(context)),
                ),
                const SizedBox(width: 12),
                Row(
                  children: [
                    Text(
                        _leaderboardWeekly
                            ? i18n.t('weekly_rank')
                            : i18n.t('total_rank'),
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                            fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => setState(
                          () => _leaderboardWeekly = !_leaderboardWeekly),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 24,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: _leaderboardWeekly
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 200),
                          alignment: _leaderboardWeekly
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (data.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    i18n.t('no_data_for_brand'),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                        fontSize: 12),
                  ),
                ),
              )
            else
              ...data.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final val = item.totalKm;
                final ratio = val / (maxVal * 1.1);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Row(
                    children: [
                      // 排名
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.8),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      // 头像占位/用户图标
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer, // 使用容器背景色
                          shape: BoxShape.circle,
                          // 核心修复：使用 CachedNetworkImageProvider 缓存头像
                          image: item.avatarUrl != null
                              ? DecorationImage(
                                  image: CachedNetworkImageProvider(
                                      item.avatarUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: item.avatarUrl == null
                            ? Icon(
                                Icons.person, // 换成实心图标
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                                size: 24,
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      // 姓名和进度条
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item.userName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '${val.toStringAsFixed(1)} ${i18n.t('user_mileage_unit')}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Stack(
                              children: [
                                Container(
                                  height: 8,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: ratio.clamp(0.02, 1.0),
                                  child: Container(
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // 🆕 --- 周度城区/高速舒适度排名 ---
  Widget _buildWeeklyComfortRankingCard(ArenaService arena, dynamic i18n) {
    final data = arena.getWeeklyScenarioRankingData(scenario: _weeklyScenario);
    final maxVal = data.isNotEmpty ? (data.first.kmPerEvent ?? 1.0) : 1.0;
    final titleKey = 'weekly_comfort_ranking';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i18n.t(titleKey), style: _headerStyle(context)),
                      const SizedBox(height: 2),
                      Text(i18n.t('weekly_comfort_desc'),
                          style: _unitStyle(context)),
                    ],
                  ),
                ),
                // 场景切换器
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      _buildScenarioToggleItem(i18n.t('city'), 'city',
                          isWeekly: true),
                      _buildScenarioToggleItem(i18n.t('highway'), 'highway',
                          isWeekly: true),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (data.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    i18n.t('no_data_for_brand'),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                        fontSize: 12),
                  ),
                ),
              )
            else
              ...data.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final val = item.kmPerEvent ?? 0.0;
                final ratio = val / (maxVal * 1.2);
                const double barHeight = 16.0;
                const double nameFontSize = 13.0;
                const double spacingBetween = 4.0;
                const double logoSize = 42.0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.8),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      BrandLogo(
                        brandName: item.brand,
                        overrideLogoUrl: item.logoUrl,
                        size: logoSize,
                        padding: 8,
                        showBackground: true,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item.displayName,
                                  style: const TextStyle(
                                    fontSize: nameFontSize,
                                    fontWeight: FontWeight.bold,
                                    height: 1.2,
                                  ),
                                ),
                                Text(
                                  val.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.8),
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: spacingBetween),
                            Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                Container(
                                  height: barHeight,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: ratio.clamp(0.08, 1.0),
                                  child: Container(
                                    height: barHeight,
                                    decoration: BoxDecoration(
                                      color:
                                          const Color(0xFF34C759), // 绿色 - 周度特征色
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // 🆕 --- 周度品牌累计里程排名 ---
  Widget _buildWeeklyMileageCard(ArenaService arena, dynamic i18n) {
    final data = arena.getWeeklyMileageData();
    final maxTotalKm = data.isNotEmpty ? (data.first.totalKm ?? 1.0) : 1.0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 标题行 + 图例右对齐 ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i18n.t('weekly_mileage_ranking'),
                          style: _headerStyle(context)),
                      const SizedBox(height: 2),
                      Text(i18n.t('weekly_mileage_desc'),
                          style: _unitStyle(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                // 柔和配色图例：单行展示，避免折行
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLegendItem('>80', const Color(0xFF007AFF)),
                      const SizedBox(width: 6),
                      _buildLegendItem('50-80', const Color(0xFF7ABCFF)),
                      const SizedBox(width: 6),
                      _buildLegendItem('20-50', const Color(0xFFADEBB3)),
                      const SizedBox(width: 6),
                      _buildLegendItem('<20', const Color(0xFFF9E79F)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (data.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    i18n.t('no_data_for_brand'),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                        fontSize: 12),
                  ),
                ),
              )
            else
              ...data.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final totalKm = item.totalKm ?? 0.0;
                final ratio = totalKm / (maxTotalKm * 1.1);
                const double barHeight = 10.0;
                const double nameFontSize = 13.0;
                const double spacingBetween = 6.0;
                const double logoSize = 42.0;

                final breakdown = item.breakdown ?? {};
                final highway = breakdown['highway'] ?? 0.0;
                final smooth = breakdown['smooth'] ?? 0.0;
                final urban = breakdown['urban'] ?? 0.0;
                final congested = breakdown['congested'] ?? 0.0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                      BrandLogo(
                        brandName: item.brand,
                        overrideLogoUrl: item.logoUrl,
                        size: logoSize,
                        padding: 8,
                        showBackground: true,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item.displayName.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: nameFontSize,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  '${totalKm.toStringAsFixed(1)} km',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: spacingBetween),
                            FractionallySizedBox(
                              widthFactor: ratio.clamp(0.01, 1.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(5),
                                child: Container(
                                  height: barHeight,
                                  width: double.infinity,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF2F2F7),
                                  ),
                                  child: Row(
                                    children: [
                                      if (highway > 0)
                                        Expanded(
                                          flex: (highway * 1000)
                                              .toInt()
                                              .clamp(1, 999999),
                                          child: Container(
                                              color: const Color(0xFF007AFF)),
                                        ),
                                      if (smooth > 0)
                                        Expanded(
                                          flex: (smooth * 1000)
                                              .toInt()
                                              .clamp(1, 999999),
                                          child: Container(
                                              color: const Color(0xFF7ABCFF)),
                                        ),
                                      if (urban > 0)
                                        Expanded(
                                          flex: (urban * 1000)
                                              .toInt()
                                              .clamp(1, 999999),
                                          child: Container(
                                              color: const Color(0xFFADEBB3)),
                                        ),
                                      if (congested > 0)
                                        Expanded(
                                          flex: (congested * 1000)
                                              .toInt()
                                              .clamp(1, 999999),
                                          child: Container(
                                              color: const Color(0xFFF9E79F)),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // --- 卡片1：无负体验里程 TOP10 ---
  Widget _buildCard1(ArenaService arena, dynamic i18n) {
    final data = arena.getTop10Data(groupByBrand: _groupByBrand);
    final maxVal = data.isNotEmpty ? (data.first.kmPerEvent ?? 1.0) : 1.0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start, // 标题行靠上
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i18n.t('arena_top10_title'),
                          style: _headerStyle(context)),
                      const SizedBox(height: 2),
                      Text(i18n.t('km_per_event_long'),
                          style: _unitStyle(context)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  children: [
                    Text(
                        _groupByBrand
                            ? i18n.t('by_brand')
                            : i18n.t('by_version'),
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                            fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _groupByBrand = !_groupByBrand),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 24,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: _groupByBrand
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 200),
                          alignment: _groupByBrand
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...data.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final val = item.kmPerEvent ?? 0.0;
              final ratio = val / (maxVal * 1.2);
              const double barHeight = 16.0;
              const double nameFontSize = 13.0;
              const double spacingBetween = 4.0;
              const double logoSize = 42.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 0. 排名编号
                    SizedBox(
                      width: 24,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.8),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    // 1. Logo
                    BrandLogo(
                      brandName: item.brand,
                      overrideLogoUrl: item.logoUrl, // 关键：使用云端 Logo URL
                      size: logoSize,
                      padding: 8,
                      showBackground: true,
                    ),
                    const SizedBox(width: 16),
                    // 2. 名称 + Bar
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item.displayName,
                                style: const TextStyle(
                                  fontSize: nameFontSize,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                              ),
                              Text(
                                val.toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.8),
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: spacingBetween),
                          Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              // 背景条
                              Container(
                                height: barHeight,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              // 进度条
                              FractionallySizedBox(
                                widthFactor: ratio.clamp(0.08, 1.0),
                                child: Container(
                                  height: barHeight,
                                  decoration: BoxDecoration(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // --- 深度同步 Web 端：分场景排行榜 (城市/高速) ---
  Widget _buildScenarioRankingCard(ArenaService arena, dynamic i18n) {
    final data = arena.getScenarioRankingData(
        scenario: _rankingScenario, groupByBrand: _groupByBrand);
    final maxVal = data.isNotEmpty ? (data.first.kmPerEvent ?? 1.0) : 1.0;
    final titleKey =
        _rankingScenario == 'city' ? 'low_speed_ranking' : 'high_speed_ranking';
    final descKey =
        _rankingScenario == 'city' ? 'low_speed_desc' : 'high_speed_desc';

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i18n.t(titleKey), style: _headerStyle(context)),
                      const SizedBox(height: 2),
                      Text(i18n.t(descKey), style: _unitStyle(context)),
                    ],
                  ),
                ),
                // 场景切换器
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      _buildScenarioToggleItem(i18n.t('city'), 'city'),
                      _buildScenarioToggleItem(i18n.t('highway'), 'highway'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (data.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    i18n.t('no_data_for_brand'),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                        fontSize: 12),
                  ),
                ),
              )
            else
              ...data.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final val = item.kmPerEvent ?? 0.0;
                final ratio = val / (maxVal * 1.2);
                const double barHeight = 16.0;
                const double nameFontSize = 13.0;
                const double spacingBetween = 4.0;
                const double logoSize = 42.0;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.8),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      BrandLogo(
                        brandName: item.brand,
                        overrideLogoUrl: item.logoUrl,
                        size: logoSize,
                        padding: 8,
                        showBackground: true,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item.displayName,
                                  style: const TextStyle(
                                    fontSize: nameFontSize,
                                    fontWeight: FontWeight.bold,
                                    height: 1.2,
                                  ),
                                ),
                                Text(
                                  val.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.8),
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: spacingBetween),
                            Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                Container(
                                  height: barHeight,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: ratio.clamp(0.08, 1.0),
                                  child: Container(
                                    height: barHeight,
                                    decoration: BoxDecoration(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildScenarioToggleItem(String label, String value,
      {bool isWeekly = false}) {
    final isSelected =
        isWeekly ? _weeklyScenario == value : _rankingScenario == value;
    return GestureDetector(
      onTap: () => setState(() {
        if (isWeekly) {
          _weeklyScenario = value;
        } else {
          _rankingScenario = value;
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  // --- 卡片1.5：总里程 ---
  Widget _buildTotalMileageCard(ArenaService arena, dynamic i18n) {
    final data = arena.getTotalMileageData();
    final maxTotalKm = data.isNotEmpty ? (data.first.totalKm ?? 1.0) : 1.0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 标题行 + 图例右对齐 ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i18n.t('arena_total_mileage_title'),
                          style: _headerStyle(context)),
                      const SizedBox(height: 2),
                      Text(i18n.t('arena_total_mileage_subtitle'),
                          style: _unitStyle(context),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                // 柔和配色图例：单行展示，避免折行
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLegendItem('>80', const Color(0xFF007AFF)),
                      const SizedBox(width: 6),
                      _buildLegendItem('50-80', const Color(0xFF7ABCFF)),
                      const SizedBox(width: 6),
                      _buildLegendItem('20-50', const Color(0xFFADEBB3)),
                      const SizedBox(width: 6),
                      _buildLegendItem('<20', const Color(0xFFF9E79F)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...data.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final totalKm = item.totalKm ?? 0.0;
              final ratio = totalKm / (maxTotalKm * 1.1);
              const double barHeight = 10.0;
              const double nameFontSize = 13.0;
              const double spacingBetween = 6.0;
              const double logoSize = 42.0;

              final breakdown = item.breakdown ?? {};
              final highway = breakdown['highway'] ?? 0.0;
              final smooth = breakdown['smooth'] ?? 0.0;
              final urban = breakdown['urban'] ?? 0.0;
              final congested = breakdown['congested'] ?? 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                    BrandLogo(
                      brandName: item.brand,
                      overrideLogoUrl: item.logoUrl,
                      size: logoSize,
                      padding: 8,
                      showBackground: true,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item.displayName.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: nameFontSize,
                                  fontWeight:
                                      FontWeight.bold, // 降级 w900 -> bold
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                '${totalKm.toStringAsFixed(1)} km',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight:
                                      FontWeight.bold, // 降级 w900 -> bold
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: spacingBetween),
                          FractionallySizedBox(
                            widthFactor: ratio.clamp(0.01, 1.0),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: Container(
                                height: barHeight,
                                width: double.infinity,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF2F2F7),
                                ),
                                child: Row(
                                  children: [
                                    // 修复比例计算，避免 int 精度丢失导致单色
                                    if (highway > 0)
                                      Expanded(
                                        flex: (highway * 1000)
                                            .toInt()
                                            .clamp(1, 999999),
                                        child: Container(
                                            color: const Color(0xFF007AFF)),
                                      ),
                                    if (smooth > 0)
                                      Expanded(
                                        flex: (smooth * 1000)
                                            .toInt()
                                            .clamp(1, 999999),
                                        child: Container(
                                            color: const Color(0xFF7ABCFF)),
                                      ),
                                    if (urban > 0)
                                      Expanded(
                                        flex: (urban * 1000)
                                            .toInt()
                                            .clamp(1, 999999),
                                        child: Container(
                                            color: const Color(0xFFADEBB3)),
                                      ),
                                    if (congested > 0)
                                      Expanded(
                                        flex: (congested * 1000)
                                            .toInt()
                                            .clamp(1, 999999),
                                        child: Container(
                                            color: const Color(0xFFF9E79F)),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7, // 稍微增大一点圆点
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4), // 稍微增加间距
        Text(
          label,
          style: const TextStyle(
            fontSize: 10, // 增大一号 (8 -> 10)
            fontWeight: FontWeight.bold,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  // --- 卡片2：品牌舒适度进化 ---
  Widget _buildCard2(ArenaService arena, dynamic i18n) {
    final brandKey = _card2Brand ?? arena.getDefaultBrand();
    final brandName = arena.getBrandName(brandKey);
    final data = arena.getEvolutionData(brandKey);

    // 计算 Y 轴最大值和刻度间隔 (对齐 Web 端规整算法)
    double maxVal = 0;
    for (var item in data.evolution) {
      if (item.kmPerEvent > maxVal) maxVal = item.kmPerEvent;
    }

    // 抽稀算法：根据最大值动态计算合适的 Y 轴间隔 (最多约 8 个标签)
    double intervalY = 1.0;
    if (maxVal <= 2.5) {
      intervalY = 0.5;
    } else {
      // 预定义的“规整”间隔
      final List<double> niceIntervals = [
        1.0,
        2.0,
        5.0,
        10.0,
        20.0,
        50.0,
        100.0,
        200.0,
        500.0,
        1000.0
      ];
      for (var interval in niceIntervals) {
        // 目标：标签数 (maxVal / interval) 的向上取整 + 1 (0刻度) + 1 (顶层余量) <= 8
        // 即 ceil(maxVal / interval) <= 6
        if ((maxVal / interval).ceil() <= 6) {
          intervalY = interval;
          break;
        }
        intervalY = interval; // 如果都不满足，使用最大的间隔
      }
    }

    double niceMax = (maxVal / intervalY).ceil() * intervalY;
    // 留出至少一个间隔的余量，避免柱子触顶，同时也作为 Y 轴最大刻度
    niceMax += intervalY;
    if (niceMax < 1.0) niceMax = 1.0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => _showBrandPicker(context, arena, brandKey,
                            (selected) {
                          setState(() => _card2Brand = selected);
                        }),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  i18n.t('arena_brand_evolution_title',
                                      args: [brandName]),
                                  style: _headerStyle(context),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_drop_down,
                                color: Theme.of(context).colorScheme.onSurface,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(i18n.t('km_per_version_event_long'),
                          style: _unitStyle(context)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                BrandLogo(
                  brandName: brandKey,
                  overrideLogoUrl:
                      arena.getBrandLogoUrl(brandKey), // 使用合并后的 Logo URL
                  size: 42,
                  padding: 8,
                  showBackground: true,
                ),
              ],
            ),
            const SizedBox(height: 20),
            AspectRatio(
              aspectRatio: 1.5,
              child: data.evolution.isEmpty
                  ? Center(
                      child: Text(
                        i18n.t('no_data_for_brand'),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                            fontSize: 12),
                      ),
                    )
                  : BarChart(
                      BarChartData(
                        gridData: const FlGridData(
                            show: true, drawVerticalLine: false),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 32,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index < 0 ||
                                    index >= data.evolution.length) {
                                  return const SizedBox();
                                }
                                final version = data.evolution[index].version;
                                if (version.isEmpty) return const SizedBox();

                                return SideTitleWidget(
                                  meta: meta,
                                  space: 4, // 减少间距防止挤出显示区域
                                  child: Text(
                                    version,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 9, // 稍微减小字体
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 38,
                              interval: intervalY,
                              getTitlesWidget: (value, meta) => SideTitleWidget(
                                meta: meta,
                                space: 8,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    value.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        minY: 0,
                        maxY: niceMax,
                        barGroups: data.evolution.asMap().entries.map((e) {
                          return BarChartGroupData(
                            x: e.key,
                            barRods: [
                              BarChartRodData(
                                toY: e.value.kmPerEvent,
                                color: Theme.of(context).colorScheme.secondary,
                                width: 28,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6)),
                              ),
                            ],
                            showingTooltipIndicators: [0],
                          );
                        }).toList(),
                        barTouchData: BarTouchData(
                          enabled: false, // 始终显示，不需要触摸
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => Colors.transparent,
                            tooltipPadding: EdgeInsets.zero,
                            tooltipMargin: 8,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              return BarTooltipItem(
                                rod.toY.toStringAsFixed(1),
                                TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              );
                            },
                          ),
                        ),
                        // 增加组间距，确保每个 bar 左右有空间
                        alignment: BarChartAlignment.spaceAround,
                      ),
                    ),
            )
          ],
        ),
      ),
    );
  }

  // --- 卡片3：详情详情 ---
  Widget _buildCard3(ArenaService arena, dynamic i18n) {
    final brandKey = _card3Brand ?? arena.getDefaultBrand();
    final brandName = arena.getBrandName(brandKey);
    final data = arena.getSymptomDetails(brandKey, version: _card3Version);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(i18n.t('arena_details_title'),
                          style: _headerStyle(context)),
                      const SizedBox(height: 2),
                      Text(
                        '${i18n.t('mileage_label')}: ${data.totalKm.toStringAsFixed(1)} KM · ${i18n.t('trips_count', args: [
                              data.tripCount.toString()
                            ])}',
                        style: _unitStyle(context),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    _buildFilterChip(
                        brandName,
                        () => _showBrandPicker(context, arena, brandKey,
                                (selected) {
                              setState(() {
                                _card3Brand = selected;
                                _card3Version = null;
                              });
                            })),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                        _card3Version == null
                            ? i18n.t('all_versions')
                            : arena.getVersionName(_card3Version!),
                        () => _showVersionPicker(context, i18n, brandKey,
                                (selected) {
                              setState(() => _card3Version = selected);
                            })),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                // 根据宽度计算列数
                int crossAxisCount = 2;
                double ratio = 2.2; // 稍大一点以容纳更多行

                if (constraints.maxWidth > 800) {
                  crossAxisCount = 4;
                  ratio = 4.0;
                } else if (constraints.maxWidth > 500) {
                  crossAxisCount = 3;
                  ratio = 3.0;
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 16,
                    childAspectRatio: ratio,
                  ),
                  itemCount: data.details.length,
                  itemBuilder: (context, index) {
                    final type = data.details.keys.elementAt(index);
                    final kmPerEvt = data.details[type]!;
                    final count = data.counts[type] ?? 0;
                    return _buildSymptomItem(i18n, type, kmPerEvt, count);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              size: 14,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ],
        ),
      ),
    );
  }

  void _showVersionPicker(BuildContext context, dynamic i18n, String brandKey,
      Function(String?) onSelected) {
    final arena = ref.read(arenaProvider);
    // 从预计算的进化数据中提取该品牌的所有版本
    final evoData = arena.getEvolutionData(brandKey);
    final versions = evoData.evolution.map((e) => e.version).toList();

    final List<String?> options = [null, ...versions];

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final v = options[index];
              return ListTile(
                title: Text(v == null ? i18n.t('all_versions') : v),
                onTap: () {
                  onSelected(v);
                  Navigator.pop(context);
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSymptomItem(dynamic i18n, String type, double value, int count) {
    Color eventColor;
    IconData eventIcon;

    switch (type) {
      case 'rapidAcceleration':
        eventColor = const Color(0xFFFF9500);
        eventIcon = Icons.speed;
        break;
      case 'rapidDeceleration':
        eventColor = const Color(0xFFFF3B30);
        eventIcon = Icons.trending_down;
        break;
      case 'jerk':
        eventColor = const Color(0xFF5856D6);
        eventIcon = Icons.priority_high;
        break;
      case 'bump':
        eventColor = const Color(0xFFAF52DE);
        eventIcon = Icons.vibration;
        break;
      case 'wobble':
        eventColor = const Color(0xFF007AFF);
        eventIcon = Icons.waves;
        break;
      default:
        eventColor = Colors.grey;
        eventIcon = Icons.event;
    }

    return Row(
      children: [
        // 1. 放大后的图标
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: eventColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(eventIcon, color: eventColor, size: 24),
        ),
        const SizedBox(width: 12),
        // 2. 三行文字 (名称, km/Event, Count)
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                i18n.t(type),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 1),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                i18n.t('events_count', args: [count.toString()]),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showBrandPicker(BuildContext context, ArenaService arena,
      String? currentBrand, Function(String) onSelected) {
    final i18n = ref.read(i18nProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 允许弹窗高度自定义
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65, // 减小初始高度，大约显示 3-4 行
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 16),
                    child: Text(i18n.t('select_brand'),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                  Expanded(
                    child: BrandSelectionGrid(
                      brands: arena.availableBrands,
                      selectedBrandKey: currentBrand,
                      scrollController: scrollController,
                      shrinkWrap: false,
                      physics: const AlwaysScrollableScrollPhysics(),
                      onBrandSelected: (brand) {
                        onSelected(brand.cloudId ?? brand.name);
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SyncButton extends StatefulWidget {
  final bool isLoading;
  final VoidCallback onPressed;

  const _SyncButton({
    required this.isLoading,
    required this.onPressed,
  });

  @override
  State<_SyncButton> createState() => _SyncButtonState();
}

class _SyncButtonState extends State<_SyncButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    if (widget.isLoading) _controller.repeat();
  }

  @override
  void didUpdateWidget(_SyncButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading != oldWidget.isLoading) {
      if (widget.isLoading) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: IconButton(
        icon: const Icon(Icons.sync, size: 20),
        onPressed: widget.isLoading ? null : widget.onPressed,
      ),
    );
  }
}
