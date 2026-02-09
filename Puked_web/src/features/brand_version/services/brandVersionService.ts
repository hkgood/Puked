import { pb } from '../../../services/pocketbase';
import type { BrandRecord, SoftwareVersionRecord } from '../../../models/types';

export const BrandVersionService = {
  // Brand operations
  async getAllBrands(): Promise<BrandRecord[]> {
    return await pb.collection('brands').getFullList<BrandRecord>({
      sort: 'order',
      requestKey: null,
    });
  },

  async createBrand(data: { displayName: string; isEnabled: boolean; order?: number; logo?: File }): Promise<BrandRecord> {
    const formData = new FormData();
    formData.append('displayName', data.displayName);
    formData.append('name', data.displayName.toLowerCase().replace(/\s+/g, '_'));
    formData.append('isEnabled', String(data.isEnabled));
    if (data.order !== undefined) {
      formData.append('order', String(data.order));
    }
    if (data.logo) {
      formData.append('logo', data.logo);
    }
    return await pb.collection('brands').create<BrandRecord>(formData);
  },

  async updateBrand(id: string, data: { displayName?: string; isEnabled?: boolean; order?: number; logo?: File }): Promise<BrandRecord> {
    const formData = new FormData();
    if (data.displayName !== undefined) {
      formData.append('displayName', data.displayName);
      formData.append('name', data.displayName.toLowerCase().replace(/\s+/g, '_'));
    }
    if (data.isEnabled !== undefined) {
      formData.append('isEnabled', String(data.isEnabled));
    }
    if (data.order !== undefined) {
      formData.append('order', String(data.order));
    }
    if (data.logo) {
      formData.append('logo', data.logo);
    }
    return await pb.collection('brands').update<BrandRecord>(id, formData);
  },

  async deleteBrand(id: string): Promise<boolean> {
    return await pb.collection('brands').delete(id);
  },

  // Software version operations
  async getAllVersions(): Promise<SoftwareVersionRecord[]> {
    return await pb.collection('software_versions').getFullList<SoftwareVersionRecord>({
      sort: '-created',
      expand: 'brand',
      requestKey: null,
    });
  },

  async getVersionsByBrand(brandId: string): Promise<SoftwareVersionRecord[]> {
    return await pb.collection('software_versions').getFullList<SoftwareVersionRecord>({
      filter: `brand = "${brandId}"`,
      sort: '-created',
      expand: 'brand',
      requestKey: null,
    });
  },

  async createVersion(name: string, brandId: string): Promise<SoftwareVersionRecord> {
    return await pb.collection('software_versions').create<SoftwareVersionRecord>({
      versionString: name,
      brand: brandId,
      isEnabled: true,
    });
  },

  async updateVersion(id: string, data: Partial<SoftwareVersionRecord>): Promise<SoftwareVersionRecord> {
    // If updating 'name' in our UI, it maps to 'versionString' in DB
    const updateData: any = { ...data };
    if (updateData.name) {
      updateData.versionString = updateData.name;
      delete updateData.name;
    }
    return await pb.collection('software_versions').update<SoftwareVersionRecord>(id, updateData);
  },

  async deleteVersion(id: string): Promise<boolean> {
    return await pb.collection('software_versions').delete(id);
  },

  // Real-time subscription
  subscribeToBrands(callback: () => void) {
    try {
      return pb.collection('brands').subscribe('*', callback).catch((error) => {
        console.warn('[BrandVersionService] Brands 订阅失败，将自动重试:', error.message);
        return () => {};
      });
    } catch (error) {
      console.error('[BrandVersionService] Brands 订阅初始化失败:', error);
      return Promise.resolve(() => {});
    }
  },

  subscribeToVersions(callback: () => void) {
    try {
      return pb.collection('software_versions').subscribe('*', callback).catch((error) => {
        console.warn('[BrandVersionService] Versions 订阅失败，将自动重试:', error.message);
        return () => {};
      });
    } catch (error) {
      console.error('[BrandVersionService] Versions 订阅初始化失败:', error);
      return Promise.resolve(() => {});
    }
  },
};

