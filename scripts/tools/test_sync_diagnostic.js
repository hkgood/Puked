import PocketBase from 'pocketbase';

const pb = new PocketBase('https://pb.osglab.com');

async function runTest() {
  try {
    console.log("--- Starting Remote Diagnostic ---");
    await pb.collection('_superusers').authWithPassword('rocky.hk@gmail.com', 'gz203799');
    console.log("Login successful as admin.");

    // 1. Check collection schemas
    console.log("\n1. Checking Collection Schemas...");
    const collections = await pb.collections.getFullList();
    const summaryColl = collections.find(c => c.name === 'trip_stats_summary');
    if (summaryColl) {
      console.log("Collection 'trip_stats_summary' found. Fields:");
      summaryColl.schema.forEach(f => {
        console.log(` - ${f.name} (${f.type})`);
      });
    } else {
      console.log("ERROR: Collection 'trip_stats_summary' NOT FOUND!");
    }

    // 2. Sample 10 trips
    console.log("\n2. Fetching sample trips...");
    const trips = await pb.collection('trips').getList(1, 10);
    console.log(`Fetched ${trips.items.length} trips.`);
    
    // 3. Try a dry-run write
    if (summaryColl && trips.items.length > 0) {
      console.log("\n3. Attempting a test write (Dry Run)...");
      const trip = trips.items[0];
      
      // Look for a real brand and version ID to avoid foreign key issues
      const brands = await pb.collection('brands').getList(1, 1);
      const versions = await pb.collection('software_versions').getList(1, 1);
      
      if (brands.items.length > 0 && versions.items.length > 0) {
        const testData = {
          user: pb.authStore.model.id,
          brand: brands.items[0].id,
          period_type: 'all',
          period_value: 'TEST_DRY_RUN',
          total_distance: 1.23,
          total_events: 5,
          avg_speed: 60.5
        };
        
        // Dynamically set the version field based on schema
        const versionField = summaryColl.schema.find(f => f.name === 'software_version' || f.name === 'version');
        if (versionField) {
          testData[versionField.name] = versions.items[0].id;
          console.log(`Using version field: ${versionField.name}`);
        } else {
          console.warn("No version field found in schema!");
        }

        try {
          const created = await pb.collection('trip_stats_summary').create(testData);
          console.log("SUCCESS: Dry run write completed. ID:", created.id);
          await pb.collection('trip_stats_summary').delete(created.id);
          console.log("SUCCESS: Dry run cleanup completed.");
        } catch (err) {
          console.error("FAILED: Test write failed.");
          console.error("Error Response:", JSON.stringify(err.response?.data || err, null, 2));
          console.log("Sent Data:", JSON.stringify(testData, null, 2));
        }
      }
    }

  } catch (err) {
    console.error("CRITICAL ERROR:", err.message);
  }
}

runTest();
