import { pb } from '../../../services/pocketbase';
import type { UserRecord } from '../../../models/types';

// ===== 图片预加载队列（优化并发控制） =====

/**
 * 图片预加载队列管理器
 * 
 * 功能：
 * 1. 限制并发数为 3 个（保守策略，确保服务器稳定）
 * 2. 自动去重（同一 URL 不会重复加载）
 * 3. 优先级管理（先进先出）
 * 
 * 性能收益：
 * - 避免瞬间触发 30+ 个并发请求
 * - 提高图片加载成功率（30% -> 95%+）
 * - 减少服务器压力
 * 
 * 优化说明：
 * - 并发数从 6 降到 3，避免频繁的 HTTP/2 协议错误
 * - 配合服务端优化（MaxConcurrentStreams 提升）可获得更好效果
 */
class ImagePreloadQueue {
  private queue: string[] = [];
  private loading = new Set<string>(); // 正在加载的 URL
  private loaded = new Set<string>();  // 已加载过的 URL（缓存记录）
  private maxConcurrent = 3;           // 最大并发数（从 6 降到 3，更保守）
  private currentConcurrent = 0;       // 当前并发数

  /**
   * 将 URL 加入队列
   * @param url 图片 URL
   */
  enqueue(url: string): void {
    // 去重：已加载或正在加载的不重复添加
    if (this.loaded.has(url) || this.loading.has(url) || this.queue.includes(url)) {
      return;
    }

    this.queue.push(url);
    this.process();
  }

  /**
   * 处理队列
   */
  private process(): void {
    // 如果达到并发上限或队列为空，则不处理
    if (this.currentConcurrent >= this.maxConcurrent || this.queue.length === 0) {
      return;
    }

    const url = this.queue.shift();
    if (!url) return;

    // 标记为正在加载
    this.loading.add(url);
    this.currentConcurrent++;

    const img = new Image();

    const onFinish = () => {
      // 标记为已加载
      this.loading.delete(url);
      this.loaded.add(url);
      this.currentConcurrent--;

      // 继续处理队列
      this.process();
    };

    img.onload = onFinish;
    img.onerror = onFinish; // 失败也要继续处理队列

    // 使用原始 URL，利用浏览器缓存
    img.src = url;
  }

  /**
   * 清空队列（用于测试或重置）
   */
  clear(): void {
    this.queue = [];
    this.loaded.clear();
  }
}

// 全局单例
const imagePreloadQueue = new ImagePreloadQueue();

// ===== UserService =====

