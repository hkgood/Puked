/**
 * 统计重建进度监控脚本
 */
import PocketBase from 'pocketbase';

const CONFIG = {
    PB_URL: 'https://pb.osglab.com',
    ADMIN_EMAIL: 'rocky.hk@gmail.com',
    ADMIN_PASSWORD: 'gz203799'
};

const pb = new PocketBase(CONFIG.PB_URL);

async function checkProgress() {
    await pb.admins.authWithPassword(CONFIG.ADMIN_EMAIL, CONFIG.ADMIN_PASSWORD);

    console.log('═══════════════════════════════════════════════════════════');
    console.log('           Puked 统计重建进度监控');
    console.log('═══════════════════════════════════════════════════════════\n');

    // 1. 获取水位线
    const state = await pb.collection('stats_state').getFirstListItem('key="current"');
    console.log(`📍 当前水位线: ${state.last_timestamp}`);

    // 2. 统计总行程数
    const totalTrips = await pb.collection('trips').getList(1, 1, {
        filter: 'is_public = true'
    });
    console.log(`📦 公开行程总数: ${totalTrips.totalItems}`);

    // 3. 统计已处理的行程数
    const processedTrips = await pb.collection('trips').getList(1, 1, {
        filter: `is_public = true && created <= "${state.last_timestamp}"`
    });
    console.log(`✅ 已处理行程数: ${processedTrips.totalItems}`);

    // 4. 统计待处理的行程数
    const remainingTrips = totalTrips.totalItems - processedTrips.totalItems;
    console.log(`⏳ 待处理行程数: ${remainingTrips}`);

    // 5. 计算进度
    const progress = totalTrips.totalItems > 0
        ? ((processedTrips.totalItems / totalTrips.totalItems) * 100).toFixed(2)
        : 0;
    console.log(`\n📊 完成进度: ${progress}%`);

    // 6. 生成进度条
    const barLength = 50;
    const filledLength = Math.round((processedTrips.totalItems / totalTrips.totalItems) * barLength);
    const bar = '█'.repeat(filledLength) + '░'.repeat(barLength - filledLength);
    console.log(`[${bar}]`);

    // 7. 统计已生成的统计记录
    const statsCount = await pb.collection('trip_stats_summary').getList(1, 1);
    console.log(`\n📈 已生成统计记录: ${statsCount.totalItems} 条`);

    // 8. 统计用户统计记录
    const userStatsCount = await pb.collection('user_stats').getList(1, 1);
    console.log(`👥 用户统计记录: ${userStatsCount.totalItems} 条`);

    // 9. 预估剩余时间（基于每批50条，每批约30-60秒）
    if (remainingTrips > 0) {
        const batches = Math.ceil(remainingTrips / 50);
        const estimatedMinutes = Math.ceil(batches * 0.75); // 假设每批45秒
        console.log(`\n⏱️  预估剩余时间: 约 ${estimatedMinutes} 分钟`);
    } else {
        console.log(`\n🎉 重建已完成！`);
    }

    console.log('\n═══════════════════════════════════════════════════════════');
}

checkProgress().catch(e => {
    console.error('❌ 监控失败:', e.message);
    process.exit(1);
});
