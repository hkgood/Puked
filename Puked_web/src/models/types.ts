export type TripRecord = {
  id: string;
  collectionId: string;
  collectionName: string;
  created: string;
  updated: string;
  user: string;
  brand: string;
  brand_ref?: string;
  car_model: string;
  software_version: string;
  software_version_ref?: string;
  is_public: boolean;
  metrics: {
    event_count: number;
    distance: number;
    duration_seconds: number;
  };
  route_summary: Array<{ lat: number; lng: number }>;
  raw_log_file: string;
  share_slug: string;
  expand?: {
    user: {
      username: string;
      avatar: string;
    };
  };
};

export type UserRecord = {
  id: string;
  username: string;
  email: string;
  name?: string;
  avatar?: string;
  brand?: string;
  brand_ref?: string;
  adas_brand?: string;
  car_model?: string;
  software_version?: string;
  software_version_ref?: string;
  verification_screenshot?: string;
  certification_images?: string[];
  verified: boolean;
  emailVisibility: boolean;
  is_superuser: boolean;
  KOL?: boolean;
  audit_status: 'pending' | 'approved' | 'rejected';
  audit_remark?: string;
  pro: boolean;
  collectionId: string;
  collectionName: string;
  created: string;
  updated: string;
};

export type BrandRecord = {
  id: string;
  name: string;
  displayName: string;
  isEnabled: boolean;
  logo: string;
  order: number;
  collectionId: string;
  collectionName: string;
  created: string;
  updated: string;
};

export type SoftwareVersionRecord = {
  id: string;
  name?: string; // Compatibility
  versionString: string;
  brand: string;
  collectionId: string;
  collectionName: string;
  created: string;
  updated: string;
  expand?: {
    brand: BrandRecord;
  };
};

export type ArenaStats = {
  label: string;
  brand: string;
  kmPerEvent: number;
  totalKm: number;
  totalEvents: number;
  symptoms: {
    rapidAcceleration: number;
    rapidDeceleration: number;
    jerk: number;
    bump: number;
    wobble: number;
  };
};

export type AlgorithmConfig = {
  id: string;
  threshold_accel: number;
  threshold_decel: number;
  threshold_wobble_span: number;
  threshold_bump: number;
  threshold_jerk: number;
  threshold_pitch: number;
  jerk_window_ms: number;
  accel_decel_window_ms: number;
  wobble_window_ms: number;
  fusion_window_ms: number;
  zy_interference_threshold: number;
  pitch_validation_enabled: boolean;
  speed_low_factor: number;
  speed_high_factor: number;
  max_jerk_allowed: number;
  max_accel_allowed: number;
  max_wobble_span_allowed: number;
  max_bump_allowed: number;
  min_accel_for_jerk: number; // Jerk 触发的最小加速度基准 (G)
  version: number;
  updated: string;
};
