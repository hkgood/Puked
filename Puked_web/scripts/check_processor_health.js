/**
 * 任务处理器健康检查脚本
 * 用于验证任务处理器是否正常运行
 */

import PocketBase from 'pocketbase';

const PB_URL = process.env.PB_URL || 'https://pb.osglab.com';
const ADMIN_EMAIL = process.env.ADMIN_EMAIL || 'rocky.hk@gmail.com';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'gz203799';

const pb = new PocketBase(PB_URL);

async function checkHealth() {
  try {
    console.log('==========================================');
    console.log('🔍 [HealthCheck] 开始检查任务处理器健康状态...');
    console.log(`📍 [HealthCheck] 目标地址: ${PB_URL}`);
    console.log('==========================================\n');

    // 1. 登录
    try {
      await pb.collection('_superusers').authWithPassword(ADMIN_EMAIL, ADMIN_PASSWORD);
      console.log('✅ 认证成功 (Superuser)');
    } catch (e) {
      await pb.admins.authWithPassword(ADMIN_EMAIL, ADMIN_PASSWORD);
      console.log('✅ 认证成功 (Admin)');
    }

    // 2. 检查心跳
    const stateRecord = await pb.collection('stats_state')
      .getFirstListItem('key="current"', { requestKey: null })
      .catch(() => null);

    if (stateRecord && stateRecord.engine_heartbeat) {
      const heartbeatTime = new Date(stateRecord.engine_heartbeat);
      const now = new Date();
      const diffSeconds = Math.floor((now - heartbeatTime) / 1000);

      console.log(`\n💓 心跳检查:`);
      console.log(`   最后心跳时间: ${stateRecord.engine_heartbeat}`);
      console.log(`   距今: ${diffSeconds} 秒`);
      console.log(`   引擎状态: ${stateRecord.engine_status || 'unknown'}`);

      if (diffSeconds > 600) { // 10分钟无心跳认为异常
        console.log(`   ⚠️  心跳超过 10 分钟未更新，任务处理器可能已停止运行！`);
      } else {
        console.log(`   ✅ 心跳正常`);
      }
    } else {
      console.log(`\n⚠️  未找到心跳记录，任务处理器可能从未启动！`);
    }

    // 3. 检查待处理任务
    const pendingTasks = await pb.collection('sync_tasks').getFullList({
      filter: 'status = "pending"',
      sort: 'created',
      requestKey: null
    });

    console.log(`\n📋 任务队列状态:`);
    console.log(`   待处理任务: ${pendingTasks.length} 个`);

    if (pendingTasks.length > 0) {
      console.log(`   最早任务创建于: ${pendingTasks[0].created}`);
      const taskAge = Math.floor((new Date() - new Date(pendingTasks[0].created)) / 1000);
      console.log(`   最早任务等待时间: ${taskAge} 秒`);

      if (taskAge > 600) { // 10分钟未处理认为异常
        console.log(`   ⚠️  有任务等待超过 10 分钟，任务处理器可能无法正常工作！`);
      }
    } else {
      console.log(`   ✅ 当前无待处理任务`);
    }

    // 4. 检查最近的任务执行情况
    const recentTasks = await pb.collection('sync_tasks').getList(1, 10, {
      sort: '-created',
      requestKey: null
    });

    console.log(`\n📊 最近任务执行情况:`);
    console.log(`   总任务数: ${recentTasks.totalItems}`);

    const stats = {
      success: 0,
      failed: 0,
      running: 0,
      pending: 0
    };

    recentTasks.items.forEach(task => {
      stats[task.status] = (stats[task.status] || 0) + 1;
    });

    console.log(`   成功: ${stats.success} | 失败: ${stats.failed} | 运行中: ${stats.running} | 待处理: ${stats.pending}`);

    // 5. 综合健康评分
    console.log('\n==========================================');
    let healthScore = 100;
    const issues = [];

    if (!stateRecord || !stateRecord.engine_heartbeat) {
      healthScore -= 50;
      issues.push('❌ 无心跳记录');
    } else {
      const diffSeconds = Math.floor((new Date() - new Date(stateRecord.engine_heartbeat)) / 1000);
      if (diffSeconds > 600) { // 10分钟
        healthScore -= 40;
        issues.push('⚠️  心跳超时');
      }
    }

    if (pendingTasks.length > 0) {
      const taskAge = Math.floor((new Date() - new Date(pendingTasks[0].created)) / 1000);
      if (taskAge > 600) { // 10分钟
        healthScore -= 30;
        issues.push('⚠️  任务积压');
      }
    }

    if (stats.failed > stats.success && recentTasks.items.length > 5) {
      healthScore -= 20;
      issues.push('⚠️  失败率偏高');
    }

    console.log(`🏥 健康评分: ${healthScore}/100`);
    if (issues.length > 0) {
      console.log(`⚠️  发现问题:`);
      issues.forEach(issue => console.log(`   ${issue}`));
    } else {
      console.log(`✅ 一切正常！`);
    }
    console.log('==========================================\n');

  } catch (error) {
    console.error('❌ [HealthCheck] 检查失败:', error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

checkHealth();
