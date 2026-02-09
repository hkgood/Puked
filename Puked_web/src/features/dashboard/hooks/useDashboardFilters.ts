import { useState } from 'react';

export const useDashboardFilters = () => {
  const [tripFilter, setTripFilter] = useState<'all' | 'public' | 'pending'>('pending'); // 默认选择待审核
  const [userFilter, setUserFilter] = useState<any>('pending');
  const [tripSearchQuery, setTripSearchQuery] = useState('');
  const [userSearchQuery, setUserSearchQuery] = useState('');
  const [filterBrand, setFilterBrand] = useState('all');
  const [filterVersion, setFilterVersion] = useState('all');
  const [filterSpeedRange, setFilterSpeedRange] = useState('all');
  const [filterStartDate, setFilterStartDate] = useState('');
  const [filterEndDate, setFilterEndDate] = useState('');

  return {
    tripFilter, setTripFilter,
    userFilter, setUserFilter,
    tripSearchQuery, setTripSearchQuery,
    userSearchQuery, setUserSearchQuery,
    filterBrand, setFilterBrand,
    filterVersion, setFilterVersion,
    filterSpeedRange, setFilterSpeedRange,
    filterStartDate, setFilterStartDate,
    filterEndDate, setFilterEndDate
  };
};
