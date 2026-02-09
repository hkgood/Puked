/**
 * 检查 trip_stats_summary 数据结构
 */
import PocketBase from 'pocketbase';

const CONFIG = {
    PB_URL: 'https://pb.osglab.com',
    ADMIN_EMAIL: 'rocky.hk@gmail.com',
    ADMIN_PASSWORD: 'gz203799'
};

const pb = new PocketBase(CONFIG.PB_URL);

async function inspect() {
    await pb.admins.authWithPassword(CONFIG.ADMIN_EMAIL, CONFIG.ADMIN_PASSWORD);

    // 获取一些样本数据
    const samples = await pb.collection('trip_stats_summary').getList(1, 10, {
        sort: '-updated'
    });

    console.log('trip_stats_summary 样本数据：\n');
    samples.items.forEach((item, index) => {
        console.log(`\n记录 ${index + 1}:`);
        console.log(`  ID: ${item.id}`);
        console.log(`  Key: ${item.key}`);
        console.log(`  Created: ${item.created}`);
        console.log(`  Updated: ${item.updated}`);
        console.log(`  Period Type: ${item.period_type}`);
        console.log(`  Period Value: ${item.period_value}`);
        console.log(`  Total Distance: ${item.total_distance}`);
        console.log(`  Total Events: ${item.total_events}`);
        console.log(`  Trip Count: ${item.trip_count}`);
    });

    // 统计在 1月21-23日期间更新的记录
    const updatedRecords = await pb.collection('trip_stats_summary').getFullList({
        filter: 'updated >= "2026-01-21 00:00:00" && updated <= "2026-01-23 23:59:59"',
        fields: 'id,created,updated,period_type'
    });

    console.log(`\n\n在 2026-01-21 到 2026-01-23 期间更新的记录数: ${updatedRecords.length}`);

    // 统计在 1月21-23日期间创建的记录
    const createdRecords = await pb.collection('trip_stats_summary').getFullList({
        filter: 'created >= "2026-01-21 00:00:00" && created <= "2026-01-23 23:59:59"',
        fields: 'id,created,updated,period_type'
    });

    console.log(`在 2026-01-21 到 2026-01-23 期间创建的记录数: ${createdRecords.length}`);
}

inspect();