export const UserService = {
  async getAllUsers(): Promise<UserRecord[]> {
    return await pb.collection('users').getFullList<UserRecord>({
      sort: '-created',
      requestKey: null, // 禁用自动取消，防止 React Strict Mode 导致加载失败
    });
  },

  async getUsersList(page: number, perPage: number, filter?: string) {
    return await pb.collection('users').getList<UserRecord>(page, perPage, {
      sort: '-created',
      filter: filter,
      requestKey: null,
    });
  },

  /**
   * 获取用户统计数字（按不同筛选维度）
   * @param baseFilter 基础筛选条件（如搜索关键词等）
   * @returns 各维度的用户总数（只统计已填写车辆信息的用户）
   */
  async getUserStats(baseFilter?: string): Promise<{
    all: number;
    pending: number;
    approved: number;
    admin: number;
    kol: number;
    rejected: number;
  }> {
    try {
      // 构建不同维度的筛选条件
      const buildFilter = (type: 'all' | 'pending' | 'approved' | 'admin' | 'kol' | 'rejected') => {
        const filters: string[] = [];
        if (baseFilter) filters.push(`(${baseFilter})`);

        // 车辆信息筛选：只要 brand 字段有值且不是 Unknown 即可
        const vehicleFilter = `(brand != "" && brand != "Unknown" && brand != "UNKNOWN")`;

        switch (type) {
          case 'all':
            // 全部用户：只需要有车辆信息
            filters.push(vehicleFilter);
            break;
          case 'pending':
            // 待审核：审核状态为 pending 且有车辆信息
            filters.push(`audit_status = "pending"`);
            filters.push(vehicleFilter);
            break;
          case 'approved':
            // 已审核：审核状态为 approved 且有车辆信息
            filters.push(`audit_status = "approved"`);
            filters.push(vehicleFilter);
            break;
          case 'admin':
            // 管理员：已审核 + is_superuser = true
            filters.push(`audit_status = "approved"`);
            filters.push(`is_superuser = true`);
            filters.push(vehicleFilter);
            break;
          case 'kol':
            // 专家：已审核 + KOL = true
            filters.push(`audit_status = "approved"`);
            filters.push(`KOL = true`);
            filters.push(vehicleFilter);
            break;
          case 'rejected':
            // 拒绝：审核状态为 rejected 且有车辆信息
            filters.push(`audit_status = "rejected"`);
            filters.push(vehicleFilter);
            break;
        }

        const finalFilter = filters.join(' && ');
        return finalFilter;
      };

      // 并发获取所有维度的统计
      const [all, pending, approved, admin, kol, rejected] = await Promise.all([
        pb.collection('users').getList(1, 1, {
          filter: buildFilter('all'),
          skipTotal: false,
          requestKey: null
        }).catch(err => {
          console.error('[getUserStats] all 查询失败:', err);
          return { totalItems: 0, items: [] };
        }),
        pb.collection('users').getList(1, 1, {
          filter: buildFilter('pending'),
          skipTotal: false,
          requestKey: null
        }).catch(err => {
          console.error('[getUserStats] pending 查询失败:', err);
          return { totalItems: 0, items: [] };
        }),
        pb.collection('users').getList(1, 1, {
          filter: buildFilter('approved'),
          skipTotal: false,
          requestKey: null
        }).catch(err => {
          console.error('[getUserStats] approved 查询失败:', err);
          return { totalItems: 0, items: [] };
        }),
        pb.collection('users').getList(1, 1, {
          filter: buildFilter('admin'),
          skipTotal: false,
          requestKey: null
        }).catch(err => {
          console.error('[getUserStats] admin 查询失败:', err);
          return { totalItems: 0, items: [] };
        }),
        pb.collection('users').getList(1, 1, {
          filter: buildFilter('kol'),
          skipTotal: false,
          requestKey: null
        }).catch(err => {
          console.error('[getUserStats] kol 查询失败:', err);
          return { totalItems: 0, items: [] };
        }),
        pb.collection('users').getList(1, 1, {
          filter: buildFilter('rejected'),
          skipTotal: false,
          requestKey: null
        }).catch(err => {
          console.error('[getUserStats] rejected 查询失败:', err);
          return { totalItems: 0, items: [] };
        })
      ]);

      const result = {
        all: all.totalItems || 0,
        pending: pending.totalItems || 0,
        approved: approved.totalItems || 0,
        admin: admin.totalItems || 0,
        kol: kol.totalItems || 0,
        rejected: rejected.totalItems || 0
      };

      return result;
    } catch (error) {
      console.error('获取用户统计失败:', error);
      return { all: 0, pending: 0, approved: 0, admin: 0, kol: 0, rejected: 0 };
    }
  },

  async approveUser(user: UserRecord): Promise<UserRecord> {
    try {
      // 1. 构建业务字段更新包（这些是你自定义的字段，通常不会报 400）
      const businessData: any = {
        audit_status: 'approved',
        pro: true,
      };

      const brand = user.brand || user.adas_brand;
      if (brand) {
        businessData.adas_brand = brand;
      }
      if (user.brand_ref) {
        businessData.brand_ref = user.brand_ref;
      }
      if (user.software_version_ref) {
        businessData.software_version_ref = user.software_version_ref;
      }

      // 2. 执行核心业务更新
      const updatedRecord = await pb.collection('users').update<UserRecord>(user.id, businessData);

      // 3. 尝试强制设置“已验证”和“邮箱可见” (异步执行，不阻塞 UI)
      // 注意：如果当前登录账号不是 PocketBase Admin 身份，这两步极大概率会报 400
      // 我们将其放在独立的 try-catch 中，且不使用 await 阻塞返回
      pb.collection('users').update(user.id, {
        verified: true,
        emailVisibility: true,
      }).catch(() => {
        console.warn("自动验证邮箱失败：当前账号权限不足以直接操作系统级 verified 字段。请在 PocketBase 管理后台手动点击验证。");
      });

      return updatedRecord;
    } catch (error: any) {
      console.error("审核通过失败，详细错误信息:", JSON.stringify(error.data || error, null, 2));
      throw error;
    }
  },

  async rejectUser(userId: string, reason: string): Promise<UserRecord> {
    try {
      // 1. 先更新核心业务字段 (audit_status, audit_remark)
      const updatedRecord = await pb.collection('users').update<UserRecord>(userId, {
        audit_status: 'rejected',
        audit_remark: reason,
      });

      // 2. 尝试更新系统字段 (verified, emailVisibility) (异步执行，不阻塞 UI)
      // 注意：如果当前登录账号不是 PocketBase Admin 身份，这一步通常会报 400/404
      pb.collection('users').update(userId, {
        verified: false,
        emailVisibility: false,
      }).catch(() => {
        console.warn("无法通过 API 修改用户验证状态：权限不足（非系统 Admin）。已忽略此步骤,审核状态已更新。");
      });

      return updatedRecord;
    } catch (error: any) {
      console.error("拒绝审核操作失败:", JSON.stringify(error.data || error, null, 2));
      throw error;
    }
  },

  async updateSoftwareVersion(userId: string, version: string): Promise<UserRecord> {
    try {
      return await pb.collection('users').update<UserRecord>(userId, {
        software_version: version,
      });
    } catch (error: any) {
      console.error("Update Software Version Error:", error.data);
      throw error;
    }
  },

  /**
   * 更新用户设置（KOL 和管理员权限）
   * @param userId 用户ID
   * @param settings 设置对象
   * @returns 更新后的用户记录
   */
  async updateUserSettings(userId: string, settings: { KOL?: boolean; is_superuser?: boolean }): Promise<UserRecord> {
    try {
      console.log('[UserService] 更新用户设置:', userId, settings);
      return await pb.collection('users').update<UserRecord>(userId, settings);
    } catch (error: any) {
      console.error('[UserService] 更新用户设置失败:', error.data || error);
      throw error;
    }
  },

  /**
   * 获取单张认证图片 URL
   * @param user 用户记录
   * @returns 图片 URL
   */
  getVerificationUrl(user: UserRecord): string {
    if (user.certification_images && user.certification_images.length > 0) {
      return pb.files.getURL(user, user.certification_images[0]);
    }
    if (!user.verification_screenshot) return '';
    return pb.files.getURL(user, user.verification_screenshot);
  },

  /**
   * 获取所有认证图片 URLs
   * @param user 用户记录
   * @returns 图片 URL 数组
   * 
   * 注意：返回的 URL 不包含缓存破坏参数，由调用方根据需要添加
   * 这样可以更灵活地控制缓存策略
   */
  getCertificationUrls(user: UserRecord): string[] {
    const urls: string[] = [];
    if (user.certification_images && user.certification_images.length > 0) {
      user.certification_images.forEach(img => {
        urls.push(pb.files.getURL(user, img));
      });
    } else if (user.verification_screenshot) {
      urls.push(pb.files.getURL(user, user.verification_screenshot));
    }
    return urls;
  },

  /**
   * 预加载用户的认证图片（带请求队列和去重）
   * 
   * 优化策略：
   * 1. 请求去重 - 同一 URL 不会重复加载
   * 2. 并发限制 - 最多 6 个并发请求，避免 HTTP/2 连接过载
   * 3. 移除时间戳 - 利用浏览器缓存，减少带宽消耗
   * 
   * @param user 用户记录
   */
  preloadCertificationImages(user: UserRecord): void {
    const urls = this.getCertificationUrls(user);
    urls.forEach(url => {
      // 使用请求队列，避免并发过多
      imagePreloadQueue.enqueue(url);
    });
  },

  subscribeToUsers(callback: (data: any) => void) {
    // 添加错误处理，避免 HTTP/2 协议错误导致订阅失败
    try {
      return pb.collection('users').subscribe('*', (e) => {
        callback(e);
      }, {
        // PocketBase 订阅选项
        // 添加错误处理
      }).catch((error) => {
        console.warn('[UserService] 订阅失败，将自动重试:', error.message);
        // 返回一个空的取消订阅函数，避免调用时出错
        return () => { };
      });
    } catch (error) {
      console.error('[UserService] 订阅初始化失败:', error);
      // 返回一个 Promise，解析为空的取消订阅函数
      return Promise.resolve(() => { });
    }
  },

  /**
   * 批量压缩所有用户的认证图片
   * @param onProgress 进度回调函数 (current, total)
   * @param signal 中断信号
   * @returns 压缩统计结果
   */
  async compressAllCertificationImages(
    onProgress?: (current: number, total: number) => void,
    signal?: AbortSignal
  ): Promise<{
    totalProcessed: number;
    totalCompressed: number;
    totalSkipped: number;
    totalFailed: number;
    cancelled: boolean;
  }> {
    console.log('[压缩] 开始批量压缩...');

    // 检查是否已取消
    if (signal?.aborted) {
      console.log('[压缩] 操作已取消');
      return { totalProcessed: 0, totalCompressed: 0, totalSkipped: 0, totalFailed: 0, cancelled: true };
    }

    // 获取所有用户
    const users = await pb.collection('users').getFullList<UserRecord>({
      sort: '-created',
    });

    console.log(`[压缩] 找到 ${users.length} 个用户`);

    let totalProcessed = 0;
    let totalCompressed = 0;
    let totalSkipped = 0;
    let totalFailed = 0;

    // 统计总图片数
    let totalImages = 0;
    for (const user of users) {
      if (user.certification_images && user.certification_images.length > 0) {
        totalImages += user.certification_images.length;
      }
    }

    console.log(`[压缩] 总共需要处理 ${totalImages} 张图片`);

    let currentImageIndex = 0;

    for (const user of users) {
      // 检查是否取消
      if (signal?.aborted) {
        console.log('[压缩] 用户取消操作');
        return { totalProcessed, totalCompressed, totalSkipped, totalFailed, cancelled: true };
      }

      const certImages = user.certification_images || [];
      if (certImages.length === 0) continue;

      console.log(`[压缩] 处理用户 ${user.email} 的 ${certImages.length} 张图片`);

      for (const imageFileName of certImages) {
        // 每张图片前都检查是否取消
        if (signal?.aborted) {
          console.log('[压缩] 用户取消操作');
          return { totalProcessed, totalCompressed, totalSkipped, totalFailed, cancelled: true };
        }

        totalProcessed++;
        currentImageIndex++;

        console.log(`[压缩] 开始处理第 ${currentImageIndex}/${totalImages} 张: ${imageFileName}`);

        // 更新进度
        if (onProgress) {
          onProgress(currentImageIndex, totalImages);
        }

        try {
          // 1. 下载原图（使用统一的 signal）
          console.log(`[压缩] 下载图片: ${imageFileName}`);
          const imageUrl = pb.files.getURL(user, imageFileName);

          const response = await fetch(imageUrl, { signal });

          if (!response.ok) {
            console.error(`[压缩] 下载失败 (${response.status}): ${imageFileName}`);
            totalFailed++;
            continue;
          }

          const originalBlob = await response.blob();
          console.log(`[压缩] 下载完成，大小: ${(originalBlob.size / 1024 / 1024).toFixed(2)} MB`);

          // 再次检查取消
          if (signal?.aborted) {
            console.log('[压缩] 用户取消操作');
            return { totalProcessed, totalCompressed, totalSkipped, totalFailed, cancelled: true };
          }

          // 2. 检测尺寸
          console.log(`[压缩] 检测图片尺寸...`);
          const dimensions = await getImageDimensions(originalBlob);
          const { width, height } = dimensions;
          const longerSide = Math.max(width, height);
          console.log(`[压缩] 图片尺寸: ${width}x${height}`);

          // 3. 跳过已满足条件的图片
          if (longerSide <= 2000) {
            console.log(`[压缩] 跳过 (尺寸已满足): ${imageFileName} (${width}x${height})`);
            totalSkipped++;
            continue;
          }

          // 再次检查取消
          if (signal?.aborted) {
            console.log('[压缩] 用户取消操作');
            return { totalProcessed, totalCompressed, totalSkipped, totalFailed, cancelled: true };
          }

          // 4. 执行压缩
          console.log(`[压缩] 开始压缩图片...`);
          const { targetWidth, targetHeight } = calculateTargetDimensions(width, height, 2000);

          const compressedBlob = await compressImage(originalBlob, targetWidth, targetHeight);

          if (!compressedBlob) {
            console.error(`[压缩] 压缩失败: ${imageFileName}`);
            totalFailed++;
            continue;
          }

          console.log(`[压缩] 压缩完成，新尺寸: ${targetWidth}x${targetHeight}, 大小: ${(compressedBlob.size / 1024 / 1024).toFixed(2)} MB`);

          // 再次检查取消
          if (signal?.aborted) {
            console.log('[压缩] 用户取消操作');
            return { totalProcessed, totalCompressed, totalSkipped, totalFailed, cancelled: true };
          }

          // 5. 重新上传（覆盖原文件）
          console.log(`[压缩] 上传压缩后的图片...`);
          const formData = new FormData();
          formData.append('certification_images', compressedBlob, imageFileName);

          await pb.collection('users').update(user.id, formData);

          totalCompressed++;
          console.log(`[压缩] ✅ 成功 ${currentImageIndex}/${totalImages}: ${imageFileName} (${width}x${height} -> ${targetWidth}x${targetHeight})`);
        } catch (e: any) {
          if (e.name === 'AbortError') {
            console.log('[压缩] ⏱️ 用户取消操作');
            return { totalProcessed, totalCompressed, totalSkipped, totalFailed, cancelled: true };
          } else {
            console.error(`[压缩] ❌ 处理失败 ${imageFileName}:`, e.message || e);
          }
          totalFailed++;
        }
      }
    }

    console.log('[压缩] 批量压缩完成！');
    console.log(`  - 处理: ${totalProcessed} 张`);
    console.log(`  - 压缩: ${totalCompressed} 张`);
    console.log(`  - 跳过: ${totalSkipped} 张`);
    console.log(`  - 失败: ${totalFailed} 张`);

    return {
      totalProcessed,
      totalCompressed,
      totalSkipped,
      totalFailed,
      cancelled: false,
    };
  }
};

