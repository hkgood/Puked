/**
 * TripCacheService - Handles local caching of trip JSON data using IndexedDB.
 * Since trip JSON files can be several MBs, IndexedDB is used instead of localStorage.
 */

const DB_NAME = 'PukedTripCache';
const STORE_NAME = 'trips';
const DB_VERSION = 1;

export interface CachedTrip {
  id: string;
  updated: string; // The 'updated' timestamp from PocketBase
  content: any;    // The full JSON content of the trip
}

class TripCacheService {
  private db: IDBDatabase | null = null;

  private async getDB(): Promise<IDBDatabase> {
    if (this.db) return this.db;

    return new Promise((resolve, reject) => {
      const request = indexedDB.open(DB_NAME, DB_VERSION);

      request.onupgradeneeded = (event) => {
        const db = (event.target as IDBOpenDBRequest).result;
        if (!db.objectStoreNames.contains(STORE_NAME)) {
          db.createObjectStore(STORE_NAME, { keyPath: 'id' });
        }
      };

      request.onsuccess = (event) => {
        this.db = (event.target as IDBOpenDBRequest).result;
        resolve(this.db);
      };

      request.onerror = (event) => {
        reject((event.target as IDBOpenDBRequest).error);
      };
    });
  }

  /**
   * Get cached trip data if it matches the remote version
   * @param id Trip ID
   * @param remoteUpdated The 'updated' timestamp from the remote record
   */
  async get(id: string, remoteUpdated: string): Promise<any | null> {
    try {
      const db = await this.getDB();
      return new Promise((resolve) => {
        const transaction = db.transaction(STORE_NAME, 'readonly');
        const store = transaction.objectStore(STORE_NAME);
        const request = store.get(id);

        request.onsuccess = () => {
          const result = request.result as CachedTrip | undefined;
          if (result && result.updated === remoteUpdated) {
            console.log(`[Cache] Hit for trip ${id}`);
            resolve(result.content);
          } else {
            console.log(`[Cache] Miss or outdated for trip ${id}`);
            resolve(null);
          }
        };

        request.onerror = () => {
          resolve(null);
        };
      });
    } catch (e) {
      console.error('[Cache] Error reading from IndexedDB:', e);
      return null;
    }
  }

  /**
   * Save trip data to cache
   */
  async set(id: string, updated: string, content: any): Promise<void> {
    try {
      const db = await this.getDB();
      return new Promise((resolve, reject) => {
        const transaction = db.transaction(STORE_NAME, 'readwrite');
        const store = transaction.objectStore(STORE_NAME);
        const item: CachedTrip = { id, updated, content };
        const request = store.put(item);

        request.onsuccess = () => {
          console.log(`[Cache] Saved trip ${id}`);
          resolve();
        };

        request.onerror = (event) => {
          reject((event.target as IDBRequest).error);
        };
      });
    } catch (e) {
      console.error('[Cache] Error writing to IndexedDB:', e);
    }
  }

  /**
   * Remove a trip from cache
   */
  async delete(id: string): Promise<void> {
    try {
      const db = await this.getDB();
      return new Promise((resolve, reject) => {
        const transaction = db.transaction(STORE_NAME, 'readwrite');
        const store = transaction.objectStore(STORE_NAME);
        const request = store.delete(id);

        request.onsuccess = () => resolve();
        request.onerror = () => reject(request.error);
      });
    } catch (e) {
      console.error('[Cache] Error deleting from IndexedDB:', e);
    }
  }

  /**
   * Clear all cached trips
   */
  async clear(): Promise<void> {
    try {
      const db = await this.getDB();
      return new Promise((resolve, reject) => {
        const transaction = db.transaction(STORE_NAME, 'readwrite');
        const store = transaction.objectStore(STORE_NAME);
        const request = store.clear();

        request.onsuccess = () => resolve();
        request.onerror = () => reject(request.error);
      });
    } catch (e) {
      console.error('[Cache] Error clearing IndexedDB:', e);
    }
  }
}

export const tripCacheService = new TripCacheService();

