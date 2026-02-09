# 用户统计信息卡片功能

## 🎯 功能需求

为已认证用户显示统计信息卡片，替代认证图片显示，包含以下信息：

1. ✅ 上传里程
2. ✅ 里程贡献度
3. ✅ Puked 排名
4. ✅ Puked 值
5. ✅ 各品牌里程分布（饼图）

## 📊 显示逻辑

### 已认证用户（approved）
```
┌─────────────────────────────────────┐
│          用户统计                    │
├─────────────────────────────────────┤
│ 📈 上传里程                          │
│    1,234.56 km                      │
├─────────────────────────────────────┤
│ 📊 里程贡献度                        │
│    0.25%                            │
│    全球总里程：500,000 km           │
├─────────────────────────────────────┤
│ 🏆 Puked 排名                        │
│    #15 / 500                        │
│    前 97% 用户                       │
├─────────────────────────────────────┤
│ ⚡ Puked 值                          │
│    12.35 km/事件                    │
│    总事件数：100                     │
├─────────────────────────────────────┤
│ 品牌里程分布                         │
│    [饼图展示]                        │
│    • Xpeng: 800 km (65%)           │
│    • Tesla: 400 km (32%)           │
│    • NIO: 34.56 km (3%)            │
└─────────────────────────────────────┘
```

### 未认证用户（pending/rejected）
```
┌─────────────────────────────────────┐
│          认证图片                    │
├─────────────────────────────────────┤
│                                     │
│    [认证图片 1]                      │
│                                     │
│    [认证图片 2]                      │
│                                     │
└─────────────────────────────────────┘
```

## 🎨 UI 设计

### 统计卡片样式

**整体布局：**
- 白色圆角卡片
- 最小高度 400px
- 与左侧信息卡片对齐

**数据展示：**
- 每项统计都有对应的彩色图标
- 大号字体显示主要数值
- 小号字体显示补充信息

**品牌分布图表：**
- 使用 Recharts 饼图
- 多彩配色方案
- 鼠标悬停显示详细数据
- 底部图例显示品牌和里程

## 📦 数据结构

### user_stats 集合

```typescript
interface UserStatsRecord {
  id: string;
  user_id: string;  // 用户 ID
  payload: {
    totalMileage: number;              // 总里程
    globalTotalMileage: number;        // 全球总里程
    totalEvents: number;               // 总事件数
    brandDistribution: {               // 品牌里程分布
      "Xpeng": 800,
      "Tesla": 400,
      "NIO": 34.56
    };
    pukedValue: number;                // Puked 值 (里程/事件)
    rank: number;                      // 排名
    totalUsers: number;                // 总用户数
    updated_at: string;                // 更新时间
  };
}
```

### 计算公式

**Puked 值：**
```
pukedValue = totalMileage / totalEvents
```

**里程贡献度：**
```
contribution = (totalMileage / globalTotalMileage) × 100%
```

**排名百分位：**
```
percentile = ((totalUsers - rank + 1) / totalUsers) × 100%
```

## 🔧 技术实现

### 组件结构

```
UserStatsCard.tsx
├── 状态管理
│   ├── stats: UserStatsPayload
│   ├── loading: boolean
│   └── error: string | null
│
├── 数据加载
│   └── loadUserStats() - 从 user_stats 表获取
│
└── UI 渲染
    ├── 加载状态
    ├── 错误状态
    └── 数据展示
        ├── 上传里程
        ├── 里程贡献度
        ├── Puked 排名
        ├── Puked 值
        └── 品牌分布图表
```

### 核心代码

#### 1. 数据加载

```typescript
const loadUserStats = async () => {
  try {
    const record = await pb.collection('user_stats').getFirstListItem<UserStatsRecord>(
      `user_id = "${user.id}"`,
      { requestKey: null }
    );
    
    setStats(record.payload);
  } catch (e: any) {
    if (e.status === 404) {
      setError('暂无统计数据');
    }
  }
};
```

#### 2. 条件渲染

```typescript
// DashboardView.tsx
{selectedUser.audit_status?.toLowerCase() === 'approved' ? (
  <UserStatsCard user={selectedUser} />
) : (
  <CertificationImagesCard user={selectedUser} />
)}
```

#### 3. 饼图实现

```typescript
<PieChart>
  <Pie
    data={brandChartData}
    cx="50%"
    cy="50%"
    label={({ name, percent }) => `${name}: ${(percent * 100).toFixed(0)}%`}
    outerRadius={80}
    dataKey="value"
  >
    {brandChartData.map((entry, index) => (
      <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
    ))}
  </Pie>
  <Tooltip formatter={(value: number) => `${value.toFixed(2)} km`} />
  <Legend />
</PieChart>
```

## 🎯 使用场景

### 场景 1：查看已认证用户统计

**操作：**
1. 进入用户管理页面
2. 选择一个已认证（approved）用户
3. 右侧卡片自动显示统计信息

**预期：**
- ✅ 看到上传里程、贡献度、排名等信息
- ✅ 看到品牌分布饼图
- ✅ 数据实时从 user_stats 表获取

### 场景 2：查看待审核用户

**操作：**
1. 选择一个待审核（pending）用户
2. 右侧卡片显示认证图片

**预期：**
- ✅ 显示认证图片（用于审核）
- ✅ 不显示统计信息（因为可能还没有数据）

### 场景 3：用户无统计数据

**操作：**
1. 选择一个已认证但未上传行程的用户

