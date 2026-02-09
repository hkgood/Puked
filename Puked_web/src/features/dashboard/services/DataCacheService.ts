/**
 * DataCacheService - A generic caching utility for API response lists.
 * Uses localStorage for small metadata and list items.
 */

interface CacheEntry<T> {
  data: T[];
  timestamp: string; // Last updated timestamp from server
  expiresAt: number; // Local expiration time
}

class DataCacheService {
  private static PREFIX = 'puked_cache_';
  private static DEFAULT_TTL = 30 * 60 * 1000; // 30 minutes

  /**
   * Save data to cache
   */
  static set<T>(key: string, data: T[], serverTimestamp: string) {
    const entry: CacheEntry<T> = {
      data,
      timestamp: serverTimestamp,
      expiresAt: Date.now() + this.DEFAULT_TTL
    };
    localStorage.setItem(this.PREFIX + key, JSON.stringify(entry));
  }

  /**
   * Get data from cache
   */
  static get<T>(key: string): CacheEntry<T> | null {
    const raw = localStorage.getItem(this.PREFIX + key);
    if (!raw) return null;
    try {
      return JSON.parse(raw) as CacheEntry<T>;
    } catch (e) {
      return null;
    }
  }

  /**
   * Remove specific cache
   */
  static delete(key: string) {
    localStorage.removeItem(this.PREFIX + key);
  }

  /**
   * Clear all app caches
   */
  static clear() {
    Object.keys(localStorage)
      .filter(key => key.startsWith(this.PREFIX))
      .forEach(key => localStorage.removeItem(key));
  }
}

export default DataCacheService;
