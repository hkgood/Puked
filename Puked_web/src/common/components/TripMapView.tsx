import React, { useEffect, useMemo } from 'react';
import { MapContainer, TileLayer, Polyline, Marker, useMap } from 'react-leaflet';
import L from 'leaflet';
import { useI18n } from '../utils/i18n';

// 修复 Leaflet 默认图标在 React 中的显示问题
import icon from 'leaflet/dist/images/marker-icon.png';
import iconShadow from 'leaflet/dist/images/marker-shadow.png';

let DefaultIcon = L.icon({
  iconUrl: icon,
  shadowUrl: iconShadow,
  iconSize: [25, 41],
  iconAnchor: [12, 41]
});
L.Marker.prototype.options.icon = DefaultIcon;

interface TrajectoryPoint {
  lat: number;
  lng: number;
  low_conf?: boolean;
}

interface RecordedEvent {
  type: string;
  lat?: number;
  lng?: number;
  timestamp: number;
}

interface TripMapViewProps {
  trajectory: TrajectoryPoint[];
  events?: RecordedEvent[];
  height?: string | number;
  isLoading?: boolean;
  focusLocation?: { lat: number; lng: number; timestamp: number } | null;
  showLoadButton?: boolean;  // 是否显示加载按钮
  onLoadDetails?: () => void; // 加载按钮点击回调
}

// 模拟 Native 的事件图标配置
export const getEventConfig = (type: string) => {
  const t = type.toLowerCase();
  if (t.includes('acceleration') || t === 'accel' || t === 'rapid_accel') {
    return { icon: '<path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm.5-13H11v6l5.25 3.15.75-1.23-4.5-2.67z"/>', color: '#F59E0B' };
  } else if (t.includes('deceleration') || t === 'brake' || t === 'rapid_decel') {
    return { icon: '<path d="M16 18l2.29-2.29-4.88-4.88-4 4L2 7.41 3.41 6l6 6 4-4 6.3 6.29L22 12v6z"/>', color: '#EF4444' };
  } else if (t.includes('bump')) {
    return { icon: '<path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm-1-13h2v10h-2zm0 12h2v2h-2z"/>', color: '#F97316' };
  } else if (t.includes('jerk')) {
    return { icon: '<path d="M1 21h22L12 2 1 21zm12-3h-2v-2h2v2zm0-4h-2v-4h2v4z"/>', color: '#6366F1' };
  } else if (type.includes('wobble')) {
    return { icon: '<path d="M10 20H4v-2h6v2zm10-2h-6v2h6v-2zM4 14h6v2H4v-2zm16 0h-6v2h6v-2zM4 10h6v2H4v-2zm16 0h-6v2h6v-2zM4 6h6v2H4V6zm16 0h-6v2h6V6z"/>', color: '#AF52DE' };
  } else if (type === 'proDisengagement') {
    return { icon: '<path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm-1-13h2v6h-2zm0 8h2v2h-2z"/>', color: '#EF4444' };
  } else if (type === 'proViolation' || type === 'manual') {
    return { icon: '<path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/>', color: '#6366F1' };
  } else if (type === 'proExperience') {
    return { icon: '<path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8zm-1-13h2v6h-2zm0 8h2v2h-2z"/>', color: '#007AFF' };
  }
  return { icon: '<path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/>', color: '#8E8E93' };
};

// 模拟 Native 的自定义标记图标
const createMarkerIcon = (color: string, iconType: 'start' | 'end' | 'event', svgPath?: string) => {
  return L.divIcon({
    html: `
      <div style="
        background-color: ${color};
        width: 20px;
        height: 20px;
        border-radius: 50%;
        border: 1.5px solid white;
        display: flex;
        align-items: center;
        justify-content: center;
        box-shadow: 0 1px 4px rgba(0,0,0,0.2);
      ">
        <svg viewBox="0 0 24 24" width="12" height="12" fill="white">
          ${svgPath || (iconType === 'start'
        ? '<path d="M8 5v14l11-7z"/>' // Play icon
        : '<path d="M6 6h12v12H6z"/>' // Stop icon
      )}
        </svg>
      </div>
    `,
    className: '',
    iconSize: [20, 20],
    iconAnchor: [10, 10]
  });
};