**预期：**
- ✅ 显示"暂无统计数据"提示
- ✅ 提示用户需要上传行程数据

## 📊 数据更新

### 统计数据生成

统计数据由后台任务（StatsManager）定期生成：

```typescript
// arenaService.ts - aggregateUserStats()
// 1. 聚合所有用户的行程数据
// 2. 计算总里程、事件数、品牌分布
// 3. 计算 Puked 值和排名
// 4. 写入 user_stats 表
```

### 更新频率

- 通过 StatsManager 手动触发
- 或通过定时任务自动更新
- 每次更新后，UI 会重新加载数据

## 🎨 图标和颜色

### 图标映射

```typescript
上传里程    → TrendingUp  (#007AFF 蓝色)
里程贡献度  → BarChart3   (#248A3D 绿色)
Puked 排名  → Award       (#FF9500 橙色)
Puked 值    → Activity    (#5856D6 紫色)
```

### 图表配色

```typescript
const COLORS = [
  '#007AFF',  // 蓝色
  '#248A3D',  // 绿色
  '#FF3B30',  // 红色
  '#FF9500',  // 橙色
  '#5856D6',  // 紫色
  '#34C759',  // 浅绿
  '#AF52DE',  // 浅紫
  '#FF2D55',  // 粉色
];
```

## 🔍 状态处理

### 加载状态

```
┌─────────────────────────────────────┐
│                                     │
│         [旋转加载图标]               │
│      加载统计数据...                 │
│                                     │
└─────────────────────────────────────┘
```

### 错误/无数据状态

```
┌─────────────────────────────────────┐
│                                     │
│         [图标]                       │
│      暂无统计数据                    │
│  用户需要上传行程数据后才会生成统计  │
│                                     │
└─────────────────────────────────────┘
```

### 正常显示状态

完整的统计信息和图表

## 📝 国际化支持

需要添加的翻译键：

```typescript
// 中文
user_stats: '用户统计',
uploaded_mileage: '上传里程',
mileage_contribution: '里程贡献度',
puked_ranking: 'Puked 排名',
puked_value: 'Puked 值',
brand_distribution: '品牌里程分布',
total_events: '总事件数',
global_total_mileage: '全球总里程',
no_stats_data: '暂无统计数据',
need_upload_trips: '用户需要上传行程数据后才会生成统计',

// 英文
user_stats: 'User Statistics',
uploaded_mileage: 'Uploaded Mileage',
mileage_contribution: 'Mileage Contribution',
puked_ranking: 'Puked Ranking',
puked_value: 'Puked Value',
brand_distribution: 'Brand Distribution',
// ...
```

## 🧪 测试场景

### 1. 已认证用户有数据

**测试：**
1. 选择已认证用户（有上传过行程）
2. 验证显示统计卡片 ✅
3. 验证所有数据项都显示 ✅
4. 验证饼图正确渲染 ✅

### 2. 已认证用户无数据

**测试：**
1. 选择已认证但未上传行程的用户
2. 验证显示"暂无统计数据"提示 ✅

### 3. 未认证用户

**测试：**
1. 选择待审核用户
2. 验证显示认证图片 ✅
3. 验证不显示统计卡片 ✅

### 4. 数据准确性

**测试：**
1. 对比 user_stats 表中的数据
2. 验证 UI 显示的数据一致 ✅
3. 验证计算的百分比正确 ✅

### 5. 图表交互

**测试：**
1. 鼠标悬停在饼图上 ✅
2. 验证 Tooltip 显示详细信息 ✅
3. 验证图例正确显示 ✅

## 💡 设计亮点

### 1. 条件渲染
根据用户认证状态智能切换显示内容

### 2. 数据可视化
使用饼图直观展示品牌分布

### 3. 信息层次
- 大号字体：主要数值
- 小号字体：补充信息
- 颜色区分：不同类型数据

### 4. 错误处理
- 加载状态
- 无数据提示
- 网络错误处理

### 5. 性能优化
- 只在选中已认证用户时加载数据
- 使用 useEffect 依赖用户 ID

## 📦 文件清单

### 新增文件

```
✅ src/features/dashboard/components/UserStatsCard.tsx
```

### 修改文件

```
✅ src/features/dashboard/components/DashboardView.tsx
   - 导入 UserStatsCard
   - 条件渲染统计卡片或认证图片
```

## ✅ 功能对比

### 修改前

```
所有用户都显示认证图片
```

### 修改后

```
已认证用户：
  └─ 显示统计信息卡片 ✅
      ├─ 上传里程
      ├─ 里程贡献度
      ├─ Puked 排名
      ├─ Puked 值
      └─ 品牌分布图表

未认证用户：
  └─ 显示认证图片 ✅
```

## 🚀 未来改进

### 可能的优化方向

1. **更多图表**
   - 行程时间趋势
   - 事件类型分布
   - 月度里程统计

2. **交互功能**
   - 点击图表跳转到详细页面
   - 数据导出功能
   - 历史数据对比

3. **实时更新**
   - WebSocket 实时推送
   - 自动刷新统计数据

4. **个性化展示**
   - 用户可选择显示哪些统计项
   - 自定义图表样式

## 🎉 总结

这个功能实现了：

1. ✅ 根据认证状态智能显示内容
2. ✅ 展示完整的用户统计信息
3. ✅ 可视化品牌里程分布
4. ✅ 友好的加载和错误处理
5. ✅ 清晰的信息层次和设计

**现在已认证用户可以看到他们的详细统计数据了！** 🎊
