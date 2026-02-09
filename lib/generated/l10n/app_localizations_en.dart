// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settings => 'Settings';

  @override
  String get preferences => 'Preferences';

  @override
  String get theme => 'Theme';

  @override
  String get themeAuto => 'AUTO';

  @override
  String get themeLight => 'LIGHT';

  @override
  String get themeDark => 'DARK';

  @override
  String get language => 'Language';

  @override
  String get chinese => 'Chinese';

  @override
  String get english => 'English';

  @override
  String get event_sound => 'Event Sound';

  @override
  String get event_sound_desc => 'Play sound when negative event detected';

  @override
  String get high_frame_rate => 'High Frame Rate Recording';

  @override
  String get high_frame_rate_desc =>
      'KOL Exclusive: Record 10Hz sensor data for more details';

  @override
  String get video_recording => 'Record Negative Event Videos (Beta)';

  @override
  String get video_recording_desc =>
      'Record 5-second video when negative events occur';

  @override
  String get camera_permission_needed => 'Camera permission needed';

  @override
  String get camera_init_failed => 'Failed to initialize camera';

  @override
  String get camera_preview_failed => 'Failed to get preview';

  @override
  String get camera_starting => 'Starting camera...';

  @override
  String get camera_preview_placeholder => 'Camera Preview Placeholder';

  @override
  String get camera_preview_hint =>
      'Preview requires native implementation\nVideo recording still works normally';

  @override
  String get current_version => 'Current Version';

  @override
  String get algorithm_version => 'Algorithm Version';

  @override
  String get check_update => 'Check for Update';

  @override
  String get privacy_policy => 'Privacy Policy';

  @override
  String get unknown => 'Unknown';

  @override
  String get user => 'User';

  @override
  String get logout => 'Logout';

  @override
  String get login => 'Login';

  @override
  String get login_to_sync => 'Login to sync data and share trips';

  @override
  String get model_hint => 'Enter model (e.g. Model 3)';

  @override
  String get version_hint => 'Enter version (e.g. v12.5)';

  @override
  String get verification_sent => 'Verification email sent';

  @override
  String get verification_success => 'Verification successful!';

  @override
  String get not_verified => 'Not verified (Tap to verify)';

  @override
  String get approved => 'Approved';

  @override
  String get pending => 'Pending';

  @override
  String get rejected => 'Rejected';

  @override
  String get unverified => 'Unverified';

  @override
  String get my_car => 'My Car';

  @override
  String get my_data_uploaded => 'My Data (Uploaded)';

  @override
  String get uploaded_mileage => 'Uploaded Mileage';

  @override
  String get mileage_contribution => 'Mileage Contribution';

  @override
  String get my_puked_rank => 'My PUKED Rank';

  @override
  String get my_puked_value => 'My PUKED Value';

  @override
  String get brand_distribution_desc => 'Dist.';

  @override
  String uploaded_mileage_val(Object value) {
    return '$value KM';
  }

  @override
  String mileage_contribution_val(Object value) {
    return '$value%';
  }

  @override
  String my_puked_rank_val(Object rank, Object total) {
    return 'Rank $rank / $total';
  }

  @override
  String my_puked_value_val(Object value) {
    return '$value km/Evt';
  }

  @override
  String get account_and_car => 'Account & Car';

  @override
  String get realtime_g => 'Real-time G';

  @override
  String get peak_g => 'Peak G';

  @override
  String get longitudinal => 'LONGITUDINAL';

  @override
  String get lateral => 'LATERAL';

  @override
  String get trip_summary => 'Trip Summary';

  @override
  String get total_events => 'Total Events';

  @override
  String get duration => 'Duration';

  @override
  String get distance => 'Distance';

  @override
  String get speed => 'Speed';

  @override
  String get avg_speed => 'Avg Speed';

  @override
  String get calibrate => 'Calibrate';

  @override
  String get recorded_msg => 'Recorded (Last 10s data)';

  @override
  String get no_trips => 'No trip records';

  @override
  String get exporting => 'Exporting data...';

  @override
  String get pro => 'Pro';

  @override
  String get submit_trip => 'Submit Trip';

  @override
  String get uploading => 'Uploading...';

  @override
  String get upload_success => 'Upload successful';

  @override
  String get upload_failed => 'Upload failed';

  @override
  String get neg_exp => 'Negative Exp.';

  @override
  String get gps_strong => 'Strong';

  @override
  String get gps_fair => 'Fair';

  @override
  String get gps_weak => 'Weak';

  @override
  String get gps_no_signal => 'No Signal';

  @override
  String get share_card => 'Share Card';

  @override
  String get trip_analysis => 'Trip Analysis';

  @override
  String get event_breakdown => 'Event Breakdown';

  @override
  String get trigger_sensitivity => 'Trigger Sensitivity';

  @override
  String get trigger_duration => 'Trigger Duration';

  @override
  String get false_positive_suppression => 'False Positive Suppression';

  @override
  String get download => 'Download';

  @override
  String get downloading => 'Syncing & Downloading...';

  @override
  String get download_success => 'Sync download successful';

  @override
  String get download_failed => 'Sync download failed';

  @override
  String get cloud_trip => 'Cloud Trip';

  @override
  String get pulling_cloud_trips => 'Fetching cloud records...';

  @override
  String cloud_sync_result(Object count) {
    return 'Sync complete, found $count new trips';
  }

  @override
  String get select_version => 'Select Version';

  @override
  String get custom_version_input => 'Manual Input';

  @override
  String get confirm => 'Confirm';

  @override
  String get cancel => 'Cancel';

  @override
  String get ok => 'OK';

  @override
  String get edit => 'Edit';

  @override
  String get save => 'Save';

  @override
  String get skip => 'Skip';

  @override
  String get software_version => 'Software Version';

  @override
  String get car_model => 'Car Model';

  @override
  String get vehicle_info => 'Vehicle Info';

  @override
  String get modify_vehicle_info => 'Modify Vehicle Info';

  @override
  String get arena_top10_title => 'Comfort Top10';

  @override
  String get weekly_comfort_ranking => 'Weekly Comfort Ranking';

  @override
  String get weekly_comfort_desc => 'Best comfort by scenario this week';

  @override
  String get weekly_mileage_ranking => 'Weekly Mileage Ranking';

  @override
  String get weekly_mileage_desc => 'Total mileage recorded this week';

  @override
  String get arena_total_mileage_title => 'Mileage by Brand';

  @override
  String get arena_total_mileage_subtitle => 'Total mileage recorded per brand';

  @override
  String arena_brand_evolution_title(Object brand) {
    return '$brand Evolution';
  }

  @override
  String get arena_details_title => 'Neg Events Breakdown';

  @override
  String get arena_leaderboard_title => 'Mileage Contributors';

  @override
  String get low_speed_ranking => 'Urban Comfort';

  @override
  String get high_speed_ranking => 'Highway Comfort';

  @override
  String get low_speed_desc =>
      'Events for trips < 50 km/h, km/evt, total mileage > 300';

  @override
  String get high_speed_desc =>
      'Events for trips >= 50 km/h, km/evt, total mileage > 300';

  @override
  String get city => 'Urban';

  @override
  String get highway => 'Highway';

  @override
  String get weekly_rank => 'Weekly';

  @override
  String get total_rank => 'Total';

  @override
  String get user_mileage_unit => 'km';

  @override
  String get km_per_event => 'km/Event';

  @override
  String get km_per_event_long =>
      'Km between negative experiences, total mileage > 300';

  @override
  String get km_per_version_event_long =>
      'Average km per negative experience by version';

  @override
  String get by_brand => 'By Brand';

  @override
  String get by_version => 'By Version';

  @override
  String get all_versions => 'All Versions';

  @override
  String get select_brand => 'Select Brand';

  @override
  String get mileage_label => 'Mileage';

  @override
  String trips_count(Object count) {
    return '$count Trips';
  }

  @override
  String events_count(Object count) {
    return '$count Events';
  }

  @override
  String get app_name => 'Puked';

  @override
  String get history => 'History';

  @override
  String get arena => 'Arena';

  @override
  String get start_trip => 'START TRIP';

  @override
  String get stop_trip => 'LONG PRESS TO STOP';

  @override
  String get calibrating => 'Calibrating...';

  @override
  String get calibrated => 'Calibrated!';

  @override
  String get calibration_failed => 'Calibration Failed';

  @override
  String get calibration_failed_desc =>
      'Please ensure the vehicle and phone are stationary.';

  @override
  String get rapid_accel => 'Rapid Accel';

  @override
  String get rapid_decel => 'Rapid Decel';

  @override
  String get jerk => 'Jerk';

  @override
  String get rapidAcceleration => 'Rapid Acceleration';

  @override
  String get rapidDeceleration => 'Rapid Deceleration';

  @override
  String get jerk_event => 'Jerk';

  @override
  String get bump => 'Bump';

  @override
  String get wobble => 'Wobble';

  @override
  String get manual => 'Manual Mark';

  @override
  String get calibration_tip => 'Keep the phone stable for vehicle alignment';

  @override
  String get no_data_for_brand => 'No Data';

  @override
  String connected_as(Object name) {
    return 'Connected as: $name';
  }

  @override
  String get car_cert_banner => 'Verify your car to enable trip uploads';

  @override
  String get upload_cert_photos => 'Car Certification';

  @override
  String get upload_hint =>
      'Please upload a photo showing your car model and VIN';

  @override
  String get file_limit_hint => 'Up to 3 photos (JPG/PNG, < 5MB each)';

  @override
  String get submit_for_audit => 'Submit for Verification';

  @override
  String get submit_success_tip => 'Verification details submitted!';

  @override
  String get error_image_limit => 'Please select up to 3 photos.';

  @override
  String get error_image_size => 'Each photo must be under 5MB.';

  @override
  String get error_image_type => 'Only JPG and PNG photos are supported.';

  @override
  String get delete_event_title => 'Confirm Delete Event';

  @override
  String get delete_event_desc =>
      'Deleted events cannot be recovered. Are you sure?';

  @override
  String agree_privacy_link(Object policy) {
    return 'I agree to $policy';
  }

  @override
  String get onboarding_step1 =>
      'Mount your phone, aligned with the car\'s direction';

  @override
  String get onboarding_step2 =>
      'Stay still, tap \'Start Trip\' to calibrate sensors';

  @override
  String get onboarding_step3 => 'Start testing, avoid picking up your phone';

  @override
  String get onboarding_step4 =>
      'Stop vehicle, long press \'Long Press to Stop\' button (0.8s) before picking up';

  @override
  String get onboarding_step5 => 'Share your trip and data with others';

  @override
  String get onboarding_start => 'Start Experience';

  @override
  String get onboarding_welcome => 'Welcome to Puked';

  @override
  String get saving_image => 'Saving as image...';

  @override
  String get save_success => 'Image saved to gallery';

  @override
  String get save_failed => 'Failed to save image';

  @override
  String get error_no_photo_permission =>
      'Please grant photo gallery permission';

  @override
  String algorithm_update_success(Object version) {
    return 'Algorithm synced (v$version)';
  }

  @override
  String get algorithm_update_failed => 'Failed to sync parameters';

  @override
  String get algorithm_settings_title => 'Online Algorithm Settings';

  @override
  String get algorithm_updated_at => 'Last Updated';

  @override
  String get threshold_accel_label => 'Accel Threshold';

  @override
  String get threshold_decel_label => 'Decel Threshold';

  @override
  String get threshold_wobble_span_label => 'Wobble Span';

  @override
  String get threshold_bump_label => 'Bump Threshold';

  @override
  String get threshold_jerk_label => 'Jerk Threshold';

  @override
  String get threshold_pitch_label => 'Pitch Threshold';

  @override
  String get jerk_window_ms_label => 'Jerk Window';

  @override
  String get accel_decel_window_ms_label => 'Accel/Decel Window';

  @override
  String get wobble_window_ms_label => 'Wobble Window';

  @override
  String get fusion_window_ms_label => 'Fusion Window';

  @override
  String get zy_interference_threshold_label => 'Z-Y Interference';

  @override
  String get zx_interference_threshold_label => 'Z-X Interference';

  @override
  String get pitch_validation_enabled_label => 'Pitch Protection';

  @override
  String get speed_low_factor_label => 'Low Speed Factor';

  @override
  String get speed_high_factor_label => 'High Speed Factor';

  @override
  String get max_jerk_allowed_label => 'Max Jerk Limit';

  @override
  String get max_accel_allowed_label => 'Max Accel Limit';

  @override
  String get max_wobble_span_allowed_label => 'Max Wobble Limit';

  @override
  String get max_bump_allowed_label => 'Max Bump Limit';

  @override
  String get min_accel_for_jerk_label => 'Jerk Min Accel';

  @override
  String get threshold_accel_hint =>
      'Min acceleration to trigger \'Rapid Acceleration\'';

  @override
  String get threshold_decel_hint =>
      'Min deceleration to trigger \'Rapid Deceleration\'';

  @override
  String get threshold_wobble_span_hint =>
      'Min lateral span to trigger \'Wobble\'';

  @override
  String get threshold_bump_hint => 'Min vertical G to trigger \'Bump\'';

  @override
  String get threshold_jerk_hint => 'Min change rate to trigger \'Jerk\'';

  @override
  String get threshold_pitch_hint =>
      'Min angular velocity to trigger \'Pitching\'';

  @override
  String get jerk_window_ms_hint => 'Time window for calculating Jerk rate';

  @override
  String get accel_decel_window_ms_hint =>
      'Min continuous time for Accel/Decel';

  @override
  String get wobble_window_ms_hint =>
      'Time window for detecting lateral swings';

  @override
  String get fusion_window_ms_hint => 'Wait time for merging multiple features';

  @override
  String get max_jerk_allowed_hint =>
      'Max jerk limit to filter out device drops';

  @override
  String get max_accel_allowed_hint =>
      'Max accel limit to filter out non-driving noise';

  @override
  String get max_wobble_span_allowed_hint =>
      'Max wobble limit to filter out device handling';

  @override
  String get max_bump_allowed_hint =>
      'Max bump limit to filter out non-road impacts';

  @override
  String get min_accel_for_jerk_hint =>
      'Only calculate jerk if acceleration exceeds this';

  @override
  String get zy_interference_threshold_hint =>
      'Z-axis activity level to suppress Y-axis';

  @override
  String get zx_interference_threshold_hint =>
      'Z-axis activity level to suppress X-axis';

  @override
  String get pitch_validation_enabled_hint =>
      'Use gyroscope to verify car\'s pitching';

  @override
  String get speed_low_factor_hint =>
      'Sensitivity factor at low speeds (<10km/h)';

  @override
  String get speed_high_factor_hint =>
      'Sensitivity factor at high speeds (>80km/h)';

  @override
  String get sync_now => 'Sync Now';

  @override
  String get error_invalid_credentials => 'Invalid email or password';

  @override
  String get login_failed => 'Login failed';

  @override
  String get forgot_password => 'Forgot Password';

  @override
  String get reset_email_sent => 'Reset email sent';

  @override
  String get password => 'Password';

  @override
  String get no_account => 'No account? Register now';

  @override
  String get error_email_taken => 'Email already taken';

  @override
  String get error_password_too_short => 'Password too short (min 8)';

  @override
  String get register_failed => 'Register failed';

  @override
  String get register => 'Register';

  @override
  String get name => 'Name';

  @override
  String get has_account => 'Already have an account? Login';

  @override
  String get about => 'About';

  @override
  String get delete_trips => 'Delete Trips';

  @override
  String delete_trips_confirm(Object count) {
    return 'Are you sure you want to delete these $count trips?';
  }

  @override
  String get delete => 'Delete';

  @override
  String get select_items => 'Select Items';

  @override
  String get sync_cloud_status => 'Sync Status';

  @override
  String bulk_upload_confirm(Object count) {
    return 'Are you sure you want to upload these $count trips?';
  }

  @override
  String get upload => 'Upload';

  @override
  String get insufficient_data_title => 'Insufficient Data';

  @override
  String get insufficient_data_message =>
      'Some trips have insufficient data (mileage too short). We suggest driving further before submitting.';

  @override
  String get syncing => 'Syncing...';

  @override
  String get no_trips_yet => 'No History Trips';

  @override
  String get submit_trip_confirm =>
      'Are you sure you want to submit this trip to the Arena?';

  @override
  String get car_cert_banner_approved => 'Car Verified';

  @override
  String get car_cert_banner_pending => 'Car Verifying';

  @override
  String get car_cert_banner_rejected => 'Car Verification Rejected';

  @override
  String get upload_cert_photos_new => 'Re-upload Certification';

  @override
  String get upload_cert_photos_submitted => 'Certification Submitted';

  @override
  String get upload_hint_new =>
      'Please re-upload photos showing your license plate or VIN';

  @override
  String get event_list => 'Event Details';

  @override
  String get event_statistics => 'Event Details';

  @override
  String get auto_negative_events => 'Auto-Detected';

  @override
  String get manual_marked_events => 'Manual Marks';

  @override
  String total_count(Object value) {
    return '$value Total';
  }

  @override
  String get min => 'min';

  @override
  String get value => 'Value';

  @override
  String get app_tagline => 'Quantifying AD Comfort';

  @override
  String get algo_a => 'ALGO A';

  @override
  String get algo_b => 'ALGO B';

  @override
  String get sensor_frozen => 'SENSOR FROZEN';

  @override
  String get ins_active => 'INS ACTIVE';

  @override
  String get fetching_arena_data => 'Fetching Arena Data...';

  @override
  String get no_records => 'No Records';

  @override
  String get arena_mileage_requirement =>
      'Ranking brand mileage must be greater than 300 km';

  @override
  String get share_failed => 'Share failed';

  @override
  String get retry => 'Retry';

  @override
  String get avatar_updated => 'Avatar updated';

  @override
  String get passwords_not_match => 'Passwords do not match';

  @override
  String get required => 'Required';

  @override
  String get email => 'Email';

  @override
  String get invalid_email => 'Invalid email format';

  @override
  String get password_too_short_hint =>
      'Password must be at least 8 characters';

  @override
  String get repeat_password => 'Repeat password';

  @override
  String get crop_avatar => 'Crop Avatar';

  @override
  String get update_avatar_failed => 'Failed to update avatar';

  @override
  String get delete_account => 'Destroy Account';

  @override
  String get new_version_found => 'New Version Found';

  @override
  String get changelog => 'Changelog';

  @override
  String get update_now => 'Update Now';

  @override
  String get downloading_update => 'Downloading Update';

  @override
  String get permission_not_granted => 'Permission not granted';

  @override
  String get network_error => 'Network error';

  @override
  String get calibration_failed_stationary =>
      'Calibration failed: Please ensure the vehicle is stationary';

  @override
  String get calibration_failed_motion =>
      'Calibration failed: Please keep the phone still';

  @override
  String get sensor_error => 'Sensor reading error';

  @override
  String get recording_notification_content => 'Puked is recording your trip';

  @override
  String get recording_notification_title => 'Recording in Progress';

  @override
  String get logic_section => 'Core Logic';

  @override
  String get please_login_first => 'Please login first';

  @override
  String get network_unavailable =>
      'Network unavailable, please check settings';

  @override
  String get uploading_trip => 'Uploading trip...';

  @override
  String get trip_submitted_success => 'Trip submitted to Arena successfully';

  @override
  String get image_upload_success => 'Image uploaded successfully';

  @override
  String get network_restored => 'Network connection restored';

  @override
  String get calibration_success_start =>
      'Calibration successful, recording started';

  @override
  String get select_or_input_version => 'Please select or enter version';

  @override
  String get confirm_delete_account =>
      'Are you sure you want to destroy your account?';

  @override
  String get exit_app => 'Exit App';

  @override
  String get exit_app_confirm => 'Are you sure you want to exit Puked?';

  @override
  String get ignore_this_version => 'Ignore this version';

  @override
  String get recalibrate => 'Recalibrate';

  @override
  String get invalid_verification_code =>
      'Invalid verification code, please check email';

  @override
  String speed_unit(Object value) {
    return '$value km/h';
  }

  @override
  String g_unit(Object value) {
    return '$value G';
  }

  @override
  String distance_unit(Object value) {
    return '$value km';
  }

  @override
  String duration_unit(Object value) {
    return '$value min';
  }

  @override
  String get update_failed => 'Update failed';

  @override
  String get processing => 'Processing...';

  @override
  String get later => 'Later';

  @override
  String get back => 'Back';

  @override
  String get ensure_network_tip =>
      'Please ensure network connection and try again';

  @override
  String get invalid_email_format => 'Invalid email format';

  @override
  String get password_too_short => 'Password must be at least 8 characters';

  @override
  String get field_required => 'This field is required';

  @override
  String get coupling_curve_index_label => 'Suppression Curve Index';

  @override
  String get coupling_curve_index_hint =>
      'Controls the non-linearity of Z-axis suppression (1.0 is linear)';

  @override
  String get coupling_strength_y_label => 'Longitudinal Strength (Y)';

  @override
  String get coupling_strength_y_hint =>
      'Weight of Z-axis activity suppressing Accel/Decel detection';

  @override
  String get coupling_strength_x_label => 'Lateral Strength (X)';

  @override
  String get coupling_strength_x_hint =>
      'Weight of Z-axis activity suppressing Jerk/Wobble detection';

  @override
  String get turn_comp_multiplier_label => 'Turn Comp Multiplier';

  @override
  String get turn_comp_multiplier_hint =>
      'Multiplier for raising decel threshold based on yaw rate';

  @override
  String get turn_comp_max_label => 'Turn Comp Max';

  @override
  String get turn_comp_max_hint =>
      'Maximum ceiling for threshold adjustment during turns';

  @override
  String get event_window_coverage_label => 'Window Coverage Rate';

  @override
  String get event_window_coverage_hint =>
      'Required percentage of points exceeding threshold within window';

  @override
  String get low_speed_jerk_limit_label => 'Low Speed Jerk Limit';

  @override
  String get low_speed_jerk_limit_hint =>
      'Speed (km/h) below which deceleration is downgraded to Jerk';

  @override
  String get trend_filter_section => 'Trend Filter';

  @override
  String get enable_trend_filter_label => 'Enable Trend Filter';

  @override
  String get enable_trend_filter_hint =>
      'Filter out gentle decel/accel events before detection (recommended)';

  @override
  String get trend_change_threshold_label => 'Trend Change Threshold';

  @override
  String get trend_change_threshold_hint =>
      'Min threshold for accel difference between first/second half';

  @override
  String get min_std_dev_threshold_label => 'Std Dev Threshold (Backup)';

  @override
  String get min_std_dev_threshold_hint =>
      'Min Y-axis acceleration standard deviation (auxiliary metric)';

  @override
  String get min_range_threshold_label => 'Range Threshold (Backup)';

  @override
  String get min_range_threshold_hint =>
      'Min Y-axis acceleration range (auxiliary metric)';

  @override
  String get recording_voice => 'Recording...';

  @override
  String get pro_on => 'VOICE ON';

  @override
  String get pro_off => 'VOICE OFF';

  @override
  String get voice_tutorial_title => 'Voice Recording Guide';

  @override
  String get voice_tutorial_step1 =>
      '1. Turn on \'VOICE ON\' and wait for model download';

  @override
  String get voice_tutorial_step2 =>
      '2. Start trip and keep phone still for calibration';

  @override
  String get voice_tutorial_step3 =>
      '3. Long-press map or use Bluetooth play key to record';

  @override
  String get voice_tutorial_step4 =>
      '4. View supported events in Voice Recording settings';

  @override
  String get got_it => 'Got it';

  @override
  String get voice_engine_config_failed => 'Voice Engine Config Failed';

  @override
  String get voice_engine_not_ready =>
      'Voice engine not ready, please wait for download';

  @override
  String get recording_active_debug => 'Recording Active';

  @override
  String get gps_signal_lost => 'GPS Signal Lost';

  @override
  String get ins_active_display => 'INS Active (Display Only)';

  @override
  String get trip_report_title => 'Trip Report';

  @override
  String share_msg_body(Object time) {
    return 'Puked Trip Report: $time';
  }

  @override
  String get pts_unit => 'pts';

  @override
  String get fail => 'FAIL';

  @override
  String get error => 'Error';

  @override
  String get proDisengagement => 'Disengagement';

  @override
  String get proViolation => 'Violation';

  @override
  String get proExperience => 'Experience';

  @override
  String get voice_recording => 'Voice Recording';

  @override
  String get voice_recording_desc => 'View events that support voice recording';

  @override
  String get voice_recording_title => 'Voice Recording Details';

  @override
  String get voice_recording_intro =>
      'The following ADAS events support voice descriptions by long-pressing the \'Record\' button when triggered during a trip:';

  @override
  String get voice_recording_manual_desc =>
      'Long-press the record button at any time to record a manual voice note for reporting current status or road conditions.';

  @override
  String get edit_event => 'Edit Event';

  @override
  String get event_type => 'Event Type';

  @override
  String get event_description => 'Description';

  @override
  String get save_changes => 'Save Changes';

  @override
  String get selecting_best_mirror => 'Selecting fastest mirror...';
}
