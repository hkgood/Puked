/**
 * Puked 统计数据全量重建脚本
 * 
 * 由于统计数据被污染，采用最彻底的方案：
 * 1. 删除所有 trip_stats_summary 记录
 * 2. 重置水位线到最早时间
 * 3. 让 auto_induction.js 重新计算所有统计
 * 
 * 使用方法：
 * node scripts/full_rebuild_stats.js
 */

import PocketBase from 'pocketbase';

const CONFIG = {
    PB_URL: 'https://pb.osglab.com',
    ADMIN_EMAIL: 'rocky.hk@gmail.com',
    ADMIN_PASSWORD: 'gz203799',
    // 重置水位线到一个很早的时间，让系统重新处理所有数据
    ROLLBACK_TIMESTAMP: '2000-01-01 00:00:00'
};

const pb = new PocketBase(CONFIG.PB_URL);

/**
 * 完全清空 trip_stats_summary
 */
async function fullCleanupTripStatsSummary() {
    console.log('\n📊 开始全量清理 trip_stats_summary...');

    try {
        // 1. 获取所有记录
        console.log('   ⏳ 正在获取所有统计记录...');
        const allRecords = await pb.collection('trip_stats_summary').getFullList({
            fields: 'id'
        });

        console.log(`   找到 ${allRecords.length} 条统计记录`);

        if (allRecords.length === 0) {
            console.log('   ✅ trip_stats_summary 为空，无需清理');
            return;
        }

        // 2. 批量删除
        console.log(`\n   ⏳ 正在删除所有 ${allRecords.length} 条统计记录...`);
        console.log('   ⚠️  这可能需要几分钟时间，请耐心等待...\n');

        let deletedCount = 0;
        let failedCount = 0;
        const startTime = Date.now();

        for (const record of allRecords) {
            try {
                await pb.collection('trip_stats_summary').delete(record.id);
                deletedCount++;

                // 每删除50条显示一次进度
                if (deletedCount % 50 === 0) {
                    const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
                    const rate = (deletedCount / elapsed).toFixed(1);
                    const remaining = ((allRecords.length - deletedCount) / rate / 60).toFixed(1);
                    console.log(`   进度: ${deletedCount}/${allRecords.length} (${(deletedCount / allRecords.length * 100).toFixed(1)}%) - 速度: ${rate}条/秒 - 预计剩余: ${remaining}分钟`);
                }
            } catch (e) {
                console.error(`   ❌ 删除记录 ${record.id} 失败: ${e.message}`);
                failedCount++;
            }
        }

        const totalTime = ((Date.now() - startTime) / 1000).toFixed(1);
        console.log(`\n   ✅ trip_stats_summary 清理完成！`);
        console.log(`      成功删除: ${deletedCount} 条`);
        console.log(`      删除失败: ${failedCount} 条`);
        console.log(`      总耗时: ${totalTime} 秒`);

    } catch (e) {
        console.error(`\n   ❌ 清理 trip_stats_summary 失败: ${e.message}`);
        throw e;
    }
}

/**
 * 重置统计水位线到最早时间
 */
async function resetStatsState() {
    console.log('\n⏮️  开始重置统计水位线...');

    try {
        const stateRecord = await pb.collection('stats_state').getFirstListItem('key="current"');

        console.log(`   当前水位线: ${stateRecord.last_timestamp}`);
        console.log(`   重置目标: ${CONFIG.ROLLBACK_TIMESTAMP}`);

        await pb.collection('stats_state').update(stateRecord.id, {
            last_timestamp: CONFIG.ROLLBACK_TIMESTAMP
        });

        console.log(`   ✅ 水位线已重置到: ${CONFIG.ROLLBACK_TIMESTAMP}`);
        console.log(`   ℹ️  auto_induction.js 将从头开始重新计算所有统计`);

    } catch (e) {
        if (e.status === 404) {
            console.log('   ⚠️  未找到 stats_state 记录，创建新记录...');
            await pb.collection('stats_state').create({
                key: 'current',
                last_timestamp: CONFIG.ROLLBACK_TIMESTAMP
            });
            console.log(`   ✅ 已创建新的水位线记录: ${CONFIG.ROLLBACK_TIMESTAMP}`);
        } else {
            console.error(`\n   ❌ 重置水位线失败: ${e.message}`);
            throw e;
        }
    }
}

/**
 * 主重建流程
 */
async function performFullRebuild() {
    console.log('╔════════════════════════════════════════════════════════════╗');
    console.log('║       Puked 统计数据全量重建工具 v2.0                     ║');
    console.log('╚════════════════════════════════════════════════════════════╝');
    console.log('\n⚠️  警告：本脚本将删除所有统计数据并从头重建！');
    console.log('   - 所有 trip_stats_summary 记录将被删除');
    console.log('   - 统计水位线将重置到 2000-01-01');
    console.log('   - auto_induction.js 将重新处理所有行程\n');

    try {
        // 1. 登录
        console.log('🔐 正在登录 PocketBase...');
        await pb.admins.authWithPassword(CONFIG.ADMIN_EMAIL, CONFIG.ADMIN_PASSWORD);
        console.log('✅ 管理员登录成功\n');

        // 2. 完全清空 trip_stats_summary
        await fullCleanupTripStatsSummary();

        // 3. 重置水位线
        await resetStatsState();

        // 4. 完成
        console.log('\n╔════════════════════════════════════════════════════════════╗');
        console.log('║                  ✨ 全量重建准备完成！                    ║');
        console.log('╚════════════════════════════════════════════════════════════╝');
        console.log('\n📋 后续操作：');
        console.log('   1. 手动触发 auto_induction.js 重新计算统计');
        console.log('      命令: node scripts/auto_induction.js');
        console.log('');
        console.log('   2. 或者等待定时任务自动运行（30分钟一次）');
        console.log('');
        console.log('   3. 重新计算可能需要较长时间（取决于行程数量）：');
        console.log('      - 1000条行程：约 10-20 分钟');
        console.log('      - 5000条行程：约 1-2 小时');
        console.log('');
        console.log('   💡 提示：user_stats 会在归纳完成后自动重建');
        console.log('   💡 提示：可以通过后台日志监控重建进度\n');

    } catch (error) {
        console.error('\n╔════════════════════════════════════════════════════════════╗');
        console.error('║                    ❌ 重建失败！                          ║');
        console.error('╚════════════════════════════════════════════════════════════╝');
        console.error(`\n错误信息: ${error.message}`);
        console.error(`\n请检查：`);
        console.error(`   1. PocketBase 服务是否正常运行`);
        console.error(`   2. 网络连接是否正常`);
        console.error(`   3. 是否有足够的权限\n`);
        process.exit(1);
    }
}

// 执行重建
performFullRebuild();
