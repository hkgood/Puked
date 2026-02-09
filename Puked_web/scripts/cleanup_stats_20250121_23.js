/**
 * Puked 统计数据清理脚本
 * 目的：清理 2025年1月21-23日 的污染统计数据
 * 
 * 操作内容：
 * 1. 删除 trip_stats_summary 中 1月21-23日 相关的统计记录
 * 2. 回退 stats_state 的 last_timestamp 到 1月20日
 * 3. 清空 user_stats（会在下次归纳时自动重建）
 * 
 * 使用方法：
 * node scripts/cleanup_stats_20250121_23.js
 */

import PocketBase from 'pocketbase';

// --- 配置区 ---
const CONFIG = {
    PB_URL: 'https://pb.osglab.com',
    ADMIN_EMAIL: 'rocky.hk@gmail.com',
    ADMIN_PASSWORD: 'gz203799',
    // 清理的日期范围
    START_DATE: '2025-01-21',
    END_DATE: '2025-01-23',
    // 回退到的水位线时间
    ROLLBACK_TIMESTAMP: '2025-01-20 23:59:59'
};

const pb = new PocketBase(CONFIG.PB_URL);

/**
 * 删除指定日期范围的统计记录
 */
async function cleanupTripStatsSummary() {
    console.log('\n📊 开始清理 trip_stats_summary...');

    try {
        // 1. 查询需要删除的记录（用于统计数量）
        const recordsToDelete = await pb.collection('trip_stats_summary').getFullList({
            filter: `period_value >= "${CONFIG.START_DATE}" && period_value <= "${CONFIG.END_DATE}"`,
            fields: 'id,period_value,period_type,brand,software_version'
        });

        console.log(`   找到 ${recordsToDelete.length} 条需要清理的统计记录`);

        if (recordsToDelete.length === 0) {
            console.log('   ✅ 没有需要清理的记录');
            return;
        }

        // 2. 显示将要删除的记录详情（前10条）
        console.log('\n   预览将要删除的记录（前10条）：');
        recordsToDelete.slice(0, 10).forEach((record, index) => {
            console.log(`   ${index + 1}. [${record.period_type}] ${record.period_value} - Brand: ${record.brand}, Version: ${record.software_version}`);
        });

        if (recordsToDelete.length > 10) {
            console.log(`   ... 还有 ${recordsToDelete.length - 10} 条记录`);
        }

        // 3. 批量删除
        console.log(`\n   ⏳ 正在删除 ${recordsToDelete.length} 条记录...`);
        let deletedCount = 0;
        let failedCount = 0;

        for (const record of recordsToDelete) {
            try {
                await pb.collection('trip_stats_summary').delete(record.id);
                deletedCount++;

                // 每删除10条显示一次进度
                if (deletedCount % 10 === 0) {
                    console.log(`   进度: ${deletedCount}/${recordsToDelete.length}`);
                }
            } catch (e) {
                console.error(`   ❌ 删除记录 ${record.id} 失败: ${e.message}`);
                failedCount++;
            }
        }

        console.log(`\n   ✅ trip_stats_summary 清理完成！`);
        console.log(`      成功删除: ${deletedCount} 条`);
        if (failedCount > 0) {
            console.log(`      删除失败: ${failedCount} 条`);
        }

    } catch (e) {
        console.error(`\n   ❌ 清理 trip_stats_summary 失败: ${e.message}`);
        throw e;
    }
}

/**
 * 清空用户统计（会在下次归纳时自动重建）
 */
async function cleanupUserStats() {
    console.log('\n👥 开始清理 user_stats...');

    try {
        // 1. 获取所有记录数量
        const allRecords = await pb.collection('user_stats').getFullList({
            fields: 'id,user_id'
        });

        console.log(`   找到 ${allRecords.length} 条用户统计记录`);

        if (allRecords.length === 0) {
            console.log('   ✅ user_stats 为空，无需清理');
            return;
        }

        // 2. 批量删除
        console.log(`\n   ⏳ 正在删除 ${allRecords.length} 条用户统计...`);
        let deletedCount = 0;

        for (const record of allRecords) {
            try {
                await pb.collection('user_stats').delete(record.id);
                deletedCount++;

                if (deletedCount % 10 === 0) {
                    console.log(`   进度: ${deletedCount}/${allRecords.length}`);
                }
            } catch (e) {
                console.error(`   ⚠️ 删除用户统计 ${record.user_id} 失败: ${e.message}`);
            }
        }

        console.log(`\n   ✅ user_stats 清理完成！删除 ${deletedCount} 条记录`);
        console.log(`   ℹ️  这些统计会在下次归纳时自动重建`);

    } catch (e) {
        console.error(`\n   ❌ 清理 user_stats 失败: ${e.message}`);
        throw e;
    }
}

