import PocketBase from 'pocketbase';

/**
 * PocketBase 数据清洗脚本
 * 功能：将带有“用户自定义”标签的版本号迁移到对应的正式版本号，并删除冗余版本。
 * 
 * 使用方法：
 * 1. 进入 Puked_web 目录: cd Puked_web
 * 2. 安装依赖: npm install
 * 3. 设置环境变量并运行:
 *    PB_ADMIN_EMAIL=your@email.com PB_ADMIN_PASSWORD=your_password node ../scripts/cleanup_versions.js
 */

const PB_URL = 'https://pb.osglab.com';
const ADMIN_EMAIL = process.env.PB_ADMIN_EMAIL;
const ADMIN_PASSWORD = process.env.PB_ADMIN_PASSWORD;

if (!ADMIN_EMAIL || !ADMIN_PASSWORD) {
    console.error('❌ 错误: 请设置环境变量 PB_ADMIN_EMAIL 和 PB_ADMIN_PASSWORD');
    process.exit(1);
}

async function cleanup() {
    const pb = new PocketBase(PB_URL);

    try {
        console.log('🚀 正在连接 PocketBase 并登录 Admin...');
        await pb.admins.authWithPassword(ADMIN_EMAIL, ADMIN_PASSWORD);
        console.log('✅ 登录成功！');

        console.log('📦 获取所有软件版本信息...');
        const allVersions = await pb.collection('software_versions').getFullList({
            requestKey: null,
        });
        console.log(`📊 共获取到 ${allVersions.length} 条版本记录`);

        const officialMap = new Map(); // key: brandId_versionString, value: record
        const customRecords = [];

        // 第一步：对版本进行分类
        for (const v of allVersions) {
            const vs = v.versionString || '';
            // 匹配“用户自定义”或“自定义”标签
            const isCustom = vs.includes('用户自定义') || vs.includes('自定义');
            
            if (isCustom) {
                customRecords.push(v);
            } else {
                const key = `${v.brand}_${vs.trim()}`;
                // 如果存在多个相同的正式版本号，保留最早创建的一个（ID 通常反映创建顺序）
                if (!officialMap.has(key)) {
                    officialMap.set(key, v);
                }
            }
        }

        console.log(`🔍 识别到 ${customRecords.length} 条待处理的自定义版本记录`);

        // 第二步：执行迁移和清理
        for (const custom of customRecords) {
            // 提取核心版本号（移除各种格式的自定义标签）
            const coreVersion = custom.versionString
                .replace(/\s*\(?用户自定义\)?\s*/g, '')
                .replace(/\s*\(?自定义\)?\s*/g, '')
                .trim();
            
            const key = `${custom.brand}_${coreVersion}`;
            const official = officialMap.get(key);

            if (official) {
                console.log(`\n🔄 迁移: "${custom.versionString}" -> 官方版本: "${official.versionString}" (ID: ${official.id})`);

                // 迁移关联的用户
                const users = await pb.collection('users').getFullList({
                    filter: `software_version_ref = "${custom.id}"`,
                    requestKey: null,
                });
                if (users.length > 0) {
                    console.log(`   - 正在迁移 ${users.length} 个用户...`);
                    for (const user of users) {
                        await pb.collection('users').update(user.id, {
                            software_version_ref: official.id,
                            software_version: official.versionString
                        });
                    }
                }

                // 迁移关联的行程 (Trips)
                const trips = await pb.collection('trips').getFullList({
                    filter: `software_version_ref = "${custom.id}"`,
                    requestKey: null,
                });
                if (trips.length > 0) {
                    console.log(`   - 正在迁移 ${trips.length} 个行程...`);
                    for (const trip of trips) {
                        await pb.collection('trips').update(trip.id, {
                            software_version_ref: official.id,
                            software_version: official.versionString
                        });
                    }
                }

                // 删除冗余的自定义版本记录
                console.log(`   - 删除冗余记录: ${custom.id}`);
                await pb.collection('software_versions').delete(custom.id);

            } else {
                // 如果没有找到对应的官方版本，则将此记录更名为核心版本号（即“转正”）
                console.log(`\n✨ 转正: "${custom.versionString}" 无对应官方版本，更名为 "${coreVersion}"`);
                await pb.collection('software_versions').update(custom.id, {
                    versionString: coreVersion
                });
                
                // 同步更新关联数据中的显示字符串
                const users = await pb.collection('users').getFullList({
                    filter: `software_version_ref = "${custom.id}"`,
                    requestKey: null,
                });
                for (const user of users) {
                    await pb.collection('users').update(user.id, {
                        software_version: coreVersion
                    });
                }

                const trips = await pb.collection('trips').getFullList({
                    filter: `software_version_ref = "${custom.id}"`,
                    requestKey: null,
                });
                for (const trip of trips) {
                    await pb.collection('trips').update(trip.id, {
                        software_version: coreVersion
                    });
                }

                // 将该版本记录视为该品牌的“正式版”
                officialMap.set(key, { ...custom, versionString: coreVersion });
            }
        }

        console.log('\n✨ 所有数据迁移与清理任务已成功完成！');

    } catch (error) {
        console.error('\n❌ 处理过程中发生错误:', error.message || error);
        if (error.data) {
            console.error('详细信息:', JSON.stringify(error.data, null, 2));
        }
    }
}

cleanup();