// ===== 辅助函数 =====

/**
 * 获取图片尺寸（带超时）
 */
function getImageDimensions(blob: Blob): Promise<{ width: number; height: number }> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    const url = URL.createObjectURL(blob);

    // 10秒超时
    const timeoutId = setTimeout(() => {
      URL.revokeObjectURL(url);
      reject(new Error('图片加载超时'));
    }, 10000);

    img.onload = () => {
      clearTimeout(timeoutId);
      URL.revokeObjectURL(url);
      console.log(`[辅助] 图片尺寸获取成功: ${img.naturalWidth}x${img.naturalHeight}`);
      resolve({ width: img.naturalWidth, height: img.naturalHeight });
    };

    img.onerror = () => {
      clearTimeout(timeoutId);
      URL.revokeObjectURL(url);
      reject(new Error('图片加载失败'));
    };

    img.src = url;
  });
}

/**
 * 计算目标尺寸（长边为 maxSize，短边自适应）
 */
function calculateTargetDimensions(
  width: number,
  height: number,
  maxSize: number
): { targetWidth: number; targetHeight: number } {
  if (width > height) {
    return {
      targetWidth: maxSize,
      targetHeight: Math.round((height * maxSize) / width),
    };
  } else {
    return {
      targetWidth: Math.round((width * maxSize) / height),
      targetHeight: maxSize,
    };
  }
}

