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
  String get car_model => 'Vehicle Model';

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
}
