// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Puked';

  @override
  String get settings => 'Settings';

  @override
  String get history => 'History';

  @override
  String get arena => 'Arena';

  @override
  String get language => 'Language';

  @override
  String get theme => 'Theme';

  @override
  String get themeAuto => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get chinese => 'Chinese';

  @override
  String get english => 'English';

  @override
  String get sensitivity => 'Auto-tagging Sensitivity';

  @override
  String get sensitivityLow => 'Low';

  @override
  String get sensitivityMedium => 'Medium (Sensitive)';

  @override
  String get sensitivityHigh => 'High (Most Sensitive - Default)';

  @override
  String get sensitivityLowDesc => 'Accel > 3.0m/s², Brake > 3.5m/s²';

  @override
  String get sensitivityMediumDesc => 'Accel > 2.4m/s², Brake > 2.8m/s²';

  @override
  String get sensitivityHighDesc => 'Accel > 1.8m/s², Brake > 2.1m/s²';

  @override
  String get sensitivityTip =>
      'Higher sensitivity means lower acceleration thresholds for auto-tagging events.';

  @override
  String get rapidAcceleration => 'Rapid Acceleration';

  @override
  String get rapidDeceleration => 'Rapid Deceleration';

  @override
  String get jerk => 'Jerk';

  @override
  String get bump => 'Bump';

  @override
  String get wobble => 'Wobble';

  @override
  String get start_trip => 'START TRIP';

  @override
  String get stop_trip => 'STOP TRIP';

  @override
  String get calibrating => 'Calibrating...';

  @override
  String get calibration_tip => 'Keep the phone stable for vehicle alignment';

  @override
  String get edit => 'Edit';

  @override
  String get modify_vehicle_info => 'Modify Vehicle Info';

  @override
  String get vehicle_info => 'Vehicle Info';

  @override
  String get car_model => 'Car Model';

  @override
  String get software_version => 'Software Version';

  @override
  String get model_hint => 'Enter model (e.g. Model 3)';

  @override
  String get version_hint => 'Enter version (e.g. v12.5)';

  @override
  String get skip => 'Skip';

  @override
  String get save => 'Save';

  @override
  String get about => 'About';

  @override
  String get current_version => 'Current Version';

  @override
  String get check_update => 'Check for Update';

  @override
  String get account => 'Account';

  @override
  String get login => 'Login';

  @override
  String get logout => 'Logout';

  @override
  String get sync_data => 'Sync Data';

  @override
  String get login_to_sync => 'Login to sync data and share trips';

  @override
  String connected_as(Object name) {
    return 'Connected as: $name';
  }

  @override
  String get brand => 'My ADAS';

  @override
  String get my_car => 'My Car';

  @override
  String get password => 'Password';

  @override
  String get name => 'Nickname';

  @override
  String get register => 'Register';

  @override
  String get no_account => 'Don\'t have an account? Register';

  @override
  String get has_account => 'Already have an account? Login';

  @override
  String get login_failed => 'Login failed';

  @override
  String get register_failed => 'Registration failed';

  @override
  String get forgot_password => 'Forgot Password?';

  @override
  String get reset_email_sent => 'Reset email sent, please check your inbox';

  @override
  String get verify_email => 'Verify Email';

  @override
  String get verification_sent => 'Verification email sent';

  @override
  String get not_verified => 'Not verified (Tap to verify)';

  @override
  String get error_email_taken => 'Email already registered';

  @override
  String get error_invalid_credentials => 'Invalid email or password';

  @override
  String get error_password_too_short =>
      'Password must be at least 8 characters';

  @override
  String get verification_success => 'Verification successful!';

  @override
  String get syncing => 'Syncing cloud status...';

  @override
  String sync_complete(Object count) {
    return 'Sync complete, marked $count trips';
  }

  @override
  String get no_cloud_records => 'No matching cloud records found';

  @override
  String get sync_cloud_status => 'Sync upload status';

  @override
  String get arena_top10_title => 'Safe Driving Top 10';

  @override
  String get km_per_event_long => 'KM per Negative Event (Higher is better)';

  @override
  String get by_brand => 'By Brand';

  @override
  String get by_version => 'By Version';

  @override
  String get arena_total_mileage_title => 'Mileage Leaderboard';

  @override
  String get arena_total_mileage_subtitle => 'Total mileage recorded per brand';

  @override
  String arena_brand_evolution_title(Object brand) {
    return '$brand Evolution';
  }

  @override
  String get km_per_version_event_long =>
      'Comfort performance across software versions';

  @override
  String get arena_details_title => 'Negative Experience Breakdown';

  @override
  String get km_per_event => 'km/Event';

  @override
  String get all_versions => 'All Versions';

  @override
  String get select_brand => 'Select Brand';

  @override
  String get no_trips_yet =>
      'No trip data recorded yet. Start a trip to see statistics!';

  @override
  String get no_data_for_brand => 'No Data';

  @override
  String events_count(Object count) {
    return '$count Events';
  }

  @override
  String trips_count(Object count) {
    return '$count Trips';
  }

  @override
  String get mileage_label => 'Mileage';

  @override
  String get car_cert_banner => 'Verify your car to enable trip uploads';

  @override
  String get upload_cert_photos => 'Car Certification';

  @override
  String get upload_hint =>
      'Please upload a photo showing your car model and VIN (usually found on the lower driver-side windshield or door pillar).';

  @override
  String get file_limit_hint => 'Up to 3 photos (JPG/PNG, < 5MB each)';

  @override
  String get submit_for_audit => 'Submit for Verification';

  @override
  String get submit_success_tip =>
      'Verification details submitted! We\'ll review them shortly.';

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
  String get insufficient_data_title => 'Insufficient Trip Data';

  @override
  String get insufficient_data_message =>
      'The trip data is too short, please upload trip data with longer mileage';

  @override
  String get upload => 'Upload';

  @override
  String get privacy_policy => 'Privacy Policy';

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
      'Stop the vehicle, tap \'End Trip\' before picking up';

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
}
