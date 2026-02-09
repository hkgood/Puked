import { useState } from 'react';
import { TripService } from '../services/tripService';
import { UserService } from '../services/userService';
import { tripCacheService } from '../services/tripCacheService';
import { ScannerService } from '../../analyzer/services/scannerService';
import type { UserRecord } from '../../../models/types';

export const useDashboardActions = (refreshUsers: () => void, refreshTrips: () => void) => {
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isAuditing, setIsAuditing] = useState(false);
  const [auditResult, setAuditResult] = useState<any>(null);

  const handleApproveTrip = async (tripId: string) => {
    setIsSubmitting(true);
    try {
      await TripService.updateTrip(tripId, { is_public: true });
      refreshTrips();
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleApproveUser = async (user: UserRecord) => {
    setIsSubmitting(true);
    try {
      await UserService.approveUser(user);
      refreshUsers();
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleRejectUser = async (userId: string, reason: string) => {
    setIsSubmitting(true);
    try {
      await UserService.rejectUser(userId, reason);
      refreshUsers();
      return true;
    } catch (e) {
      console.error(e);
      return false;
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleDeleteTrip = async (tripId: string) => {
    setIsSubmitting(true);
    try {
      await TripService.deleteTrip(tripId);
      refreshTrips();
      return true;
    } catch (e) {
      console.error(e);
      return false;
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleForceRefresh = async (tripId: string) => {
    await tripCacheService.set(tripId, "0", null);
  };

  const handleUnpublishTrip = async (tripId: string) => {
    setIsSubmitting(true);
    try {
      await TripService.updateTrip(tripId, { is_public: false });
      refreshTrips();
      return true;
    } catch (e) {
      console.error(e);
      return false;
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleSingleAudit = async (tripData: any) => {
    setIsAuditing(true);
    try {
      const unreasonableEvents: Record<string, string> = {};
      const events = tripData?.events || [];

      for (const evt of events) {
        const result = await ScannerService.auditEvent(evt, tripData?.metadata?.start_time || '');
        if (result.isUnreasonable) {
          unreasonableEvents[evt.event_id] = result.reason || '不合理';
        }
      }

      setAuditResult({
        totalEvents: events.length,
        unreasonableCount: Object.keys(unreasonableEvents).length,
        unreasonableEvents
      });

      return unreasonableEvents;
    } catch (e) {
      console.error('[handleSingleAudit] Error:', e);
      return {};
    } finally {
      setIsAuditing(false);
    }
  };

  const handleUpdateUserSettings = async (userId: string, field: string, value: any) => {
    setIsSubmitting(true);
    try {
      const updatedUser = await UserService.updateUserSettings(userId, { [field]: value });
      refreshUsers();
      return updatedUser;
    } finally {
      setIsSubmitting(false);
    }
  };

  return {
    isSubmitting,
    isAuditing,
    auditResult,
    setAuditResult,
    handleApproveTrip,
    handleApproveUser,
    handleRejectUser,
    handleDeleteTrip,
    handleForceRefresh,
    handleUpdateUserSettings,
    handleUnpublishTrip,
    handleSingleAudit
  };
};
