import { pb } from '../../../services/pocketbase';
import type { TripRecord } from '../../../models/types';

export class TripService {
  /**
   * 抓取所有公开或管理员可见的行程 (全量)
   */
  static async getAllTrips(filter?: string): Promise<TripRecord[]> {
    try {
      return await pb.collection('trips').getFullList<TripRecord>({
        sort: '-created',
        expand: 'user',
        filter: filter,
        // 彻底移除 fields 限制，让后端根据权限自动返回字段，避免 400 错误
        requestKey: null,
      });
    } catch (e) {
      console.error('Fetch trips error:', e);
      return [];
    }
  }

  /**
   * 分页抓取行程
   */
  static async getTripsList(page: number, perPage: number, filter?: string) {
    try {
      return await pb.collection('trips').getList<TripRecord>(page, perPage, {
        sort: '-created',
        expand: 'user',
        filter: filter,
        // 彻底移除 fields 限制，确保搜索逻辑不再因字段缺失而崩溃
        requestKey: null,
      });
    } catch (e) {
      console.error('Fetch trips list error:', e);
      throw e;
    }
  }

  static async getTripById(id: string): Promise<TripRecord> {
    return await pb.collection('trips').getOne<TripRecord>(id, {
      expand: 'user',
    });
  }

  static async updateTrip(id: string, data: any): Promise<TripRecord> {
    return await pb.collection('trips').update<TripRecord>(id, data, {
      requestKey: null
    });
  }

  static async deleteTrip(id: string): Promise<boolean> {
    try {
      await pb.collection('trips').delete(id);
      return true;
    } catch (e) {
      console.error('Delete trip error:', e);
      return false;
    }
  }

  /**
   * 实时订阅新行程
   */
  static subscribeToTrips(callback: (e: any) => void) {
    try {
      return pb.collection('trips').subscribe('*', callback).catch((error) => {
        console.warn('[TripService] 订阅失败，将自动重试:', error.message);
        return () => {};
      });
    } catch (error) {
      console.error('[TripService] 订阅初始化失败:', error);
      return Promise.resolve(() => {});
    }
  }
}
