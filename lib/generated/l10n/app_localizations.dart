import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Puked'**
  String get appTitle;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @arena.
  ///
  /// In en, this message translates to:
  /// **'Arena'**
  String get arena;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeAuto.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeAuto;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @chinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get chinese;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @sensitivity.
  ///
  /// In en, this message translates to:
  /// **'Auto-tagging Sensitivity'**
  String get sensitivity;

  /// No description provided for @sensitivityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get sensitivityLow;

  /// No description provided for @sensitivityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium (Sensitive)'**
  String get sensitivityMedium;

  /// No description provided for @sensitivityHigh.
  ///
  /// In en, this message translates to:
  /// **'High (Most Sensitive - Default)'**
  String get sensitivityHigh;

  /// No description provided for @sensitivityLowDesc.
  ///
  /// In en, this message translates to:
  /// **'Accel > 3.0m/s², Brake > 3.5m/s²'**
  String get sensitivityLowDesc;

  /// No description provided for @sensitivityMediumDesc.
  ///
  /// In en, this message translates to:
  /// **'Accel > 2.4m/s², Brake > 2.8m/s²'**
  String get sensitivityMediumDesc;

  /// No description provided for @sensitivityHighDesc.
  ///
  /// In en, this message translates to:
  /// **'Accel > 1.8m/s², Brake > 2.1m/s²'**
  String get sensitivityHighDesc;

  /// No description provided for @sensitivityTip.
  ///
  /// In en, this message translates to:
  /// **'Higher sensitivity means lower acceleration thresholds for auto-tagging events.'**
  String get sensitivityTip;

  /// No description provided for @rapidAcceleration.
  ///
  /// In en, this message translates to:
  /// **'Rapid Acceleration'**
  String get rapidAcceleration;

  /// No description provided for @rapidDeceleration.
  ///
  /// In en, this message translates to:
  /// **'Rapid Deceleration'**
  String get rapidDeceleration;

  /// No description provided for @jerk.
  ///
  /// In en, this message translates to:
  /// **'Jerk'**
  String get jerk;

  /// No description provided for @bump.
  ///
  /// In en, this message translates to:
  /// **'Bump'**
  String get bump;

  /// No description provided for @wobble.
  ///
  /// In en, this message translates to:
  /// **'Wobble'**
  String get wobble;

  /// No description provided for @start_trip.
  ///
  /// In en, this message translates to:
  /// **'START TRIP'**
  String get start_trip;

  /// No description provided for @stop_trip.
  ///
  /// In en, this message translates to:
  /// **'STOP TRIP'**
  String get stop_trip;

  /// No description provided for @calibrating.
  ///
  /// In en, this message translates to:
  /// **'Calibrating...'**
  String get calibrating;

  /// No description provided for @calibration_tip.
  ///
  /// In en, this message translates to:
  /// **'Keep the phone stable for vehicle alignment'**
  String get calibration_tip;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @modify_vehicle_info.
  ///
  /// In en, this message translates to:
  /// **'Modify Vehicle Info'**
  String get modify_vehicle_info;

  /// No description provided for @vehicle_info.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Info'**
  String get vehicle_info;

  /// No description provided for @car_model.
  ///
  /// In en, this message translates to:
  /// **'Car Model'**
  String get car_model;

  /// No description provided for @software_version.
  ///
  /// In en, this message translates to:
  /// **'Software Version'**
  String get software_version;

  /// No description provided for @model_hint.
  ///
  /// In en, this message translates to:
  /// **'Enter model (e.g. Model 3)'**
  String get model_hint;

  /// No description provided for @version_hint.
  ///
  /// In en, this message translates to:
  /// **'Enter version (e.g. v12.5)'**
  String get version_hint;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @current_version.
  ///
  /// In en, this message translates to:
  /// **'Current Version'**
  String get current_version;

  /// No description provided for @check_update.
  ///
  /// In en, this message translates to:
  /// **'Check for Update'**
  String get check_update;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @sync_data.
  ///
  /// In en, this message translates to:
  /// **'Sync Data'**
  String get sync_data;

  /// No description provided for @login_to_sync.
  ///
  /// In en, this message translates to:
  /// **'Login to sync data and share trips'**
  String get login_to_sync;

  /// No description provided for @connected_as.
  ///
  /// In en, this message translates to:
  /// **'Connected as: {name}'**
  String connected_as(Object name);

  /// No description provided for @brand.
  ///
  /// In en, this message translates to:
  /// **'My ADAS'**
  String get brand;

  /// No description provided for @my_car.
  ///
  /// In en, this message translates to:
  /// **'My Car'**
  String get my_car;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get name;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @no_account.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Register'**
  String get no_account;

  /// No description provided for @has_account.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Login'**
  String get has_account;

  /// No description provided for @login_failed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get login_failed;

  /// No description provided for @register_failed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed'**
  String get register_failed;

  /// No description provided for @forgot_password.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgot_password;

  /// No description provided for @reset_email_sent.
  ///
  /// In en, this message translates to:
  /// **'Reset email sent, please check your inbox'**
  String get reset_email_sent;

  /// No description provided for @verify_email.
  ///
  /// In en, this message translates to:
  /// **'Verify Email'**
  String get verify_email;

  /// No description provided for @verification_sent.
  ///
  /// In en, this message translates to:
  /// **'Verification email sent'**
  String get verification_sent;

  /// No description provided for @not_verified.
  ///
  /// In en, this message translates to:
  /// **'Not verified (Tap to verify)'**
  String get not_verified;

  /// No description provided for @error_email_taken.
  ///
  /// In en, this message translates to:
  /// **'Email already registered'**
  String get error_email_taken;

  /// No description provided for @error_invalid_credentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password'**
  String get error_invalid_credentials;

  /// No description provided for @error_password_too_short.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get error_password_too_short;

  /// No description provided for @verification_success.
  ///
  /// In en, this message translates to:
  /// **'Verification successful!'**
  String get verification_success;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing cloud status...'**
  String get syncing;

  /// No description provided for @sync_complete.
  ///
  /// In en, this message translates to:
  /// **'Sync complete, marked {count} trips'**
  String sync_complete(Object count);

  /// No description provided for @no_cloud_records.
  ///
  /// In en, this message translates to:
  /// **'No matching cloud records found'**
  String get no_cloud_records;

  /// No description provided for @sync_cloud_status.
  ///
  /// In en, this message translates to:
  /// **'Sync upload status'**
  String get sync_cloud_status;

  /// No description provided for @arena_top10_title.
  ///
  /// In en, this message translates to:
  /// **'Safe Driving Top 10'**
  String get arena_top10_title;

  /// No description provided for @km_per_event_long.
  ///
  /// In en, this message translates to:
  /// **'KM per Negative Event (Higher is better)'**
  String get km_per_event_long;

  /// No description provided for @by_brand.
  ///
  /// In en, this message translates to:
  /// **'By Brand'**
  String get by_brand;

  /// No description provided for @by_version.
  ///
  /// In en, this message translates to:
  /// **'By Version'**
  String get by_version;

  /// No description provided for @arena_total_mileage_title.
  ///
  /// In en, this message translates to:
  /// **'Mileage Leaderboard'**
  String get arena_total_mileage_title;

  /// No description provided for @arena_total_mileage_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Total mileage recorded per brand'**
  String get arena_total_mileage_subtitle;

  /// No description provided for @arena_brand_evolution_title.
  ///
  /// In en, this message translates to:
  /// **'{brand} Evolution'**
  String arena_brand_evolution_title(Object brand);

  /// No description provided for @km_per_version_event_long.
  ///
  /// In en, this message translates to:
  /// **'Comfort performance across software versions'**
  String get km_per_version_event_long;

  /// No description provided for @arena_details_title.
  ///
  /// In en, this message translates to:
  /// **'Negative Experience Breakdown'**
  String get arena_details_title;

  /// No description provided for @km_per_event.
  ///
  /// In en, this message translates to:
  /// **'km/Event'**
  String get km_per_event;

  /// No description provided for @all_versions.
  ///
  /// In en, this message translates to:
  /// **'All Versions'**
  String get all_versions;

  /// No description provided for @select_brand.
  ///
  /// In en, this message translates to:
  /// **'Select Brand'**
  String get select_brand;

  /// No description provided for @no_trips_yet.
  ///
  /// In en, this message translates to:
  /// **'No trip data recorded yet. Start a trip to see statistics!'**
  String get no_trips_yet;

  /// No description provided for @no_data_for_brand.
  ///
  /// In en, this message translates to:
  /// **'No Data'**
  String get no_data_for_brand;

  /// No description provided for @events_count.
  ///
  /// In en, this message translates to:
  /// **'{count} Events'**
  String events_count(Object count);

  /// No description provided for @trips_count.
  ///
  /// In en, this message translates to:
  /// **'{count} Trips'**
  String trips_count(Object count);

  /// No description provided for @mileage_label.
  ///
  /// In en, this message translates to:
  /// **'Mileage'**
  String get mileage_label;

  /// No description provided for @car_cert_banner.
  ///
  /// In en, this message translates to:
  /// **'Verify your car to enable trip uploads'**
  String get car_cert_banner;

  /// No description provided for @upload_cert_photos.
  ///
  /// In en, this message translates to:
  /// **'Car Certification'**
  String get upload_cert_photos;

  /// No description provided for @upload_hint.
  ///
  /// In en, this message translates to:
  /// **'Please upload a photo showing your car model and VIN (usually found on the lower driver-side windshield or door pillar).'**
  String get upload_hint;

  /// No description provided for @file_limit_hint.
  ///
  /// In en, this message translates to:
  /// **'Up to 3 photos (JPG/PNG, < 5MB each)'**
  String get file_limit_hint;

  /// No description provided for @submit_for_audit.
  ///
  /// In en, this message translates to:
  /// **'Submit for Verification'**
  String get submit_for_audit;

  /// No description provided for @submit_success_tip.
  ///
  /// In en, this message translates to:
  /// **'Verification details submitted! We\'ll review them shortly.'**
  String get submit_success_tip;

  /// No description provided for @error_image_limit.
  ///
  /// In en, this message translates to:
  /// **'Please select up to 3 photos.'**
  String get error_image_limit;

  /// No description provided for @error_image_size.
  ///
  /// In en, this message translates to:
  /// **'Each photo must be under 5MB.'**
  String get error_image_size;

  /// No description provided for @error_image_type.
  ///
  /// In en, this message translates to:
  /// **'Only JPG and PNG photos are supported.'**
  String get error_image_type;

  /// No description provided for @delete_event_title.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete Event'**
  String get delete_event_title;

  /// No description provided for @delete_event_desc.
  ///
  /// In en, this message translates to:
  /// **'Deleted events cannot be recovered. Are you sure?'**
  String get delete_event_desc;

  /// No description provided for @insufficient_data_title.
  ///
  /// In en, this message translates to:
  /// **'Insufficient Trip Data'**
  String get insufficient_data_title;

  /// No description provided for @insufficient_data_message.
  ///
  /// In en, this message translates to:
  /// **'The trip data is too short, please upload trip data with longer mileage'**
  String get insufficient_data_message;

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @privacy_policy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacy_policy;

  /// No description provided for @agree_privacy_link.
  ///
  /// In en, this message translates to:
  /// **'I agree to {policy}'**
  String agree_privacy_link(Object policy);

  /// No description provided for @onboarding_step1.
  ///
  /// In en, this message translates to:
  /// **'Mount your phone, aligned with the car\'s direction'**
  String get onboarding_step1;

  /// No description provided for @onboarding_step2.
  ///
  /// In en, this message translates to:
  /// **'Stay still, tap \'Start Trip\' to calibrate sensors'**
  String get onboarding_step2;

  /// No description provided for @onboarding_step3.
  ///
  /// In en, this message translates to:
  /// **'Start testing, avoid picking up your phone'**
  String get onboarding_step3;

  /// No description provided for @onboarding_step4.
  ///
  /// In en, this message translates to:
  /// **'Stop the vehicle, tap \'End Trip\' before picking up'**
  String get onboarding_step4;

  /// No description provided for @onboarding_step5.
  ///
  /// In en, this message translates to:
  /// **'Share your trip and data with others'**
  String get onboarding_step5;

  /// No description provided for @onboarding_start.
  ///
  /// In en, this message translates to:
  /// **'Start Experience'**
  String get onboarding_start;

  /// No description provided for @onboarding_welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Puked'**
  String get onboarding_welcome;

  /// No description provided for @saving_image.
  ///
  /// In en, this message translates to:
  /// **'Saving as image...'**
  String get saving_image;

  /// No description provided for @save_success.
  ///
  /// In en, this message translates to:
  /// **'Image saved to gallery'**
  String get save_success;

  /// No description provided for @save_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save image'**
  String get save_failed;

  /// No description provided for @error_no_photo_permission.
  ///
  /// In en, this message translates to:
  /// **'Please grant photo gallery permission'**
  String get error_no_photo_permission;

  /// No description provided for @algorithm_version.
  ///
  /// In en, this message translates to:
  /// **'Algorithm Version'**
  String get algorithm_version;

  /// No description provided for @algorithm_update_success.
  ///
  /// In en, this message translates to:
  /// **'Algorithm synced (v{version})'**
  String algorithm_update_success(Object version);

  /// No description provided for @algorithm_update_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to sync parameters'**
  String get algorithm_update_failed;

  /// No description provided for @algorithm_settings_title.
  ///
  /// In en, this message translates to:
  /// **'Online Algorithm Settings'**
  String get algorithm_settings_title;

  /// No description provided for @algorithm_updated_at.
  ///
  /// In en, this message translates to:
  /// **'Last Updated'**
  String get algorithm_updated_at;

  /// No description provided for @threshold_accel_label.
  ///
  /// In en, this message translates to:
  /// **'Accel Threshold'**
  String get threshold_accel_label;

  /// No description provided for @threshold_decel_label.
  ///
  /// In en, this message translates to:
  /// **'Decel Threshold'**
  String get threshold_decel_label;

  /// No description provided for @threshold_wobble_span_label.
  ///
  /// In en, this message translates to:
  /// **'Wobble Span'**
  String get threshold_wobble_span_label;

  /// No description provided for @threshold_bump_label.
  ///
  /// In en, this message translates to:
  /// **'Bump Threshold'**
  String get threshold_bump_label;

  /// No description provided for @threshold_jerk_label.
  ///
  /// In en, this message translates to:
  /// **'Jerk Threshold'**
  String get threshold_jerk_label;

  /// No description provided for @threshold_pitch_label.
  ///
  /// In en, this message translates to:
  /// **'Pitch Threshold'**
  String get threshold_pitch_label;

  /// No description provided for @jerk_window_ms_label.
  ///
  /// In en, this message translates to:
  /// **'Jerk Window'**
  String get jerk_window_ms_label;

  /// No description provided for @accel_decel_window_ms_label.
  ///
  /// In en, this message translates to:
  /// **'Accel/Decel Window'**
  String get accel_decel_window_ms_label;

  /// No description provided for @wobble_window_ms_label.
  ///
  /// In en, this message translates to:
  /// **'Wobble Window'**
  String get wobble_window_ms_label;

  /// No description provided for @fusion_window_ms_label.
  ///
  /// In en, this message translates to:
  /// **'Fusion Window'**
  String get fusion_window_ms_label;

  /// No description provided for @zy_interference_threshold_label.
  ///
  /// In en, this message translates to:
  /// **'Z-Y Interference'**
  String get zy_interference_threshold_label;

  /// No description provided for @pitch_validation_enabled_label.
  ///
  /// In en, this message translates to:
  /// **'Pitch Protection'**
  String get pitch_validation_enabled_label;

  /// No description provided for @speed_low_factor_label.
  ///
  /// In en, this message translates to:
  /// **'Low Speed Factor'**
  String get speed_low_factor_label;

  /// No description provided for @speed_high_factor_label.
  ///
  /// In en, this message translates to:
  /// **'High Speed Factor'**
  String get speed_high_factor_label;

  /// No description provided for @max_jerk_allowed_label.
  ///
  /// In en, this message translates to:
  /// **'Max Jerk Limit'**
  String get max_jerk_allowed_label;

  /// No description provided for @max_accel_allowed_label.
  ///
  /// In en, this message translates to:
  /// **'Max Accel Limit'**
  String get max_accel_allowed_label;

  /// No description provided for @max_wobble_span_allowed_label.
  ///
  /// In en, this message translates to:
  /// **'Max Wobble Limit'**
  String get max_wobble_span_allowed_label;

  /// No description provided for @max_bump_allowed_label.
  ///
  /// In en, this message translates to:
  /// **'Max Bump Limit'**
  String get max_bump_allowed_label;

  /// No description provided for @threshold_accel_hint.
  ///
  /// In en, this message translates to:
  /// **'Min acceleration to trigger \'Rapid Acceleration\''**
  String get threshold_accel_hint;

  /// No description provided for @threshold_decel_hint.
  ///
  /// In en, this message translates to:
  /// **'Min deceleration to trigger \'Rapid Deceleration\''**
  String get threshold_decel_hint;

  /// No description provided for @threshold_wobble_span_hint.
  ///
  /// In en, this message translates to:
  /// **'Min lateral span to trigger \'Wobble\''**
  String get threshold_wobble_span_hint;

  /// No description provided for @threshold_bump_hint.
  ///
  /// In en, this message translates to:
  /// **'Min vertical G to trigger \'Bump\''**
  String get threshold_bump_hint;

  /// No description provided for @threshold_jerk_hint.
  ///
  /// In en, this message translates to:
  /// **'Min change rate to trigger \'Jerk\''**
  String get threshold_jerk_hint;

  /// No description provided for @threshold_pitch_hint.
  ///
  /// In en, this message translates to:
  /// **'Min angular velocity to trigger \'Pitching\''**
  String get threshold_pitch_hint;

  /// No description provided for @jerk_window_ms_hint.
  ///
  /// In en, this message translates to:
  /// **'Time window for calculating Jerk rate'**
  String get jerk_window_ms_hint;

  /// No description provided for @accel_decel_window_ms_hint.
  ///
  /// In en, this message translates to:
  /// **'Min continuous time for Accel/Decel'**
  String get accel_decel_window_ms_hint;

  /// No description provided for @wobble_window_ms_hint.
  ///
  /// In en, this message translates to:
  /// **'Time window for detecting lateral swings'**
  String get wobble_window_ms_hint;

  /// No description provided for @fusion_window_ms_hint.
  ///
  /// In en, this message translates to:
  /// **'Wait time for merging multiple features'**
  String get fusion_window_ms_hint;

  /// No description provided for @max_jerk_allowed_hint.
  ///
  /// In en, this message translates to:
  /// **'Max jerk limit to filter out device drops'**
  String get max_jerk_allowed_hint;

  /// No description provided for @max_accel_allowed_hint.
  ///
  /// In en, this message translates to:
  /// **'Max accel limit to filter out non-driving noise'**
  String get max_accel_allowed_hint;

  /// No description provided for @max_wobble_span_allowed_hint.
  ///
  /// In en, this message translates to:
  /// **'Max wobble limit to filter out device handling'**
  String get max_wobble_span_allowed_hint;

  /// No description provided for @max_bump_allowed_hint.
  ///
  /// In en, this message translates to:
  /// **'Max bump limit to filter out non-road impacts'**
  String get max_bump_allowed_hint;

  /// No description provided for @zy_interference_threshold_hint.
  ///
  /// In en, this message translates to:
  /// **'Z-axis activity level to suppress Y-axis'**
  String get zy_interference_threshold_hint;

  /// No description provided for @pitch_validation_enabled_hint.
  ///
  /// In en, this message translates to:
  /// **'Use gyroscope to verify car\'s pitching'**
  String get pitch_validation_enabled_hint;

  /// No description provided for @speed_low_factor_hint.
  ///
  /// In en, this message translates to:
  /// **'Sensitivity factor at low speeds (<10km/h)'**
  String get speed_low_factor_hint;

  /// No description provided for @speed_high_factor_hint.
  ///
  /// In en, this message translates to:
  /// **'Sensitivity factor at high speeds (>80km/h)'**
  String get speed_high_factor_hint;

  /// No description provided for @sync_now.
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get sync_now;

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @downloading.
  ///
  /// In en, this message translates to:
  /// **'Syncing & Downloading...'**
  String get downloading;

  /// No description provided for @download_success.
  ///
  /// In en, this message translates to:
  /// **'Sync download successful'**
  String get download_success;

  /// No description provided for @download_failed.
  ///
  /// In en, this message translates to:
  /// **'Sync download failed'**
  String get download_failed;

  /// No description provided for @cloud_trip.
  ///
  /// In en, this message translates to:
  /// **'Cloud Trip'**
  String get cloud_trip;

  /// No description provided for @pulling_cloud_trips.
  ///
  /// In en, this message translates to:
  /// **'Fetching cloud records...'**
  String get pulling_cloud_trips;

  /// No description provided for @cloud_sync_result.
  ///
  /// In en, this message translates to:
  /// **'Sync complete, found {count} new trips'**
  String cloud_sync_result(Object count);

  /// No description provided for @custom_version_input.
  ///
  /// In en, this message translates to:
  /// **'Manual Input (Format: x.x.x, no sub-versions)'**
  String get custom_version_input;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @select_version.
  ///
  /// In en, this message translates to:
  /// **'Select Version'**
  String get select_version;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