/**
 * 回退统计水位线
 */
async function rollbackStatsState() {
    console.log('\n⏮️  开始回退统计水位线...');

    try {
        // 1. 查找当前的状态记录
        const stateRecord = await pb.collection('stats_state').getFirstListItem('key="current"');

        console.log(`   当前水位线: ${stateRecord.last_timestamp}`);
        console.log(`   目标水位线: ${CONFIG.ROLLBACK_TIMESTAMP}`);

        // 2. 更新水位线
        await pb.collection('stats_state').update(stateRecord.id, {
            last_timestamp: CONFIG.ROLLBACK_TIMESTAMP
        });

        console.log(`   ✅ 水位线已回退到: ${CONFIG.ROLLBACK_TIMESTAMP}`);
        console.log(`   ℹ️  下次归纳将从此时间点开始重新处理数据`);

    } catch (e) {
        if (e.status === 404) {
            console.log('   ⚠️  未找到 stats_state 记录，尝试创建新记录...');
            try {
                await pb.collection('stats_state').create({
                    key: 'current',
                    last_timestamp: CONFIG.ROLLBACK_TIMESTAMP
                });
                console.log(`   ✅ 已创建新的水位线记录: ${CONFIG.ROLLBACK_TIMESTAMP}`);
            } catch (createError) {
                console.error(`   ❌ 创建水位线记录失败: ${createError.message}`);
                throw createError;
            }
        } else {
            console.error(`\n   ❌ 回退水位线失败: ${e.message}`);
            throw e;
        }
    }
}

/**
 * 主清理流程
 */
async function performCleanup() {
    console.log('╔════════════════════════════════════════════════════════════╗');
    console.log('║        Puked 统计数据清理工具 v1.0                        ║');
    console.log('╚════════════════════════════════════════════════════════════╝');
    console.log(`\n清理日期范围: ${CONFIG.START_DATE} ~ ${CONFIG.END_DATE}`);
    console.log(`回退水位线至: ${CONFIG.ROLLBACK_TIMESTAMP}\n`);

    try {
        // 1. 登录
        console.log('🔐 正在登录 PocketBase...');
        await pb.admins.authWithPassword(CONFIG.ADMIN_EMAIL, CONFIG.ADMIN_PASSWORD);
        console.log('✅ 管理员登录成功\n');

        // 2. 清理 trip_stats_summary
        await cleanupTripStatsSummary();

        // 3. 清理 user_stats
        await cleanupUserStats();

        // 4. 回退水位线
        await rollbackStatsState();

        // 5. 完成
        console.log('\n╔════════════════════════════════════════════════════════════╗');
        console.log('║                    ✨ 清理完成！                          ║');
        console.log('╚════════════════════════════════════════════════════════════╝');
        console.log('\n📋 后续操作：');
        console.log('   1. 在移动端竞技场页面点击"强制刷新"按钮');
        console.log('   2. 或者等待 auto_induction.js 自动运行（30分钟一次）');
        console.log('   3. 系统会重新计算 1月21日之后的所有统计数据');
        console.log('\n   💡 提示：user_stats 会在下次归纳时自动重建\n');

    } catch (error) {
        console.error('\n╔════════════════════════════════════════════════════════════╗');
        console.error('║                    ❌ 清理失败！                          ║');
        console.error('╚════════════════════════════════════════════════════════════╝');
        console.error(`\n错误信息: ${error.message}`);
        console.error(`\n请检查：`);
        console.error(`   1. PocketBase 服务是否正常运行`);
        console.error(`   2. 管理员账号密码是否正确`);
        console.error(`   3. 网络连接是否正常`);
        console.error(`   4. 数据表结构是否正确\n`);
        process.exit(1);
    }
}

// 执行清理
performCleanup();
