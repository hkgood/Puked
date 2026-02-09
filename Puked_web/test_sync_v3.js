import PocketBase from 'pocketbase';
const pb = new PocketBase('https://pb.osglab.com');

async function test() {
  await pb.collection('_superusers').authWithPassword('rocky.hk@gmail.com', 'gz203799');
  
  const bList = await pb.collection('brands').getFullList();
  const vList = await pb.collection('software_versions').getFullList();
  const bMap = new Map(bList.map(b => [b.name.toLowerCase(), b.id]));
  const vMap = new Map(vList.map(v => [(v.versionString || v.version_name || '').toLowerCase(), v.id]));
  
  const othersB = bList.find(b => b.name.toLowerCase() === 'others')?.id || bList[0].id;
  const othersV = vList.find(v => (v.versionString || v.version_name || '').toLowerCase() === 'others')?.id || vList[0].id;

  const trips = await pb.collection('trips').getList(1, 10, { sort: '-created' });
  console.log(`Running final 10-trip test for ${trips.items.length} records...`);

  let ok = 0;
  for (const t of trips.items) {
    const brandId = bMap.get((t.brand || '').toLowerCase()) || othersB;
    const versionId = vMap.get((t.software_version || t.version || '').toLowerCase()) || othersV;
    const key = `${brandId}_${versionId}_all_TEST_${t.id}`;

    const data = {
      key,
      brand: brandId,
      software_version: versionId,
      period_type: 'all',
      period_value: 'TEST',
      total_distance: 1.0,
      total_events: 0
    };

    try {
      const res = await pb.collection('trip_stats_summary').create(data);
      ok++;
      await pb.collection('trip_stats_summary').delete(res.id);
    } catch (e) {
      console.error(`Failed for ${t.id}:`, e.response?.data || e.message);
    }
  }
  console.log(`Final Test Result: ${ok}/10 OK`);
}
test();
