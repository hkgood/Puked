import { pb } from '../../../services/pocketbase';
import type { AlgorithmConfig } from '../../../models/types';

export class ConfigService {
  private static cachedConfig: AlgorithmConfig | null = null;

  static async getLatestConfig(): Promise<AlgorithmConfig> {
    if (this.cachedConfig) return this.cachedConfig;

    try {
      const records = await pb.collection('algorithm_configs').getList<AlgorithmConfig>(1, 1, {
        sort: '-version',
        requestKey: null
      });

      if (records.items.length > 0) {
        this.cachedConfig = records.items[0];
        return this.cachedConfig;
      }
    } catch (e) {
      console.error('Failed to fetch algorithm config:', e);
    }

    // Fallback to defaults
    return this.getDefaultConfig();
  }

  static getDefaultConfig(): AlgorithmConfig {
    return {
      id: 'default',
      threshold_accel: 2.2,
      threshold_decel: -2.0,
      threshold_wobble_span: 2.5,
      threshold_bump: 5.5,
      threshold_jerk: 6.0,
      threshold_pitch: 1.5,
      jerk_window_ms: 250,
      accel_decel_window_ms: 600,
      wobble_window_ms: 1000,
      fusion_window_ms: 3000,
      zy_interference_threshold: 1.5,
      pitch_validation_enabled: true,
      speed_low_factor: 1.1,
      speed_high_factor: 0.9,
      max_jerk_allowed: 50.0,
      max_accel_allowed: 20.0,
      max_wobble_span_allowed: 20.0,
      max_bump_allowed: 40.0,
      min_accel_for_jerk: 0.25, // 默认 0.25G
      version: 0,
      updated: new Date().toISOString()
    };
  }

  static clearCache() {
    this.cachedConfig = null;
  }
}