const startIcon = createMarkerIcon('#4CAF50', 'start'); // Green 500
const endIcon = createMarkerIcon('#F44336', 'end');   // Red 500

// 自动缩放组件
const FitBounds = ({ points }: { points: L.LatLngExpression[] }) => {
  const map = useMap();
  useEffect(() => {
    if (points.length > 0) {
      const bounds = L.latLngBounds(points);
      map.fitBounds(bounds, { padding: [50, 50], maxZoom: 16 });
    }
  }, [points, map]);
  return null;
};

// 焦点处理组件
const FocusHandler = ({ focusLocation }: { focusLocation?: { lat: number; lng: number; timestamp: number } | null }) => {
  const map = useMap();
  useEffect(() => {
    if (focusLocation && focusLocation.lat && focusLocation.lng) {
      map.flyTo([focusLocation.lat, focusLocation.lng], 18, {
        duration: 1.5,
        easeLinearity: 0.25
      });
    }
  }, [focusLocation, map]);
  return null;
};

const TripMapView: React.FC<TripMapViewProps> = ({
  trajectory,
  events = [],
  height = '100%',
  isLoading = false,
  focusLocation,
  showLoadButton = false,
  onLoadDetails
}) => {
  const { t } = useI18n();
  // 分段处理轨迹，逻辑参考 Native App
  const segments = useMemo(() => {
    if (!trajectory || !Array.isArray(trajectory) || trajectory.length === 0) return [];

    const result: Array<{ points: L.LatLngExpression[], isLowConf: boolean }> = [];
    let currentSegment: L.LatLngExpression[] = [];
    let currentIsLowConf = !!trajectory[0].low_conf;

    trajectory.forEach((p, i) => {
      const isLow = !!p.low_conf;
      const point: L.LatLngExpression = [p.lat, p.lng];

      if (isLow !== currentIsLowConf) {
        // 状态切换，保存当前段
        if (currentSegment.length >= 2) {
          result.push({ points: [...currentSegment], isLowConf: currentIsLowConf });
        }
        // 开始新的一段，为了线段连续，包含上一个点的终点
        currentSegment = [currentSegment.length > 0 ? currentSegment[currentSegment.length - 1] : point, point];
        currentIsLowConf = isLow;
      } else {
        currentSegment.push(point);
      }
    });

    // 添加最后一段
    if (currentSegment.length >= 2) {
      result.push({ points: currentSegment, isLowConf: currentIsLowConf });
    }

    return result;
  }, [trajectory]);

  // 用于计算边界和起终点的所有点
  const allPoints = useMemo(() => {
    return trajectory.map(p => [p.lat, p.lng] as L.LatLngExpression);
  }, [trajectory]);

  const startPoint = allPoints.length > 0 ? allPoints[0] : [31.2304, 121.4737] as L.LatLngExpression;
  const endPoint = allPoints.length > 1 ? allPoints[allPoints.length - 1] : null;

  return (
    <div style={{ height, width: '100%', borderRadius: 'inherit', overflow: 'hidden', position: 'relative', zIndex: 10 }}>
      {/* 地图容器 */}
      <MapContainer
        center={startPoint}
        zoom={allPoints.length > 0 ? 13 : 11}
        scrollWheelZoom={!showLoadButton} // 未加载时禁用滚轮缩放
        dragging={!showLoadButton} // 未加载时禁用拖拽
        style={{ height: '100%', width: '100%', background: '#F5F5F7' }}
        zoomControl={false}
        preferCanvas={true}
      >
        {/* 使用 CartoDB 瓦片，与 Native 保持一致 */}
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>'
          url="https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png"
        />

        {segments.map((segment, idx) => (
          <Polyline
            key={idx}
            positions={segment.points}
            pathOptions={{
              color: segment.isLowConf ? '#FF9500' : '#00E676',
              weight: 4,
              opacity: segment.isLowConf ? 0.5 : 0.8,
              dashArray: segment.isLowConf ? '5, 10' : undefined,
              lineJoin: 'round'
            }}
          />
        ))}

        {allPoints.length > 0 && (
          <>
            <Marker position={startPoint} icon={startIcon} />
            {endPoint && <Marker position={endPoint} icon={endIcon} />}

            {/* 事件标记 */}
            {events.map((event, idx) => {
              if (event.lat && event.lng) {
                const config = getEventConfig(event.type);
                return (
                  <Marker
                    key={`event-${idx}`}
                    position={[event.lat, event.lng]}
                    icon={createMarkerIcon(config.color, 'event', config.icon)}
                  />
                );
              }
              return null;
            })}

            <FitBounds points={allPoints} />
            <FocusHandler focusLocation={focusLocation} />
          </>
        )}
      </MapContainer>

      {/* 加载详情按钮遮罩层 - 覆盖在地图之上 */}
      {showLoadButton && !isLoading && (
        <div
          className="absolute inset-0 flex items-center justify-center"
          style={{
            backgroundColor: 'rgba(0, 0, 0, 0.1)',
            backdropFilter: 'blur(2px)',
            zIndex: 1000,
            pointerEvents: 'auto'
          }}
        >
          <div className="flex flex-col items-center gap-4">
            <button
              onClick={onLoadDetails}
              type="button"
              className="bg-[#007AFF] hover:bg-[#0051D5] text-white px-8 py-4 rounded-[1.5rem] text-sm font-black uppercase tracking-[0.15em] shadow-2xl active:scale-95 transition-all flex items-center gap-3"
              style={{
                boxShadow: '0 20px 25px -5px rgba(59, 130, 246, 0.3)',
                pointerEvents: 'auto',
                cursor: 'pointer'
              }}
            >
              <svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor" style={{ flexShrink: 0 }}>
                <path d="M19 12v7H5v-7H3v7c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2v-7h-2zm-6 .67l2.59-2.58L17 11.5l-5 5-5-5 1.41-1.41L11 12.67V3h2z" />
              </svg>
              <span>{t('load_trip_details')}</span>
            </button>
            <span className="text-[10px] font-bold text-gray-700 uppercase tracking-widest">
              {t('click_to_load_details')}
            </span>
          </div>
        </div>
      )}

      {/* 加载中状态 - 参考 Native 质感 */}
      {isLoading && (
        <div className="absolute inset-0 z-[1000] flex items-center justify-center bg-white/30 backdrop-blur-[4px]">
          <div className="flex flex-col items-center gap-3 bg-white/90 px-8 py-5 rounded-[2rem] shadow-2xl border border-white">
            <div className="w-8 h-8 border-4 border-[#007AFF]/20 border-t-[#007AFF] rounded-full animate-spin"></div>
            <span className="text-[10px] font-black text-[#1D1D1F] uppercase tracking-[0.2em] ml-1">{t('loading')}</span>
          </div>
        </div>
      )}

      {/* 当没有点且不在加载时，显示提示 */}
      {!isLoading && !showLoadButton && allPoints.length === 0 && (
        <div className="absolute inset-0 z-[20] flex items-center justify-center bg-gray-50/10 backdrop-blur-[2px] pointer-events-none">
          <div className="bg-white/90 px-6 py-3 rounded-2xl shadow-xl border border-gray-100 flex items-center gap-3">
            <div className="w-2 h-2 bg-amber-500 rounded-full animate-pulse"></div>
            <span className="text-[11px] font-black text-[#1D1D1F] uppercase tracking-widest">{t('no_trajectory')}</span>
          </div>
        </div>
      )}
    </div>
  );
};

export default TripMapView;

