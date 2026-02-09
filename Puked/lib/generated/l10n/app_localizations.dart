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

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeAuto.
  ///
  /// In en, this message translates to:
  /// **'AUTO'**
  String get themeAuto;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'LIGHT'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'DARK'**
  String get themeDark;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

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

  /// No description provided for @event_sound.
  ///
  /// In en, this message translates to:
  /// **'Event Sound'**
  String get event_sound;

  /// No description provided for @event_sound_desc.
  ///
  /// In en, this message translates to:
  /// **'Play sound when negative event detected'**
  String get event_sound_desc;

  /// No description provided for @high_frame_rate.
  ///
  /// In en, this message translates to:
  /// **'High Frame Rate Recording'**
  String get high_frame_rate;

  /// No description provided for @high_frame_rate_desc.
  ///
  /// In en, this message translates to:
  /// **'KOL Exclusive: Record 10Hz sensor data for more details'**
  String get high_frame_rate_desc;

  /// No description provided for @video_recording.
  ///
  /// In en, this message translates to:
  /// **'Record Negative Event Videos (Beta)'**
  String get video_recording;

  /// No description provided for @video_recording_desc.
  ///
  /// In en, this message translates to:
  /// **'Record 5-second video when negative events occur'**
  String get video_recording_desc;

  /// No description provided for @camera_permission_needed.
  ///
  /// In en, this message translates to:
  /// **'Camera permission needed'**
  String get camera_permission_needed;

  /// No description provided for @camera_init_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to initialize camera'**
  String get camera_init_failed;

  /// No description provided for @camera_preview_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to get preview'**
  String get camera_preview_failed;

  /// No description provided for @camera_starting.
  ///
  /// In en, this message translates to:
  /// **'Starting camera...'**
  String get camera_starting;

  /// No description provided for @camera_preview_placeholder.
  ///
  /// In en, this message translates to:
  /// **'Camera Preview Placeholder'**
  String get camera_preview_placeholder;

  /// No description provided for @camera_preview_hint.
  ///
  /// In en, this message translates to:
  /// **'Preview requires native implementation\nVideo recording still works normally'**
  String get camera_preview_hint;

  /// No description provided for @current_version.
  ///
  /// In en, this message translates to:
  /// **'Current Version'**
  String get current_version;

  /// No description provided for @algorithm_version.
  ///
  /// In en, this message translates to:
  /// **'Algorithm Version'**
  String get algorithm_version;

  /// No description provided for @check_update.
  ///
  /// In en, this message translates to:
  /// **'Check for Update'**
  String get check_update;

  /// No description provided for @privacy_policy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacy_policy;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @user.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get user;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @login_to_sync.
  ///
  /// In en, this message translates to:
  /// **'Login to sync data and share trips'**
  String get login_to_sync;

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

  /// No description provided for @verification_sent.
  ///
  /// In en, this message translates to:
  /// **'Verification email sent'**
  String get verification_sent;

  /// No description provided for @verification_success.
  ///
  /// In en, this message translates to:
  /// **'Verification successful!'**
  String get verification_success;

  /// No description provided for @not_verified.
  ///
  /// In en, this message translates to:
  /// **'Not verified (Tap to verify)'**
  String get not_verified;

  /// No description provided for @approved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approved;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejected;

  /// No description provided for @unverified.
  ///
  /// In en, this message translates to:
  /// **'Unverified'**
  String get unverified;

  /// No description provided for @my_car.
  ///
  /// In en, this message translates to:
  /// **'My Car'**
  String get my_car;

  /// No description provided for @my_data_uploaded.
  ///
  /// In en, this message translates to:
  /// **'My Data (Uploaded)'**
  String get my_data_uploaded;

  /// No description provided for @uploaded_mileage.
  ///
  /// In en, this message translates to:
  /// **'Uploaded Mileage'**
  String get uploaded_mileage;

  /// No description provided for @mileage_contribution.
  ///
  /// In en, this message translates to:
  /// **'Mileage Contribution'**
  String get mileage_contribution;

  /// No description provided for @my_puked_rank.
  ///
  /// In en, this message translates to:
  /// **'My PUKED Rank'**
  String get my_puked_rank;

  /// No description provided for @my_puked_value.
  ///
  /// In en, this message translates to:
  /// **'My PUKED Value'**
  String get my_puked_value;

  /// No description provided for @brand_distribution_desc.
  ///
  /// In en, this message translates to:
  /// **'Dist.'**
  String get brand_distribution_desc;

  /// No description provided for @uploaded_mileage_val.
  ///
  /// In en, this message translates to:
  /// **'{value} KM'**
  String uploaded_mileage_val(Object value);

  /// No description provided for @mileage_contribution_val.
  ///
  /// In en, this message translates to:
  /// **'{value}%'**
  String mileage_contribution_val(Object value);

  /// No description provided for @my_puked_rank_val.
  ///
  /// In en, this message translates to:
  /// **'Rank {rank} / {total}'**
  String my_puked_rank_val(Object rank, Object total);

  /// No description provided for @my_puked_value_val.
  ///
  /// In en, this message translates to:
  /// **'{value} km/Evt'**
  String my_puked_value_val(Object value);

  /// No description provided for @account_and_car.
  ///
  /// In en, this message translates to:
  /// **'Account & Car'**
  String get account_and_car;

  /// No description provided for @realtime_g.
  ///
  /// In en, this message translates to:
  /// **'Real-time G'**
  String get realtime_g;

  /// No description provided for @peak_g.
  ///
  /// In en, this message translates to:
  /// **'Peak G'**
  String get peak_g;

  /// No description provided for @longitudinal.
  ///
  /// In en, this message translates to:
  /// **'LONGITUDINAL'**
  String get longitudinal;

  /// No description provided for @lateral.
  ///
  /// In en, this message translates to:
  /// **'LATERAL'**
  String get lateral;

  /// No description provided for @trip_summary.
  ///
  /// In en, this message translates to:
  /// **'Trip Summary'**
  String get trip_summary;

  /// No description provided for @total_events.
  ///
  /// In en, this message translates to:
  /// **'Total Events'**
  String get total_events;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @speed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get speed;

  /// No description provided for @avg_speed.
  ///
  /// In en, this message translates to:
  /// **'Avg Speed'**
  String get avg_speed;

  /// No description provided for @calibrate.
  ///
  /// In en, this message translates to:
  /// **'Calibrate'**
  String get calibrate;

  /// No description provided for @recorded_msg.
  ///
  /// In en, this message translates to:
  /// **'Recorded (Last 10s data)'**
  String get recorded_msg;

  /// No description provided for @no_trips.
  ///
  /// In en, this message translates to:
  /// **'No trip records'**
  String get no_trips;

  /// No description provided for @exporting.
  ///
  /// In en, this message translates to:
  /// **'Exporting data...'**
  String get exporting;

  /// No description provided for @pro.
  ///
  /// In en, this message translates to:
  /// **'Pro'**
  String get pro;

  /// No description provided for @submit_trip.
  ///
  /// In en, this message translates to:
  /// **'Submit Trip'**
  String get submit_trip;

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get uploading;

  /// No description provided for @upload_success.
  ///
  /// In en, this message translates to:
  /// **'Upload successful'**
  String get upload_success;

  /// No description provided for @upload_failed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get upload_failed;

  /// No description provided for @neg_exp.
  ///
  /// In en, this message translates to:
  /// **'Negative Exp.'**
  String get neg_exp;

  /// No description provided for @gps_strong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get gps_strong;

  /// No description provided for @gps_fair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get gps_fair;

  /// No description provided for @gps_weak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get gps_weak;

  /// No description provided for @gps_no_signal.
  ///
  /// In en, this message translates to:
  /// **'No Signal'**
  String get gps_no_signal;

  /// No description provided for @share_card.
  ///
  /// In en, this message translates to:
  /// **'Share Card'**
  String get share_card;

  /// No description provided for @trip_analysis.
  ///
  /// In en, this message translates to:
  /// **'Trip Analysis'**
  String get trip_analysis;

  /// No description provided for @event_breakdown.
  ///
  /// In en, this message translates to:
  /// **'Event Breakdown'**
  String get event_breakdown;

  /// No description provided for @trigger_sensitivity.
  ///
  /// In en, this message translates to:
  /// **'Trigger Sensitivity'**
  String get trigger_sensitivity;

  /// No description provided for @trigger_duration.
  ///
  /// In en, this message translates to:
  /// **'Trigger Duration'**
  String get trigger_duration;

  /// No description provided for @false_positive_suppression.
  ///
  /// In en, this message translates to:
  /// **'False Positive Suppression'**
  String get false_positive_suppression;

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

  /// No description provided for @select_version.
  ///
  /// In en, this message translates to:
  /// **'Select Version'**
  String get select_version;

  /// No description provided for @custom_version_input.
  ///
  /// In en, this message translates to:
  /// **'Manual Input'**
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

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @software_version.
  ///
  /// In en, this message translates to:
  /// **'Software Version'**
  String get software_version;

  /// No description provided for @car_model.
  ///
  /// In en, this message translates to:
  /// **'Car Model'**
  String get car_model;

  /// No description provided for @vehicle_info.
  ///
  /// In en, this message translates to:
  /// **'Vehicle Info'**
  String get vehicle_info;

  /// No description provided for @modify_vehicle_info.
  ///
  /// In en, this message translates to:
  /// **'Modify Vehicle Info'**
  String get modify_vehicle_info;

  /// No description provided for @arena_top10_title.
  ///
  /// In en, this message translates to:
  /// **'Comfort Top10'**
  String get arena_top10_title;

  /// No description provided for @weekly_comfort_ranking.
  ///
  /// In en, this message translates to:
  /// **'Weekly Comfort Ranking'**
  String get weekly_comfort_ranking;

  /// No description provided for @weekly_comfort_desc.
  ///
  /// In en, this message translates to:
  /// **'Best comfort by scenario this week'**
  String get weekly_comfort_desc;

  /// No description provided for @weekly_mileage_ranking.
  ///
  /// In en, this message translates to:
  /// **'Weekly Mileage Ranking'**
  String get weekly_mileage_ranking;

  /// No description provided for @weekly_mileage_desc.
  ///
  /// In en, this message translates to:
  /// **'Total mileage recorded this week'**
  String get weekly_mileage_desc;

  /// No description provided for @arena_total_mileage_title.
  ///
  /// In en, this message translates to:
  /// **'Mileage by Brand'**
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

  /// No description provided for @arena_details_title.
  ///
  /// In en, this message translates to:
  /// **'Neg Events Breakdown'**
  String get arena_details_title;

  /// No description provided for @arena_leaderboard_title.
  ///
  /// In en, this message translates to:
  /// **'Mileage Contributors'**
  String get arena_leaderboard_title;

  /// No description provided for @low_speed_ranking.
  ///
  /// In en, this message translates to:
  /// **'Urban Comfort'**
  String get low_speed_ranking;

  /// No description provided for @high_speed_ranking.
  ///
  /// In en, this message translates to:
  /// **'Highway Comfort'**
  String get high_speed_ranking;

  /// No description provided for @low_speed_desc.
  ///
  /// In en, this message translates to:
  /// **'Events for trips < 50 km/h, km/evt, total mileage > 300'**
  String get low_speed_desc;

  /// No description provided for @high_speed_desc.
  ///
  /// In en, this message translates to:
  /// **'Events for trips >= 50 km/h, km/evt, total mileage > 300'**
  String get high_speed_desc;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'Urban'**
  String get city;

  /// No description provided for @highway.
  ///
  /// In en, this message translates to:
  /// **'Highway'**
  String get highway;

  /// No description provided for @weekly_rank.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly_rank;

  /// No description provided for @total_rank.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total_rank;

  /// No description provided for @user_mileage_unit.
  ///
  /// In en, this message translates to:
  /// **'km'**
  String get user_mileage_unit;

  /// No description provided for @km_per_event.
  ///
  /// In en, this message translates to:
  /// **'km/Event'**
  String get km_per_event;

  /// No description provided for @km_per_event_long.
  ///
  /// In en, this message translates to:
  /// **'Km between negative experiences, total mileage > 300'**
  String get km_per_event_long;

  /// No description provided for @km_per_version_event_long.
  ///
  /// In en, this message translates to:
  /// **'Average km per negative experience by version'**
  String get km_per_version_event_long;

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

  /// No description provided for @mileage_label.
  ///
  /// In en, this message translates to:
  /// **'Mileage'**
  String get mileage_label;

  /// No description provided for @trips_count.
  ///
  /// In en, this message translates to:
  /// **'{count} Trips'**
  String trips_count(Object count);

  /// No description provided for @events_count.
  ///
  /// In en, this message translates to:
  /// **'{count} Events'**
  String events_count(Object count);

  /// No description provided for @app_name.
  ///
  /// In en, this message translates to:
  /// **'Puked'**
  String get app_name;

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

  /// No description provided for @start_trip.
  ///
  /// In en, this message translates to:
  /// **'START TRIP'**
  String get start_trip;

  /// No description provided for @stop_trip.
  ///
  /// In en, this message translates to:
  /// **'LONG PRESS TO STOP'**
  String get stop_trip;

  /// No description provided for @calibrating.
  ///
  /// In en, this message translates to:
  /// **'Calibrating...'**
  String get calibrating;

  /// No description provided for @calibrated.
  ///
  /// In en, this message translates to:
  /// **'Calibrated!'**
  String get calibrated;

  /// No description provided for @calibration_failed.
  ///
  /// In en, this message translates to:
  /// **'Calibration Failed'**
  String get calibration_failed;

  /// No description provided for @calibration_failed_desc.
  ///
  /// In en, this message translates to:
  /// **'Please ensure the vehicle and phone are stationary.'**
  String get calibration_failed_desc;

  /// No description provided for @rapid_accel.
  ///
  /// In en, this message translates to:
  /// **'Rapid Accel'**
  String get rapid_accel;

  /// No description provided for @rapid_decel.
  ///
  /// In en, this message translates to:
  /// **'Rapid Decel'**
  String get rapid_decel;

  /// No description provided for @jerk.
  ///
  /// In en, this message translates to:
  /// **'Jerk'**
  String get jerk;

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

  /// No description provided for @jerk_event.
  ///
  /// In en, this message translates to:
  /// **'Jerk'**
  String get jerk_event;

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

  /// No description provided for @manual.
  ///
  /// In en, this message translates to:
  /// **'Manual Mark'**
  String get manual;

  /// No description provided for @calibration_tip.
  ///
  /// In en, this message translates to:
  /// **'Keep the phone stable for vehicle alignment'**
  String get calibration_tip;

  /// No description provided for @no_data_for_brand.
  ///
  /// In en, this message translates to:
  /// **'No Data'**
  String get no_data_for_brand;

  /// No description provided for @connected_as.
  ///
  /// In en, this message translates to:
  /// **'Connected as: {name}'**
  String connected_as(Object name);

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
  /// **'Please upload a photo showing your car model and VIN'**
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
  /// **'Verification details submitted!'**
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
  /// **'Stop vehicle, long press \'Long Press to Stop\' button (0.8s) before picking up'**
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

  /// No description provided for @zx_interference_threshold_label.
  ///
  /// In en, this message translates to:
  /// **'Z-X Interference'**
  String get zx_interference_threshold_label;

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

  /// No description provided for @min_accel_for_jerk_label.
  ///
  /// In en, this message translates to:
  /// **'Jerk Min Accel'**
  String get min_accel_for_jerk_label;

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

  /// No description provided for @min_accel_for_jerk_hint.
  ///
  /// In en, this message translates to:
  /// **'Only calculate jerk if acceleration exceeds this'**
  String get min_accel_for_jerk_hint;

  /// No description provided for @zy_interference_threshold_hint.
  ///
  /// In en, this message translates to:
  /// **'Z-axis activity level to suppress Y-axis'**
  String get zy_interference_threshold_hint;

  /// No description provided for @zx_interference_threshold_hint.
  ///
  /// In en, this message translates to:
  /// **'Z-axis activity level to suppress X-axis'**
  String get zx_interference_threshold_hint;

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

  /// No description provided for @error_invalid_credentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password'**
  String get error_invalid_credentials;

  /// No description provided for @login_failed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get login_failed;

  /// No description provided for @forgot_password.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password'**
  String get forgot_password;

  /// No description provided for @reset_email_sent.
  ///
  /// In en, this message translates to:
  /// **'Reset email sent'**
  String get reset_email_sent;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @no_account.
  ///
  /// In en, this message translates to:
  /// **'No account? Register now'**
  String get no_account;

  /// No description provided for @error_email_taken.
  ///
  /// In en, this message translates to:
  /// **'Email already taken'**
  String get error_email_taken;

  /// No description provided for @error_password_too_short.
  ///
  /// In en, this message translates to:
  /// **'Password too short (min 8)'**
  String get error_password_too_short;

  /// No description provided for @register_failed.
  ///
  /// In en, this message translates to:
  /// **'Register failed'**
  String get register_failed;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @has_account.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Login'**
  String get has_account;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @delete_trips.
  ///
  /// In en, this message translates to:
  /// **'Delete Trips'**
  String get delete_trips;

  /// No description provided for @delete_trips_confirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete these {count} trips?'**
  String delete_trips_confirm(Object count);

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @select_items.
  ///
  /// In en, this message translates to:
  /// **'Select Items'**
  String get select_items;

  /// No description provided for @sync_cloud_status.
  ///
  /// In en, this message translates to:
  /// **'Sync Status'**
  String get sync_cloud_status;

  /// No description provided for @bulk_upload_confirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to upload these {count} trips?'**
  String bulk_upload_confirm(Object count);

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @insufficient_data_title.
  ///
  /// In en, this message translates to:
  /// **'Insufficient Data'**
  String get insufficient_data_title;

  /// No description provided for @insufficient_data_message.
  ///
  /// In en, this message translates to:
  /// **'Some trips have insufficient data (mileage too short). We suggest driving further before submitting.'**
  String get insufficient_data_message;

  /// No description provided for @syncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing...'**
  String get syncing;

  /// No description provided for @no_trips_yet.
  ///
  /// In en, this message translates to:
  /// **'No History Trips'**
  String get no_trips_yet;

  /// No description provided for @submit_trip_confirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to submit this trip to the Arena?'**
  String get submit_trip_confirm;

  /// No description provided for @car_cert_banner_approved.
  ///
  /// In en, this message translates to:
  /// **'Car Verified'**
  String get car_cert_banner_approved;

  /// No description provided for @car_cert_banner_pending.
  ///
  /// In en, this message translates to:
  /// **'Car Verifying'**
  String get car_cert_banner_pending;

  /// No description provided for @car_cert_banner_rejected.
  ///
  /// In en, this message translates to:
  /// **'Car Verification Rejected'**
  String get car_cert_banner_rejected;

  /// No description provided for @upload_cert_photos_new.
  ///
  /// In en, this message translates to:
  /// **'Re-upload Certification'**
  String get upload_cert_photos_new;

  /// No description provided for @upload_cert_photos_submitted.
  ///
  /// In en, this message translates to:
  /// **'Certification Submitted'**
  String get upload_cert_photos_submitted;

  /// No description provided for @upload_hint_new.
  ///
  /// In en, this message translates to:
  /// **'Please re-upload photos showing your license plate or VIN'**
  String get upload_hint_new;

  /// No description provided for @event_list.
  ///
  /// In en, this message translates to:
  /// **'Event Details'**
  String get event_list;

  /// No description provided for @event_statistics.
  ///
  /// In en, this message translates to:
  /// **'Event Details'**
  String get event_statistics;

  /// No description provided for @auto_negative_events.
  ///
  /// In en, this message translates to:
  /// **'Auto-Detected'**
  String get auto_negative_events;

  /// No description provided for @manual_marked_events.
  ///
  /// In en, this message translates to:
  /// **'Manual Marks'**
  String get manual_marked_events;

  /// No description provided for @total_count.
  ///
  /// In en, this message translates to:
  /// **'{value} Total'**
  String total_count(Object value);

  /// No description provided for @min.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get min;

  /// No description provided for @value.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get value;

  /// No description provided for @app_tagline.
  ///
  /// In en, this message translates to:
  /// **'Quantifying AD Comfort'**
  String get app_tagline;

  /// No description provided for @algo_a.
  ///
  /// In en, this message translates to:
  /// **'ALGO A'**
  String get algo_a;

  /// No description provided for @algo_b.
  ///
  /// In en, this message translates to:
  /// **'ALGO B'**
  String get algo_b;

  /// No description provided for @sensor_frozen.
  ///
  /// In en, this message translates to:
  /// **'SENSOR FROZEN'**
  String get sensor_frozen;

  /// No description provided for @ins_active.
  ///
  /// In en, this message translates to:
  /// **'INS ACTIVE'**
  String get ins_active;

  /// No description provided for @fetching_arena_data.
  ///
  /// In en, this message translates to:
  /// **'Fetching Arena Data...'**
  String get fetching_arena_data;

  /// No description provided for @no_records.
  ///
  /// In en, this message translates to:
  /// **'No Records'**
  String get no_records;

  /// No description provided for @arena_mileage_requirement.
  ///
  /// In en, this message translates to:
  /// **'Ranking brand mileage must be greater than 300 km'**
  String get arena_mileage_requirement;

  /// No description provided for @share_failed.
  ///
  /// In en, this message translates to:
  /// **'Share failed'**
  String get share_failed;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @avatar_updated.
  ///
  /// In en, this message translates to:
  /// **'Avatar updated'**
  String get avatar_updated;

  /// No description provided for @passwords_not_match.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwords_not_match;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @invalid_email.
  ///
  /// In en, this message translates to:
  /// **'Invalid email format'**
  String get invalid_email;

  /// No description provided for @password_too_short_hint.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get password_too_short_hint;

  /// No description provided for @repeat_password.
  ///
  /// In en, this message translates to:
  /// **'Repeat password'**
  String get repeat_password;

  /// No description provided for @crop_avatar.
  ///
  /// In en, this message translates to:
  /// **'Crop Avatar'**
  String get crop_avatar;

  /// No description provided for @update_avatar_failed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update avatar'**
  String get update_avatar_failed;

  /// No description provided for @delete_account.
  ///
  /// In en, this message translates to:
  /// **'Destroy Account'**
  String get delete_account;

  /// No description provided for @new_version_found.
  ///
  /// In en, this message translates to:
  /// **'New Version Found'**
  String get new_version_found;

  /// No description provided for @changelog.
  ///
  /// In en, this message translates to:
  /// **'Changelog'**
  String get changelog;

  /// No description provided for @update_now.
  ///
  /// In en, this message translates to:
  /// **'Update Now'**
  String get update_now;

  /// No description provided for @downloading_update.
  ///
  /// In en, this message translates to:
  /// **'Downloading Update'**
  String get downloading_update;

  /// No description provided for @permission_not_granted.
  ///
  /// In en, this message translates to:
  /// **'Permission not granted'**
  String get permission_not_granted;

  /// No description provided for @network_error.
  ///
  /// In en, this message translates to:
  /// **'Network error'**
  String get network_error;

  /// No description provided for @calibration_failed_stationary.
  ///
  /// In en, this message translates to:
  /// **'Calibration failed: Please ensure the vehicle is stationary'**
  String get calibration_failed_stationary;

  /// No description provided for @calibration_failed_motion.
  ///
  /// In en, this message translates to:
  /// **'Calibration failed: Please keep the phone still'**
  String get calibration_failed_motion;

  /// No description provided for @sensor_error.
  ///
  /// In en, this message translates to:
  /// **'Sensor reading error'**
  String get sensor_error;

  /// No description provided for @recording_notification_content.
  ///
  /// In en, this message translates to:
  /// **'Puked is recording your trip'**
  String get recording_notification_content;

  /// No description provided for @recording_notification_title.
  ///
  /// In en, this message translates to:
  /// **'Recording in Progress'**
  String get recording_notification_title;

  /// No description provided for @logic_section.
  ///
  /// In en, this message translates to:
  /// **'Core Logic'**
  String get logic_section;

  /// No description provided for @please_login_first.
  ///
  /// In en, this message translates to:
  /// **'Please login first'**
  String get please_login_first;

  /// No description provided for @network_unavailable.
  ///
  /// In en, this message translates to:
  /// **'Network unavailable, please check settings'**
  String get network_unavailable;

  /// No description provided for @uploading_trip.
  ///
  /// In en, this message translates to:
  /// **'Uploading trip...'**
  String get uploading_trip;

  /// No description provided for @trip_submitted_success.
  ///
  /// In en, this message translates to:
  /// **'Trip submitted to Arena successfully'**
  String get trip_submitted_success;

  /// No description provided for @image_upload_success.
  ///
  /// In en, this message translates to:
  /// **'Image uploaded successfully'**
  String get image_upload_success;

  /// No description provided for @network_restored.
  ///
  /// In en, this message translates to:
  /// **'Network connection restored'**
  String get network_restored;

  /// No description provided for @calibration_success_start.
  ///
  /// In en, this message translates to:
  /// **'Calibration successful, recording started'**
  String get calibration_success_start;

  /// No description provided for @select_or_input_version.
  ///
  /// In en, this message translates to:
  /// **'Please select or enter version'**
  String get select_or_input_version;

  /// No description provided for @confirm_delete_account.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to destroy your account?'**
  String get confirm_delete_account;

  /// No description provided for @exit_app.
  ///
  /// In en, this message translates to:
  /// **'Exit App'**
  String get exit_app;

  /// No description provided for @exit_app_confirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to exit Puked?'**
  String get exit_app_confirm;

  /// No description provided for @ignore_this_version.
  ///
  /// In en, this message translates to:
  /// **'Ignore this version'**
  String get ignore_this_version;

  /// No description provided for @recalibrate.
  ///
  /// In en, this message translates to:
  /// **'Recalibrate'**
  String get recalibrate;

  /// No description provided for @invalid_verification_code.
  ///
  /// In en, this message translates to:
  /// **'Invalid verification code, please check email'**
  String get invalid_verification_code;

  /// No description provided for @speed_unit.
  ///
  /// In en, this message translates to:
  /// **'{value} km/h'**
  String speed_unit(Object value);

  /// No description provided for @g_unit.
  ///
  /// In en, this message translates to:
  /// **'{value} G'**
  String g_unit(Object value);

  /// No description provided for @distance_unit.
  ///
  /// In en, this message translates to:
  /// **'{value} km'**
  String distance_unit(Object value);

  /// No description provided for @duration_unit.
  ///
  /// In en, this message translates to:
  /// **'{value} min'**
  String duration_unit(Object value);

  /// No description provided for @update_failed.
  ///
  /// In en, this message translates to:
  /// **'Update failed'**
  String get update_failed;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing...'**
  String get processing;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @ensure_network_tip.
  ///
  /// In en, this message translates to:
  /// **'Please ensure network connection and try again'**
  String get ensure_network_tip;

  /// No description provided for @invalid_email_format.
  ///
  /// In en, this message translates to:
  /// **'Invalid email format'**
  String get invalid_email_format;

  /// No description provided for @password_too_short.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get password_too_short;

  /// No description provided for @field_required.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get field_required;

  /// No description provided for @coupling_curve_index_label.
  ///
  /// In en, this message translates to:
  /// **'Suppression Curve Index'**
  String get coupling_curve_index_label;

  /// No description provided for @coupling_curve_index_hint.
  ///
  /// In en, this message translates to:
  /// **'Controls the non-linearity of Z-axis suppression (1.0 is linear)'**
  String get coupling_curve_index_hint;

  /// No description provided for @coupling_strength_y_label.
  ///
  /// In en, this message translates to:
  /// **'Longitudinal Strength (Y)'**
  String get coupling_strength_y_label;

  /// No description provided for @coupling_strength_y_hint.
  ///
  /// In en, this message translates to:
  /// **'Weight of Z-axis activity suppressing Accel/Decel detection'**
  String get coupling_strength_y_hint;

  /// No description provided for @coupling_strength_x_label.
  ///
  /// In en, this message translates to:
  /// **'Lateral Strength (X)'**
  String get coupling_strength_x_label;

  /// No description provided for @coupling_strength_x_hint.
  ///
  /// In en, this message translates to:
  /// **'Weight of Z-axis activity suppressing Jerk/Wobble detection'**
  String get coupling_strength_x_hint;

  /// No description provided for @turn_comp_multiplier_label.
  ///
  /// In en, this message translates to:
  /// **'Turn Comp Multiplier'**
  String get turn_comp_multiplier_label;

  /// No description provided for @turn_comp_multiplier_hint.
  ///
  /// In en, this message translates to:
  /// **'Multiplier for raising decel threshold based on yaw rate'**
  String get turn_comp_multiplier_hint;

  /// No description provided for @turn_comp_max_label.
  ///
  /// In en, this message translates to:
  /// **'Turn Comp Max'**
  String get turn_comp_max_label;

  /// No description provided for @turn_comp_max_hint.
  ///
  /// In en, this message translates to:
  /// **'Maximum ceiling for threshold adjustment during turns'**
  String get turn_comp_max_hint;

  /// No description provided for @event_window_coverage_label.
  ///
  /// In en, this message translates to:
  /// **'Window Coverage Rate'**
  String get event_window_coverage_label;

  /// No description provided for @event_window_coverage_hint.
  ///
  /// In en, this message translates to:
  /// **'Required percentage of points exceeding threshold within window'**
  String get event_window_coverage_hint;

  /// No description provided for @low_speed_jerk_limit_label.
  ///
  /// In en, this message translates to:
  /// **'Low Speed Jerk Limit'**
  String get low_speed_jerk_limit_label;

  /// No description provided for @low_speed_jerk_limit_hint.
  ///
  /// In en, this message translates to:
  /// **'Speed (km/h) below which deceleration is downgraded to Jerk'**
  String get low_speed_jerk_limit_hint;

  /// No description provided for @trend_filter_section.
  ///
  /// In en, this message translates to:
  /// **'Trend Filter'**
  String get trend_filter_section;

  /// No description provided for @enable_trend_filter_label.
  ///
  /// In en, this message translates to:
  /// **'Enable Trend Filter'**
  String get enable_trend_filter_label;

  /// No description provided for @enable_trend_filter_hint.
  ///
  /// In en, this message translates to:
  /// **'Filter out gentle decel/accel events before detection (recommended)'**
  String get enable_trend_filter_hint;

  /// No description provided for @trend_change_threshold_label.
  ///
  /// In en, this message translates to:
  /// **'Trend Change Threshold'**
  String get trend_change_threshold_label;

  /// No description provided for @trend_change_threshold_hint.
  ///
  /// In en, this message translates to:
  /// **'Min threshold for accel difference between first/second half'**
  String get trend_change_threshold_hint;

  /// No description provided for @min_std_dev_threshold_label.
  ///
  /// In en, this message translates to:
  /// **'Std Dev Threshold (Backup)'**
  String get min_std_dev_threshold_label;

  /// No description provided for @min_std_dev_threshold_hint.
  ///
  /// In en, this message translates to:
  /// **'Min Y-axis acceleration standard deviation (auxiliary metric)'**
  String get min_std_dev_threshold_hint;

  /// No description provided for @min_range_threshold_label.
  ///
  /// In en, this message translates to:
  /// **'Range Threshold (Backup)'**
  String get min_range_threshold_label;

  /// No description provided for @min_range_threshold_hint.
  ///
  /// In en, this message translates to:
  /// **'Min Y-axis acceleration range (auxiliary metric)'**
  String get min_range_threshold_hint;

  /// No description provided for @recording_voice.
  ///
  /// In en, this message translates to:
  /// **'Recording...'**
  String get recording_voice;

  /// No description provided for @pro_on.
  ///
  /// In en, this message translates to:
  /// **'VOICE ON'**
  String get pro_on;

  /// No description provided for @pro_off.
  ///
  /// In en, this message translates to:
  /// **'VOICE OFF'**
  String get pro_off;

  /// No description provided for @voice_tutorial_title.
  ///
  /// In en, this message translates to:
  /// **'Voice Recording Guide'**
  String get voice_tutorial_title;

  /// No description provided for @voice_tutorial_step1.
  ///
  /// In en, this message translates to:
  /// **'1. Turn on \'VOICE ON\' and wait for model download'**
  String get voice_tutorial_step1;

  /// No description provided for @voice_tutorial_step2.
  ///
  /// In en, this message translates to:
  /// **'2. Start trip and keep phone still for calibration'**
  String get voice_tutorial_step2;

  /// No description provided for @voice_tutorial_step3.
  ///
  /// In en, this message translates to:
  /// **'3. Long-press map or use Bluetooth play key to record'**
  String get voice_tutorial_step3;

  /// No description provided for @voice_tutorial_step4.
  ///
  /// In en, this message translates to:
  /// **'4. View supported events in Voice Recording settings'**
  String get voice_tutorial_step4;

  /// No description provided for @got_it.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get got_it;

  /// No description provided for @voice_engine_config_failed.
  ///
  /// In en, this message translates to:
  /// **'Voice Engine Config Failed'**
  String get voice_engine_config_failed;

  /// No description provided for @voice_engine_not_ready.
  ///
  /// In en, this message translates to:
  /// **'Voice engine not ready, please wait for download'**
  String get voice_engine_not_ready;

  /// No description provided for @recording_active_debug.
  ///
  /// In en, this message translates to:
  /// **'Recording Active'**
  String get recording_active_debug;

  /// No description provided for @gps_signal_lost.
  ///
  /// In en, this message translates to:
  /// **'GPS Signal Lost'**
  String get gps_signal_lost;

  /// No description provided for @ins_active_display.
  ///
  /// In en, this message translates to:
  /// **'INS Active (Display Only)'**
  String get ins_active_display;

  /// No description provided for @trip_report_title.
  ///
  /// In en, this message translates to:
  /// **'Trip Report'**
  String get trip_report_title;

  /// No description provided for @share_msg_body.
  ///
  /// In en, this message translates to:
  /// **'Puked Trip Report: {time}'**
  String share_msg_body(Object time);

  /// No description provided for @pts_unit.
  ///
  /// In en, this message translates to:
  /// **'pts'**
  String get pts_unit;

  /// No description provided for @fail.
  ///
  /// In en, this message translates to:
  /// **'FAIL'**
  String get fail;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @proDisengagement.
  ///
  /// In en, this message translates to:
  /// **'Disengagement'**
  String get proDisengagement;

  /// No description provided for @proViolation.
  ///
  /// In en, this message translates to:
  /// **'Violation'**
  String get proViolation;

  /// No description provided for @proExperience.
  ///
  /// In en, this message translates to:
  /// **'Experience'**
  String get proExperience;

  /// No description provided for @voice_recording.
  ///
  /// In en, this message translates to:
  /// **'Voice Recording'**
  String get voice_recording;

  /// No description provided for @voice_recording_desc.
  ///
  /// In en, this message translates to:
  /// **'View events that support voice recording'**
  String get voice_recording_desc;

  /// No description provided for @voice_recording_title.
  ///
  /// In en, this message translates to:
  /// **'Voice Recording Details'**
  String get voice_recording_title;

  /// No description provided for @voice_recording_intro.
  ///
  /// In en, this message translates to:
  /// **'The following ADAS events support voice descriptions by long-pressing the \'Record\' button when triggered during a trip:'**
  String get voice_recording_intro;

  /// No description provided for @voice_recording_manual_desc.
  ///
  /// In en, this message translates to:
  /// **'Long-press the record button at any time to record a manual voice note for reporting current status or road conditions.'**
  String get voice_recording_manual_desc;

  /// No description provided for @edit_event.
  ///
  /// In en, this message translates to:
  /// **'Edit Event'**
  String get edit_event;

  /// No description provided for @event_type.
  ///
  /// In en, this message translates to:
  /// **'Event Type'**
  String get event_type;

  /// No description provided for @event_description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get event_description;

  /// No description provided for @save_changes.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get save_changes;

  /// No description provided for @selecting_best_mirror.
  ///
  /// In en, this message translates to:
  /// **'Selecting fastest mirror...'**
  String get selecting_best_mirror;
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
