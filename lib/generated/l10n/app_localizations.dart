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
  /// **'Vehicle Model'**
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