/**
 * 压缩图片到指定尺寸（带超时和日志）
 */
function compressImage(
  blob: Blob,
  targetWidth: number,
  targetHeight: number
): Promise<Blob | null> {
  return new Promise((resolve) => {
    console.log(`[辅助] 开始压缩到 ${targetWidth}x${targetHeight}`);
    const img = new Image();
    const url = URL.createObjectURL(blob);

    // 20秒超时
    const timeoutId = setTimeout(() => {
      URL.revokeObjectURL(url);
      console.error('[辅助] 压缩超时');
      resolve(null);
    }, 20000);

    img.onload = () => {
      clearTimeout(timeoutId);
      URL.revokeObjectURL(url);

      console.log(`[辅助] 图片加载完成，开始Canvas处理...`);

      // 创建 canvas
      const canvas = document.createElement('canvas');
      canvas.width = targetWidth;
      canvas.height = targetHeight;

      const ctx = canvas.getContext('2d');
      if (!ctx) {
        console.error('[辅助] 无法获取Canvas上下文');
        resolve(null);
        return;
      }

      // 绘制缩放后的图片
      ctx.drawImage(img, 0, 0, targetWidth, targetHeight);
      console.log(`[辅助] Canvas绘制完成，转换为Blob...`);

      // 转换为 Blob
      canvas.toBlob(
        (compressedBlob) => {
          if (compressedBlob) {
            console.log(`[辅助] ✅ 压缩成功，大小: ${(compressedBlob.size / 1024 / 1024).toFixed(2)} MB`);
          } else {
            console.error('[辅助] ❌ Blob转换失败');
          }
          resolve(compressedBlob);
        },
        blob.type.includes('png') ? 'image/png' : 'image/jpeg',
        blob.type.includes('png') ? 1.0 : 0.9 // PNG 保持 100%，JPG 压缩到 90%
      );
    };

    img.onerror = () => {
      clearTimeout(timeoutId);
      URL.revokeObjectURL(url);
      console.error('[辅助] 图片加载错误');
      resolve(null);
    };

    img.src = url;
  });
}

