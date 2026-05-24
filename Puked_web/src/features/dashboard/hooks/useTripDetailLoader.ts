import { useState, useEffect, useCallback } from 'react';
import { tripCacheService } from '../services/tripCacheService';
import { getFileUrl } from '../../../services/pocketbase';
import { ScannerService, type SupplementalEvent } from '../../analyzer/services/scannerService';
import { getEvents } from '../utils/tripDataUtils';

/**
 * 专门用于加载行程全量 JSON 数据及缺失事件扫描的 Hook
 * @param selectedTrip 选中的行程
 * @param autoLoad 是否自动加载（默认 false，需要手动触发）
 */
export const useTripDetailLoader = (selectedTrip: any, autoLoad = false) => {
  const [fullTripData, setFullTripData] = useState<any | null>(null);
  const [loadedTripId, setLoadedTripId] = useState<string | null>(null);
  const [isDataLoading, setIsDataLoading] = useState(false);
  const [loadingProgress, setLoadingProgress] = useState(0);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [supplementalEvents, setSupplementalEvents] = useState<SupplementalEvent[]>([]);

  // 🔥 P1-1 修复：添加 AbortController + useRef 跟踪当前请求，避免竞态
  const abortControllerRef = useRef<AbortController | null>(null);
  const currentTripIdRef = useRef<string | null>(null);

  const fetchFullData = useCallback(async () => {
    const dataFile = selectedTrip?.raw_log_file || selectedTrip?.data_file;

    if (!selectedTrip || !dataFile) {
      setFullTripData(null);
      setLoadedTripId(null);
      setLoadError(null);
      setLoadingProgress(0);
      setSupplementalEvents([]);
      return;
    }

    // 🔥 如果是同一个行程且已经加载，直接返回
    if (loadedTripId === selectedTrip.id && fullTripData) return;

    // 🔥 切换到新行程时，取消上一个请求（防止竞态）
    if (abortControllerRef.current) {
      abortControllerRef.current.abort();
    }
    const controller = new AbortController();
    abortControllerRef.current = controller;
    currentTripIdRef.current = selectedTrip.id;

    // 切换到新行程时，清空旧的详情数据
    if (loadedTripId !== selectedTrip.id) {
      setFullTripData(null);
      setLoadedTripId(null);
      setSupplementalEvents([]);
      setLoadingProgress(0);
    }

    // 1. 尝试从缓存读取
    let tripData = await tripCacheService.get(selectedTrip.id, selectedTrip.updated);

    if (tripData && tripData.events && tripData.trajectory) {
      setFullTripData(tripData);
      setLoadedTripId(selectedTrip.id);
      setLoadingProgress(100);
      setIsDataLoading(false);
    } else {
      setIsDataLoading(true);
      if (tripData) await tripCacheService.set(selectedTrip.id, "0", null);
      tripData = null;
    }

    setLoadError(null);
    setLoadingProgress(0);

    try {
      if (!tripData) {
        let fileUrl = getFileUrl(selectedTrip, dataFile);
        if (!fileUrl) throw new Error('File URL not found');

        const finalUrl = `${fileUrl}${fileUrl.includes('?') ? '&' : '?'}_nocache=${Math.random().toString(36).substring(7)}`;
        const response = await fetch(finalUrl, { cache: 'no-store', mode: 'cors', signal: controller.signal });

        if (!response.ok) throw new Error(`HTTP Error: ${response.status}`);

        const contentLength = response.headers.get('content-length');
        const total = contentLength ? parseInt(contentLength, 10) : 0;
        const reader = response.body?.getReader();
        if (!reader) throw new Error('ReadableStream not supported');

        let loaded = 0;
        const chunks = [];
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          // 🔥 每次 chunk 后检查是否已切换行程（竞态检测）
          if (currentTripIdRef.current !== selectedTrip.id) {
            reader.cancel();
            return;
          }
          chunks.push(value);
          loaded += value.length;
          if (total) setLoadingProgress(Math.round((loaded / total) * 100));
        }

        const allChunks = new Uint8Array(loaded);
        let position = 0;
        for (const chunk of chunks) {
          allChunks.set(chunk, position);
          position += chunk.length;
        }

        const decodedStr = new TextDecoder("utf-8").decode(allChunks);
        if (!decodedStr.trim()) throw new Error('EMPTY_DATA');

        tripData = JSON.parse(decodedStr);
        await tripCacheService.set(selectedTrip.id, selectedTrip.updated, tripData);
      }

      // 🔥 再次检查是否已切换行程（JSON parse 后也要检查）
      if (currentTripIdRef.current !== selectedTrip.id) return;

      if (tripData) {
        setFullTripData(tripData);
        setLoadedTripId(selectedTrip.id);
        setLoadingProgress(100);
        setIsDataLoading(false);

        const missing = await ScannerService.scanForMissingEvents(tripData);
        const existingEvents = getEvents(selectedTrip);
        const filteredMissing = missing.filter(m =>
          !existingEvents.some((e: any) => Math.abs(e.timestamp - m.timestamp) < 0.5)
        );
        setSupplementalEvents(filteredMissing);
      }
    } catch (err: any) {
      // 忽略主动取消的错误
      if (err.name === 'AbortError' || err.message === 'canceled') return;
      console.error('[useTripDetailLoader] Error:', err);
      setLoadError(err.message);
      setIsDataLoading(false);
    }
  }, [selectedTrip, loadedTripId, fullTripData]);

  useEffect(() => {
    // 当切换行程时，总是清空旧的详情数据
    if (selectedTrip && loadedTripId !== selectedTrip.id) {
      setFullTripData(null);
      setLoadedTripId(null);
      setSupplementalEvents([]);
      setLoadingProgress(0);
      setLoadError(null);
    }

    // 仅在 autoLoad 为 true 时自动加载新数据
    if (autoLoad) {
      fetchFullData();
    }
  }, [selectedTrip, autoLoad, loadedTripId, fetchFullData]);

  // 手动触发加载的方法
  const loadTripDetails = useCallback(() => {
    fetchFullData();
  }, [fetchFullData]);

  return {
    fullTripData,
    loadedTripId,
    isDataLoading,
    loadingProgress,
    loadError,
    supplementalEvents,
    loadTripDetails // 暴露手动加载方法
  };
};
