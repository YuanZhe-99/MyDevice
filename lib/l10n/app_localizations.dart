import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
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
  /// Purpose: Create an app localizations instance.
  /// Inputs: `localeName`.
  /// Returns: A new `AppLocalizations` instance.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  /// Purpose: Return the localized string for `of`.
  /// Inputs: `context`.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
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
    Locale('ja'),
    Locale('zh'),
    Locale('zh', 'TW'),
  ];

  /// Purpose: Return the localized string for `appTitle`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'MyDevice!!!!!'**
  String get appTitle;

  /// Purpose: Return the localized string for `navDevices`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @navDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get navDevices;

  /// Purpose: Return the localized string for `navSettings`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Purpose: Return the localized string for `deviceCategoryDesktop`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deviceCategoryDesktop.
  ///
  /// In en, this message translates to:
  /// **'Desktop'**
  String get deviceCategoryDesktop;

  /// Purpose: Return the localized string for `deviceCategoryLaptop`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deviceCategoryLaptop.
  ///
  /// In en, this message translates to:
  /// **'Laptop'**
  String get deviceCategoryLaptop;

  /// Purpose: Return the localized string for `deviceCategoryPhone`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deviceCategoryPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get deviceCategoryPhone;

  /// Purpose: Return the localized string for `deviceCategoryTablet`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deviceCategoryTablet.
  ///
  /// In en, this message translates to:
  /// **'Tablet'**
  String get deviceCategoryTablet;

  /// Purpose: Return the localized string for `deviceCategoryHeadphone`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deviceCategoryHeadphone.
  ///
  /// In en, this message translates to:
  /// **'Headphone'**
  String get deviceCategoryHeadphone;

  /// Purpose: Return the localized string for `deviceCategoryWatch`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deviceCategoryWatch.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get deviceCategoryWatch;

  /// Purpose: Return the localized string for `deviceCategoryRouter`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deviceCategoryRouter.
  ///
  /// In en, this message translates to:
  /// **'Router'**
  String get deviceCategoryRouter;

  /// Purpose: Return the localized string for `deviceCategoryGameConsole`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deviceCategoryGameConsole.
  ///
  /// In en, this message translates to:
  /// **'Game Console'**
  String get deviceCategoryGameConsole;

  /// Purpose: Return the localized string for `deviceCategoryVps`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deviceCategoryVps.
  ///
  /// In en, this message translates to:
  /// **'VPS'**
  String get deviceCategoryVps;

  /// Purpose: Return the localized string for `deviceCategoryDevBoard`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deviceCategoryDevBoard.
  ///
  /// In en, this message translates to:
  /// **'Dev Board'**
  String get deviceCategoryDevBoard;

  /// Purpose: Return the localized string for `deviceCategoryOther`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deviceCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get deviceCategoryOther;

  /// Purpose: Return the localized string for `deviceName`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deviceName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get deviceName;

  /// Purpose: Return the localized string for `deviceBrand`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deviceBrand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get deviceBrand;

  /// Purpose: Return the localized string for `deviceModel`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deviceModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get deviceModel;

  /// Purpose: Return the localized string for `deviceCategory`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deviceCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get deviceCategory;

  /// Purpose: Return the localized string for `devicePurchaseDate`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @devicePurchaseDate.
  ///
  /// In en, this message translates to:
  /// **'Purchase Date'**
  String get devicePurchaseDate;

  /// Purpose: Return the localized string for `deviceReleaseDate`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deviceReleaseDate.
  ///
  /// In en, this message translates to:
  /// **'Release Date'**
  String get deviceReleaseDate;

  /// Purpose: Return the localized string for `deviceNotes`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deviceNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get deviceNotes;

  /// Purpose: Return the localized string for `deviceLocation`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deviceLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get deviceLocation;

  /// Purpose: Return the localized string for `mapPickLocation`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @mapPickLocation.
  ///
  /// In en, this message translates to:
  /// **'Pick Location'**
  String get mapPickLocation;

  /// Purpose: Return the localized string for `mapSearchHint`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @mapSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search location...'**
  String get mapSearchHint;

  /// Purpose: Return the localized string for `cpuInfo`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @cpuInfo.
  ///
  /// In en, this message translates to:
  /// **'CPU'**
  String get cpuInfo;

  /// Purpose: Return the localized string for `cpuModel`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @cpuModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get cpuModel;

  /// Purpose: Return the localized string for `cpuArchitecture`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @cpuArchitecture.
  ///
  /// In en, this message translates to:
  /// **'Architecture'**
  String get cpuArchitecture;

  /// Purpose: Return the localized string for `cpuFrequency`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @cpuFrequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get cpuFrequency;

  /// Purpose: Return the localized string for `cpuPCores`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @cpuPCores.
  ///
  /// In en, this message translates to:
  /// **'P-Cores'**
  String get cpuPCores;

  /// Purpose: Return the localized string for `cpuECores`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @cpuECores.
  ///
  /// In en, this message translates to:
  /// **'E-Cores'**
  String get cpuECores;

  /// Purpose: Return the localized string for `cpuThreads`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @cpuThreads.
  ///
  /// In en, this message translates to:
  /// **'Threads'**
  String get cpuThreads;

  /// Purpose: Return the localized string for `cpuCache`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @cpuCache.
  ///
  /// In en, this message translates to:
  /// **'Cache'**
  String get cpuCache;

  /// Purpose: Return the localized string for `gpuInfo`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @gpuInfo.
  ///
  /// In en, this message translates to:
  /// **'GPU'**
  String get gpuInfo;

  /// Purpose: Return the localized string for `gpuModel`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @gpuModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get gpuModel;

  /// Purpose: Return the localized string for `gpuArchitecture`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @gpuArchitecture.
  ///
  /// In en, this message translates to:
  /// **'Architecture'**
  String get gpuArchitecture;

  /// Purpose: Return the localized string for `ram`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @ram.
  ///
  /// In en, this message translates to:
  /// **'RAM'**
  String get ram;

  /// Purpose: Return the localized string for `storage`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @storage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get storage;

  /// Purpose: Return the localized string for `screenSize`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @screenSize.
  ///
  /// In en, this message translates to:
  /// **'Screen Size'**
  String get screenSize;

  /// Purpose: Return the localized string for `screenResolution`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @screenResolution.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get screenResolution;

  /// Purpose: Return the localized string for `ppi`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @ppi.
  ///
  /// In en, this message translates to:
  /// **'PPI'**
  String get ppi;

  /// Purpose: Return the localized string for `battery`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @battery.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get battery;

  /// Purpose: Return the localized string for `os`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @os.
  ///
  /// In en, this message translates to:
  /// **'OS'**
  String get os;

  /// Purpose: Return the localized string for `addDevice`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @addDevice.
  ///
  /// In en, this message translates to:
  /// **'Add Device'**
  String get addDevice;

  /// Purpose: Return the localized string for `editDevice`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @editDevice.
  ///
  /// In en, this message translates to:
  /// **'Edit Device'**
  String get editDevice;

  /// Purpose: Return the localized string for `deleteDevice`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deleteDevice.
  ///
  /// In en, this message translates to:
  /// **'Delete Device'**
  String get deleteDevice;

  /// Purpose: Return the localized string for `deleteDeviceConfirm`.
  /// Inputs: `name`.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deleteDeviceConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String deleteDeviceConfirm(String name);

  /// Purpose: Return the localized string for `save`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Purpose: Return the localized string for `cancel`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Purpose: Return the localized string for `delete`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Purpose: Return the localized string for `noDevices`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @noDevices.
  ///
  /// In en, this message translates to:
  /// **'No devices yet. Tap + to add one!'**
  String get noDevices;

  /// Purpose: Return the localized string for `deviceDetail`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deviceDetail.
  ///
  /// In en, this message translates to:
  /// **'Device Detail'**
  String get deviceDetail;

  /// Purpose: Return the localized string for `swipeEditHint`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @swipeEditHint.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get swipeEditHint;

  /// Purpose: Return the localized string for `swipeDeleteHint`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @swipeDeleteHint.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get swipeDeleteHint;

  /// Purpose: Return the localized string for `fromTemplate`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @fromTemplate.
  ///
  /// In en, this message translates to:
  /// **'From Template'**
  String get fromTemplate;

  /// Purpose: Return the localized string for `settingsTheme`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// Purpose: Return the localized string for `settingsThemeSystem`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// Purpose: Return the localized string for `settingsThemeLight`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// Purpose: Return the localized string for `settingsThemeDark`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// Purpose: Return the localized string for `settingsLanguage`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// Purpose: Return the localized string for `settingsLanguageSystem`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsLanguageSystem;

  /// Purpose: Return the localized string for `settingsGeneral`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// Purpose: Return the localized string for `settingsData`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsData;

  /// Purpose: Return the localized string for `settingsAbout`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// Purpose: Return the localized string for `settingsVersion`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// Purpose: Return the localized string for `settingsPrivacyPolicy`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacyPolicy;

  /// Purpose: Return the localized string for `settingsLicense`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsLicense.
  ///
  /// In en, this message translates to:
  /// **'License (GPLv3)'**
  String get settingsLicense;

  /// Purpose: Return the localized string for `settingsLicenses`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open Source Licenses'**
  String get settingsLicenses;

  /// Purpose: Return the localized string for `backupTitle`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @backupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get backupTitle;

  /// Purpose: Return the localized string for `backupSubtitle`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @backupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Full local backup (data + images)'**
  String get backupSubtitle;

  /// Purpose: Return the localized string for `backupCreate`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @backupCreate.
  ///
  /// In en, this message translates to:
  /// **'Create Backup'**
  String get backupCreate;

  /// Purpose: Return the localized string for `backupCreated`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @backupCreated.
  ///
  /// In en, this message translates to:
  /// **'Backup created'**
  String get backupCreated;

  /// Purpose: Return the localized string for `backupAutoBackup`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @backupAutoBackup.
  ///
  /// In en, this message translates to:
  /// **'Auto Backup'**
  String get backupAutoBackup;

  /// Purpose: Return the localized string for `backupRetention`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @backupRetention.
  ///
  /// In en, this message translates to:
  /// **'Retention Period'**
  String get backupRetention;

  /// Purpose: Return the localized string for `backupKeepForever`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @backupKeepForever.
  ///
  /// In en, this message translates to:
  /// **'Keep forever'**
  String get backupKeepForever;

  /// Purpose: Return the localized string for `backupKeepDays`.
  /// Inputs: `days`.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @backupKeepDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String backupKeepDays(int days);

  /// Purpose: Return the localized string for `backupHistory`.
  /// Inputs: `count`.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @backupHistory.
  ///
  /// In en, this message translates to:
  /// **'History ({count})'**
  String backupHistory(int count);

  /// Purpose: Return the localized string for `backupNoBackups`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @backupNoBackups.
  ///
  /// In en, this message translates to:
  /// **'No backups yet'**
  String get backupNoBackups;

  /// Purpose: Return the localized string for `backupRestore`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @backupRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get backupRestore;

  /// Purpose: Return the localized string for `backupRestoreConfirm`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @backupRestoreConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will overwrite your current data. Continue?'**
  String get backupRestoreConfirm;

  /// Purpose: Return the localized string for `backupRestored`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @backupRestored.
  ///
  /// In en, this message translates to:
  /// **'Backup restored'**
  String get backupRestored;

  /// Purpose: Return the localized string for `backupRestoreFailed`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @backupRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed'**
  String get backupRestoreFailed;

  /// Purpose: Return the localized string for `backupDeleteConfirm`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @backupDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this backup?'**
  String get backupDeleteConfirm;

  /// Purpose: Return the localized string for `exportData`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @exportData.
  ///
  /// In en, this message translates to:
  /// **'Export Data'**
  String get exportData;

  /// Purpose: Return the localized string for `exportAsZip`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @exportAsZip.
  ///
  /// In en, this message translates to:
  /// **'Export as ZIP'**
  String get exportAsZip;

  /// Purpose: Return the localized string for `exportAsZipDesc`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @exportAsZipDesc.
  ///
  /// In en, this message translates to:
  /// **'Full data archive (device data + images) for backup or migration'**
  String get exportAsZipDesc;

  /// Purpose: Return the localized string for `exportAsMarkdown`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @exportAsMarkdown.
  ///
  /// In en, this message translates to:
  /// **'Export as Markdown'**
  String get exportAsMarkdown;

  /// Purpose: Return the localized string for `exportAsMarkdownDesc`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @exportAsMarkdownDesc.
  ///
  /// In en, this message translates to:
  /// **'Device inventory with network & dataset info, for LLM personalization'**
  String get exportAsMarkdownDesc;

  /// Purpose: Return the localized string for `importData`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @importData.
  ///
  /// In en, this message translates to:
  /// **'Import Data'**
  String get importData;

  /// Purpose: Return the localized string for `exportSuccess`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @exportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Data exported successfully'**
  String get exportSuccess;

  /// Purpose: Return the localized string for `importSuccess`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @importSuccess.
  ///
  /// In en, this message translates to:
  /// **'Data imported successfully'**
  String get importSuccess;

  /// Purpose: Return the localized string for `importFailed`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed'**
  String get importFailed;

  /// Purpose: Return the localized string for `importConfirm`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @importConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will overwrite your current data. Continue?'**
  String get importConfirm;

  /// Purpose: Return the localized string for `dataMigration`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @dataMigration.
  ///
  /// In en, this message translates to:
  /// **'Open Data Folder'**
  String get dataMigration;

  /// Purpose: Return the localized string for `dataMigrationDesc`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @dataMigrationDesc.
  ///
  /// In en, this message translates to:
  /// **'Open the application data directory'**
  String get dataMigrationDesc;

  /// Purpose: Return the localized string for `settingsStorageLocation`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsStorageLocation.
  ///
  /// In en, this message translates to:
  /// **'Storage Location'**
  String get settingsStorageLocation;

  /// Purpose: Return the localized string for `settingsStoragePathHint`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsStoragePathHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the directory path for storing data. Leave empty to use default.'**
  String get settingsStoragePathHint;

  /// Purpose: Return the localized string for `settingsDirectoryPath`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsDirectoryPath.
  ///
  /// In en, this message translates to:
  /// **'Directory Path'**
  String get settingsDirectoryPath;

  /// Purpose: Return the localized string for `settingsResetDefault`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsResetDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get settingsResetDefault;

  /// Purpose: Return the localized string for `settingsResetDefaultLocation`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsResetDefaultLocation.
  ///
  /// In en, this message translates to:
  /// **'Reset to default location'**
  String get settingsResetDefaultLocation;

  /// Purpose: Return the localized string for `settingsStoragePathUpdated`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsStoragePathUpdated.
  ///
  /// In en, this message translates to:
  /// **'Storage path updated'**
  String get settingsStoragePathUpdated;

  /// Purpose: Return the localized string for `totalDevices`.
  /// Inputs: `count`.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @totalDevices.
  ///
  /// In en, this message translates to:
  /// **'{count} device(s)'**
  String totalDevices(int count);

  /// Purpose: Return the localized string for `storageType`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @storageType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get storageType;

  /// Purpose: Return the localized string for `storageInterface`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @storageInterface.
  ///
  /// In en, this message translates to:
  /// **'Interface'**
  String get storageInterface;

  /// Purpose: Return the localized string for `storageTypeSsd`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @storageTypeSsd.
  ///
  /// In en, this message translates to:
  /// **'SSD'**
  String get storageTypeSsd;

  /// Purpose: Return the localized string for `storageTypeSdCard`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @storageTypeSdCard.
  ///
  /// In en, this message translates to:
  /// **'SD Card'**
  String get storageTypeSdCard;

  /// Purpose: Return the localized string for `storageTypeHdd`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @storageTypeHdd.
  ///
  /// In en, this message translates to:
  /// **'HDD'**
  String get storageTypeHdd;

  /// Purpose: Return the localized string for `storageInterfaceM2Nvme`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @storageInterfaceM2Nvme.
  ///
  /// In en, this message translates to:
  /// **'M.2 NVMe'**
  String get storageInterfaceM2Nvme;

  /// Purpose: Return the localized string for `storageInterfaceSata25`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @storageInterfaceSata25.
  ///
  /// In en, this message translates to:
  /// **'2.5\" SATA'**
  String get storageInterfaceSata25;

  /// Purpose: Return the localized string for `storageInterfaceM2Sata`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @storageInterfaceM2Sata.
  ///
  /// In en, this message translates to:
  /// **'M.2 SATA'**
  String get storageInterfaceM2Sata;

  /// Purpose: Return the localized string for `storageInterfaceUsb`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @storageInterfaceUsb.
  ///
  /// In en, this message translates to:
  /// **'USB'**
  String get storageInterfaceUsb;

  /// Purpose: Return the localized string for `ramType`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @ramType.
  ///
  /// In en, this message translates to:
  /// **'RAM Type'**
  String get ramType;

  /// Purpose: Return the localized string for `sortTitle`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @sortTitle.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortTitle;

  /// Purpose: Return the localized string for `sortCustom`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @sortCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom Order'**
  String get sortCustom;

  /// Purpose: Return the localized string for `sortAlphabetical`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @sortAlphabetical.
  ///
  /// In en, this message translates to:
  /// **'Alphabetical'**
  String get sortAlphabetical;

  /// Purpose: Return the localized string for `sortPurchaseDate`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @sortPurchaseDate.
  ///
  /// In en, this message translates to:
  /// **'Purchase Date'**
  String get sortPurchaseDate;

  /// Purpose: Return the localized string for `sortReleaseDate`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @sortReleaseDate.
  ///
  /// In en, this message translates to:
  /// **'Release Date'**
  String get sortReleaseDate;

  /// Purpose: Return the localized string for `sortAscending`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @sortAscending.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get sortAscending;

  /// Purpose: Return the localized string for `sortSubnet`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @sortSubnet.
  ///
  /// In en, this message translates to:
  /// **'Subnet'**
  String get sortSubnet;

  /// Purpose: Return the localized string for `sortGroupByCategory`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @sortGroupByCategory.
  ///
  /// In en, this message translates to:
  /// **'Group by Category'**
  String get sortGroupByCategory;

  /// Purpose: Return the localized string for `sortReorder`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @sortReorder.
  ///
  /// In en, this message translates to:
  /// **'Reorder...'**
  String get sortReorder;

  /// Purpose: Return the localized string for `sortByIp`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @sortByIp.
  ///
  /// In en, this message translates to:
  /// **'IP Address'**
  String get sortByIp;

  /// Purpose: Return the localized string for `sortExitNodeFirst`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @sortExitNodeFirst.
  ///
  /// In en, this message translates to:
  /// **'Exit Nodes First'**
  String get sortExitNodeFirst;

  /// Purpose: Return the localized string for `navNetworks`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @navNetworks.
  ///
  /// In en, this message translates to:
  /// **'Networks'**
  String get navNetworks;

  /// Purpose: Return the localized string for `noNetworks`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @noNetworks.
  ///
  /// In en, this message translates to:
  /// **'No networks yet. Tap + to add one!'**
  String get noNetworks;

  /// Purpose: Return the localized string for `addNetwork`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @addNetwork.
  ///
  /// In en, this message translates to:
  /// **'Add Network'**
  String get addNetwork;

  /// Purpose: Return the localized string for `editNetwork`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @editNetwork.
  ///
  /// In en, this message translates to:
  /// **'Edit Network'**
  String get editNetwork;

  /// Purpose: Return the localized string for `deleteNetwork`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deleteNetwork.
  ///
  /// In en, this message translates to:
  /// **'Delete Network'**
  String get deleteNetwork;

  /// Purpose: Return the localized string for `deleteNetworkConfirm`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deleteNetworkConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will delete the network and all device assignments. Continue?'**
  String get deleteNetworkConfirm;

  /// Purpose: Return the localized string for `networkName`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @networkName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get networkName;

  /// Purpose: Return the localized string for `networkType`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @networkType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get networkType;

  /// Purpose: Return the localized string for `networkSubnet`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @networkSubnet.
  ///
  /// In en, this message translates to:
  /// **'Subnet'**
  String get networkSubnet;

  /// Purpose: Return the localized string for `networkGateway`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @networkGateway.
  ///
  /// In en, this message translates to:
  /// **'Gateway'**
  String get networkGateway;

  /// Purpose: Return the localized string for `networkDns`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @networkDns.
  ///
  /// In en, this message translates to:
  /// **'DNS Servers'**
  String get networkDns;

  /// Purpose: Return the localized string for `networkNotes`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @networkNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get networkNotes;

  /// Purpose: Return the localized string for `networkNotesHint`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @networkNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Config info, keys, remarks…'**
  String get networkNotesHint;

  /// Purpose: Return the localized string for `networkTypeLan`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @networkTypeLan.
  ///
  /// In en, this message translates to:
  /// **'LAN'**
  String get networkTypeLan;

  /// Purpose: Return the localized string for `networkTypeTailscale`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @networkTypeTailscale.
  ///
  /// In en, this message translates to:
  /// **'Tailscale'**
  String get networkTypeTailscale;

  /// Purpose: Return the localized string for `networkTypeZerotier`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @networkTypeZerotier.
  ///
  /// In en, this message translates to:
  /// **'ZeroTier'**
  String get networkTypeZerotier;

  /// Purpose: Return the localized string for `networkTypeEasytier`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @networkTypeEasytier.
  ///
  /// In en, this message translates to:
  /// **'EasyTier'**
  String get networkTypeEasytier;

  /// Purpose: Return the localized string for `networkTypeWireguard`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @networkTypeWireguard.
  ///
  /// In en, this message translates to:
  /// **'WireGuard'**
  String get networkTypeWireguard;

  /// Purpose: Return the localized string for `networkTypeOther`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @networkTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get networkTypeOther;

  /// Purpose: Return the localized string for `networkDevices`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @networkDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get networkDevices;

  /// Purpose: Return the localized string for `noNetworkDevices`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @noNetworkDevices.
  ///
  /// In en, this message translates to:
  /// **'No devices in this network yet.'**
  String get noNetworkDevices;

  /// Purpose: Return the localized string for `networkDeviceConfig`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @networkDeviceConfig.
  ///
  /// In en, this message translates to:
  /// **'Device Config'**
  String get networkDeviceConfig;

  /// Purpose: Return the localized string for `networkAddressMode`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @networkAddressMode.
  ///
  /// In en, this message translates to:
  /// **'Address Mode'**
  String get networkAddressMode;

  /// Purpose: Return the localized string for `addressModeDhcp`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @addressModeDhcp.
  ///
  /// In en, this message translates to:
  /// **'DHCP'**
  String get addressModeDhcp;

  /// Purpose: Return the localized string for `addressModeStatic`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @addressModeStatic.
  ///
  /// In en, this message translates to:
  /// **'Static IP'**
  String get addressModeStatic;

  /// Purpose: Return the localized string for `networkIpAddress`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @networkIpAddress.
  ///
  /// In en, this message translates to:
  /// **'IP Address'**
  String get networkIpAddress;

  /// Purpose: Return the localized string for `networkHostname`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @networkHostname.
  ///
  /// In en, this message translates to:
  /// **'Hostname'**
  String get networkHostname;

  /// Purpose: Return the localized string for `networkExitNode`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @networkExitNode.
  ///
  /// In en, this message translates to:
  /// **'Exit Node'**
  String get networkExitNode;

  /// Purpose: Return the localized string for `networkPickDevice`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @networkPickDevice.
  ///
  /// In en, this message translates to:
  /// **'Select Device'**
  String get networkPickDevice;

  /// Purpose: Return the localized string for `removeDevice`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @removeDevice.
  ///
  /// In en, this message translates to:
  /// **'Remove Device'**
  String get removeDevice;

  /// Purpose: Return the localized string for `removeDeviceConfirm`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @removeDeviceConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove this device from the network?'**
  String get removeDeviceConfirm;

  /// Purpose: Return the localized string for `settingsConfirm`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get settingsConfirm;

  /// Purpose: Return the localized string for `settingsWebDAVSync`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsWebDAVSync.
  ///
  /// In en, this message translates to:
  /// **'WebDAV Sync'**
  String get settingsWebDAVSync;

  /// Purpose: Return the localized string for `settingsWebDAVServerURL`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsWebDAVServerURL.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get settingsWebDAVServerURL;

  /// Purpose: Return the localized string for `settingsWebDAVUsername`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsWebDAVUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get settingsWebDAVUsername;

  /// Purpose: Return the localized string for `settingsWebDAVPassword`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsWebDAVPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get settingsWebDAVPassword;

  /// Purpose: Return the localized string for `settingsWebDAVRemotePath`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsWebDAVRemotePath.
  ///
  /// In en, this message translates to:
  /// **'Remote Path'**
  String get settingsWebDAVRemotePath;

  /// Purpose: Return the localized string for `settingsWebDAVNextcloud`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsWebDAVNextcloud.
  ///
  /// In en, this message translates to:
  /// **'Nextcloud'**
  String get settingsWebDAVNextcloud;

  /// Purpose: Return the localized string for `settingsWebDAVTestConnection`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsWebDAVTestConnection.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get settingsWebDAVTestConnection;

  /// Purpose: Return the localized string for `settingsWebDAVConnectionSuccess`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsWebDAVConnectionSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connection successful'**
  String get settingsWebDAVConnectionSuccess;

  /// Purpose: Return the localized string for `settingsWebDAVConnectionFailed`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsWebDAVConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get settingsWebDAVConnectionFailed;

  /// Purpose: Return the localized string for `settingsWebDAVConfigSaved`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsWebDAVConfigSaved.
  ///
  /// In en, this message translates to:
  /// **'WebDAV configuration saved'**
  String get settingsWebDAVConfigSaved;

  /// Purpose: Return the localized string for `settingsWebDAVSyncNow`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsWebDAVSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get settingsWebDAVSyncNow;

  /// Purpose: Return the localized string for `settingsWebDAVSyncing`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsWebDAVSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get settingsWebDAVSyncing;

  /// Purpose: Return the localized string for `settingsWebDAVSyncSuccess`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsWebDAVSyncSuccess.
  ///
  /// In en, this message translates to:
  /// **'Sync completed'**
  String get settingsWebDAVSyncSuccess;

  /// Purpose: Return the localized string for `settingsWebDAVSyncFailed`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsWebDAVSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get settingsWebDAVSyncFailed;

  /// Purpose: Return the localized string for `settingsWebDAVSyncImageWarnings`.
  /// Inputs: `count`.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsWebDAVSyncImageWarnings.
  ///
  /// In en, this message translates to:
  /// **'Sync completed, but {count} image(s) failed to transfer'**
  String settingsWebDAVSyncImageWarnings(int count);

  /// Purpose: Return the localized string for `settingsWebDAVAutoSync`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsWebDAVAutoSync.
  ///
  /// In en, this message translates to:
  /// **'Auto Sync'**
  String get settingsWebDAVAutoSync;

  /// Purpose: Return the localized string for `settingsWebDAVAutoSyncDesc`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsWebDAVAutoSyncDesc.
  ///
  /// In en, this message translates to:
  /// **'Sync automatically when data changes'**
  String get settingsWebDAVAutoSyncDesc;

  /// Purpose: Return the localized string for `settingsWebDAVDisconnect`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsWebDAVDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get settingsWebDAVDisconnect;

  /// Purpose: Return the localized string for `settingsWebDAVConfigRemoved`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsWebDAVConfigRemoved.
  ///
  /// In en, this message translates to:
  /// **'WebDAV configuration removed'**
  String get settingsWebDAVConfigRemoved;

  /// Purpose: Return the localized string for `backupRestoreModules`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @backupRestoreModules.
  ///
  /// In en, this message translates to:
  /// **'Select Modules to Restore'**
  String get backupRestoreModules;

  /// Purpose: Return the localized string for `backupSelectAll`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @backupSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get backupSelectAll;

  /// Purpose: Return the localized string for `backupModuleDevices`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @backupModuleDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get backupModuleDevices;

  /// Purpose: Return the localized string for `backupModuleNetworks`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @backupModuleNetworks.
  ///
  /// In en, this message translates to:
  /// **'Networks'**
  String get backupModuleNetworks;

  /// Purpose: Return the localized string for `backupModuleDatasets`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @backupModuleDatasets.
  ///
  /// In en, this message translates to:
  /// **'Data Sets'**
  String get backupModuleDatasets;

  /// Purpose: Return the localized string for `navDataSets`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @navDataSets.
  ///
  /// In en, this message translates to:
  /// **'Data Sets'**
  String get navDataSets;

  /// Purpose: Return the localized string for `noDataSets`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @noDataSets.
  ///
  /// In en, this message translates to:
  /// **'No data sets yet. Tap + to add one!'**
  String get noDataSets;

  /// Purpose: Return the localized string for `addDataSet`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @addDataSet.
  ///
  /// In en, this message translates to:
  /// **'Add Data Set'**
  String get addDataSet;

  /// Purpose: Return the localized string for `editDataSet`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @editDataSet.
  ///
  /// In en, this message translates to:
  /// **'Edit Data Set'**
  String get editDataSet;

  /// Purpose: Return the localized string for `deleteDataSet`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deleteDataSet.
  ///
  /// In en, this message translates to:
  /// **'Delete Data Set'**
  String get deleteDataSet;

  /// Purpose: Return the localized string for `deleteDataSetConfirm`.
  /// Inputs: `name`.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deleteDataSetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String deleteDataSetConfirm(String name);

  /// Purpose: Return the localized string for `dataSetName`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @dataSetName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get dataSetName;

  /// Purpose: Return the localized string for `dataSetEmoji`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @dataSetEmoji.
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get dataSetEmoji;

  /// Purpose: Return the localized string for `dataSetStorages`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @dataSetStorages.
  ///
  /// In en, this message translates to:
  /// **'Linked Storages'**
  String get dataSetStorages;

  /// Purpose: Return the localized string for `dataSetNoDeviceStorages`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @dataSetNoDeviceStorages.
  ///
  /// In en, this message translates to:
  /// **'No devices with storage found'**
  String get dataSetNoDeviceStorages;

  /// Purpose: Return the localized string for `mapViewDevices`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @mapViewDevices.
  ///
  /// In en, this message translates to:
  /// **'Device Map'**
  String get mapViewDevices;

  /// Purpose: Return the localized string for `mapViewNetworkDevices`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @mapViewNetworkDevices.
  ///
  /// In en, this message translates to:
  /// **'Network Device Map'**
  String get mapViewNetworkDevices;

  /// Purpose: Return the localized string for `mapNoLocations`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @mapNoLocations.
  ///
  /// In en, this message translates to:
  /// **'No devices have location data set.'**
  String get mapNoLocations;

  /// Purpose: Return the localized string for `deviceEmoji`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deviceEmoji.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get deviceEmoji;

  /// Purpose: Return the localized string for `deviceImage`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deviceImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get deviceImage;

  /// Purpose: Return the localized string for `devicePickImage`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @devicePickImage.
  ///
  /// In en, this message translates to:
  /// **'Pick Image'**
  String get devicePickImage;

  /// Purpose: Return the localized string for `deviceChangeImage`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deviceChangeImage.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get deviceChangeImage;

  /// Purpose: Return the localized string for `deviceRemoveIcon`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deviceRemoveIcon.
  ///
  /// In en, this message translates to:
  /// **'Remove Icon'**
  String get deviceRemoveIcon;

  /// Purpose: Return the localized string for `deviceSerialNumber`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deviceSerialNumber.
  ///
  /// In en, this message translates to:
  /// **'Serial Number'**
  String get deviceSerialNumber;

  /// Purpose: Return the localized string for `storageBrand`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @storageBrand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get storageBrand;

  /// Purpose: Return the localized string for `storageSerialNumber`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @storageSerialNumber.
  ///
  /// In en, this message translates to:
  /// **'Serial Number'**
  String get storageSerialNumber;

  /// Purpose: Return the localized string for `fetchFromInternet`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @fetchFromInternet.
  ///
  /// In en, this message translates to:
  /// **'Fetch Online'**
  String get fetchFromInternet;

  /// Purpose: Return the localized string for `searchDeviceInfo`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @searchDeviceInfo.
  ///
  /// In en, this message translates to:
  /// **'Fetch Device Info'**
  String get searchDeviceInfo;

  /// Purpose: Return the localized string for `searchHint`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search device name...'**
  String get searchHint;

  /// Purpose: Return the localized string for `searchButton`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @searchButton.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchButton;

  /// Purpose: Return the localized string for `searchNoResults`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get searchNoResults;

  /// Purpose: Return the localized string for `searchApply`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @searchApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get searchApply;

  /// Purpose: Return the localized string for `searchCurrent`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @searchCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get searchCurrent;

  /// Purpose: Return the localized string for `searchFetched`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @searchFetched.
  ///
  /// In en, this message translates to:
  /// **'Fetched'**
  String get searchFetched;

  /// Purpose: Return the localized string for `searchDeviceImage`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @searchDeviceImage.
  ///
  /// In en, this message translates to:
  /// **'Device Image'**
  String get searchDeviceImage;

  /// Purpose: Return the localized string for `searchFetchImage`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @searchFetchImage.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get searchFetchImage;

  /// Purpose: Return the localized string for `searchFetchingDetail`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @searchFetchingDetail.
  ///
  /// In en, this message translates to:
  /// **'Fetching details...'**
  String get searchFetchingDetail;

  /// Purpose: Return the localized string for `searchCpuInfo`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @searchCpuInfo.
  ///
  /// In en, this message translates to:
  /// **'Search CPU'**
  String get searchCpuInfo;

  /// Purpose: Return the localized string for `searchGpuInfo`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @searchGpuInfo.
  ///
  /// In en, this message translates to:
  /// **'Search GPU'**
  String get searchGpuInfo;

  /// Purpose: Return the localized string for `searchCpuHint`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @searchCpuHint.
  ///
  /// In en, this message translates to:
  /// **'Enter CPU model...'**
  String get searchCpuHint;

  /// Purpose: Return the localized string for `searchGpuHint`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @searchGpuHint.
  ///
  /// In en, this message translates to:
  /// **'Enter GPU model...'**
  String get searchGpuHint;

  /// Purpose: Return the localized string for `searchTemplatePlaceholder`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @searchTemplatePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get searchTemplatePlaceholder;

  /// Purpose: Return the localized string for `cpuPresetSearch`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @cpuPresetSearch.
  ///
  /// In en, this message translates to:
  /// **'Search CPU...'**
  String get cpuPresetSearch;

  /// Purpose: Return the localized string for `gpuPresetSearch`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @gpuPresetSearch.
  ///
  /// In en, this message translates to:
  /// **'Search GPU...'**
  String get gpuPresetSearch;

  /// Purpose: Return the localized string for `cpuArchHint`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @cpuArchHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. ARM Cortex-A78, x86-64'**
  String get cpuArchHint;

  /// Purpose: Return the localized string for `cpuFreqHint`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @cpuFreqHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 3.5 GHz'**
  String get cpuFreqHint;

  /// Purpose: Return the localized string for `cpuCacheHint`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @cpuCacheHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. L2 4MB / L3 32MB'**
  String get cpuCacheHint;

  /// Purpose: Return the localized string for `gpuArchHint`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @gpuArchHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Ada Lovelace, RDNA 3'**
  String get gpuArchHint;

  /// Purpose: Return the localized string for `ramHint`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @ramHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 16'**
  String get ramHint;

  /// Purpose: Return the localized string for `storageCapacityHint`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @storageCapacityHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 512'**
  String get storageCapacityHint;

  /// Purpose: Return the localized string for `storageBrandHint`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @storageBrandHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Samsung, WD'**
  String get storageBrandHint;

  /// Purpose: Return the localized string for `screenSizeHint`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @screenSizeHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 6.7\"'**
  String get screenSizeHint;

  /// Purpose: Return the localized string for `batteryHint`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @batteryHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 5000 mAh'**
  String get batteryHint;

  /// Purpose: Return the localized string for `osHint`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @osHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Windows 11, Android 15'**
  String get osHint;

  /// Purpose: Return the localized string for `locationHint`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @locationHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Home, Office, Tokyo DC'**
  String get locationHint;

  /// Purpose: Return the localized string for `networkSubnetHint`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @networkSubnetHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 192.168.1.0/24, 100.64.0.0/10'**
  String get networkSubnetHint;

  /// Purpose: Return the localized string for `networkGatewayHint`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @networkGatewayHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 192.168.1.1'**
  String get networkGatewayHint;

  /// Purpose: Return the localized string for `networkDnsHint`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @networkDnsHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 8.8.8.8, 1.1.1.1'**
  String get networkDnsHint;

  /// Purpose: Return the localized string for `networkIpHint`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @networkIpHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 192.168.1.100'**
  String get networkIpHint;

  /// Purpose: Return the localized string for `networkHostnameHint`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @networkHostnameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. my-server'**
  String get networkHostnameHint;

  /// Purpose: Return the localized string for `backupModuleImages`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @backupModuleImages.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get backupModuleImages;

  /// Purpose: Return the localized string for `syncConflictTitle`.
  /// Inputs: `name`.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @syncConflictTitle.
  ///
  /// In en, this message translates to:
  /// **'Sync Conflict: {name}'**
  String syncConflictTitle(String name);

  /// Purpose: Return the localized string for `syncConflictBody`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @syncConflictBody.
  ///
  /// In en, this message translates to:
  /// **'This record was modified on both devices since last sync.'**
  String get syncConflictBody;

  /// Purpose: Return the localized string for `syncConflictLocalVersion`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @syncConflictLocalVersion.
  ///
  /// In en, this message translates to:
  /// **'Local version:'**
  String get syncConflictLocalVersion;

  /// Purpose: Return the localized string for `syncConflictRemoteVersion`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @syncConflictRemoteVersion.
  ///
  /// In en, this message translates to:
  /// **'Remote version:'**
  String get syncConflictRemoteVersion;

  /// Purpose: Return the localized string for `syncConflictKeepLocal`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @syncConflictKeepLocal.
  ///
  /// In en, this message translates to:
  /// **'Keep Local'**
  String get syncConflictKeepLocal;

  /// Purpose: Return the localized string for `syncConflictKeepRemote`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @syncConflictKeepRemote.
  ///
  /// In en, this message translates to:
  /// **'Keep Remote'**
  String get syncConflictKeepRemote;

  /// Purpose: Return the localized string for `trayShow`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @trayShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get trayShow;

  /// Purpose: Return the localized string for `trayQuit`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @trayQuit.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get trayQuit;

  /// Purpose: Return the localized string for `settingsMinimizeToTray`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsMinimizeToTray.
  ///
  /// In en, this message translates to:
  /// **'Minimize to Tray'**
  String get settingsMinimizeToTray;

  /// Purpose: Return the localized string for `settingsCloseToTray`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsCloseToTray.
  ///
  /// In en, this message translates to:
  /// **'Close to Tray'**
  String get settingsCloseToTray;

  /// Purpose: Return the localized string for `settingsAutoStart`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsAutoStart.
  ///
  /// In en, this message translates to:
  /// **'Launch at Startup'**
  String get settingsAutoStart;

  /// Purpose: Return the localized string for `settingsApiServer`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsApiServer.
  ///
  /// In en, this message translates to:
  /// **'API Server Settings'**
  String get settingsApiServer;

  /// Purpose: Return the localized string for `settingsApiEnabled`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsApiEnabled.
  ///
  /// In en, this message translates to:
  /// **'Local API Server'**
  String get settingsApiEnabled;

  /// Purpose: Return the localized string for `settingsApiListenAddress`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsApiListenAddress.
  ///
  /// In en, this message translates to:
  /// **'Listen Address'**
  String get settingsApiListenAddress;

  /// Purpose: Return the localized string for `settingsApiPort`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsApiPort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get settingsApiPort;

  /// Purpose: Return the localized string for `settingsApiUsername`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsApiUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get settingsApiUsername;

  /// Purpose: Return the localized string for `settingsApiPassword`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsApiPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get settingsApiPassword;

  /// Purpose: Return the localized string for `settingsApiRunning`.
  /// Inputs: `port`.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsApiRunning.
  ///
  /// In en, this message translates to:
  /// **'Running on port {port}'**
  String settingsApiRunning(int port);

  /// Purpose: Return the localized string for `settingsApiStopped`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsApiStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get settingsApiStopped;

  /// Purpose: Return the localized string for `settingsApiNeedCredentials`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsApiNeedCredentials.
  ///
  /// In en, this message translates to:
  /// **'Set username and password before listening on non-localhost'**
  String get settingsApiNeedCredentials;

  /// Purpose: Return the localized string for `settingsApiRestarted`.
  /// Inputs: `port`.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsApiRestarted.
  ///
  /// In en, this message translates to:
  /// **'API server restarted on port {port}'**
  String settingsApiRestarted(int port);

  /// Purpose: Return the localized string for `settingsDesktop`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsDesktop.
  ///
  /// In en, this message translates to:
  /// **'Desktop'**
  String get settingsDesktop;

  /// Purpose: Return the localized string for `lifecycleAndFinance`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @lifecycleAndFinance.
  ///
  /// In en, this message translates to:
  /// **'Lifecycle & Finance'**
  String get lifecycleAndFinance;

  /// Purpose: Return the localized string for `deviceStatus`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deviceStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get deviceStatus;

  /// Purpose: Return the localized string for `statusInService`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @statusInService.
  ///
  /// In en, this message translates to:
  /// **'In Service'**
  String get statusInService;

  /// Purpose: Return the localized string for `statusRetired`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @statusRetired.
  ///
  /// In en, this message translates to:
  /// **'Retired'**
  String get statusRetired;

  /// Purpose: Return the localized string for `statusSold`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @statusSold.
  ///
  /// In en, this message translates to:
  /// **'Sold'**
  String get statusSold;

  /// Purpose: Return the localized string for `filterAll`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// Purpose: Return the localized string for `deviceRetired`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deviceRetired.
  ///
  /// In en, this message translates to:
  /// **'Retired'**
  String get deviceRetired;

  /// Purpose: Return the localized string for `deviceRetiredDate`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deviceRetiredDate.
  ///
  /// In en, this message translates to:
  /// **'Retirement Date'**
  String get deviceRetiredDate;

  /// Purpose: Return the localized string for `deviceSold`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deviceSold.
  ///
  /// In en, this message translates to:
  /// **'Sold'**
  String get deviceSold;

  /// Purpose: Return the localized string for `acquisitionType`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @acquisitionType.
  ///
  /// In en, this message translates to:
  /// **'Acquisition Type'**
  String get acquisitionType;

  /// Purpose: Return the localized string for `acquisitionPurchased`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @acquisitionPurchased.
  ///
  /// In en, this message translates to:
  /// **'One-time Purchase'**
  String get acquisitionPurchased;

  /// Purpose: Return the localized string for `acquisitionLeased`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @acquisitionLeased.
  ///
  /// In en, this message translates to:
  /// **'Lease'**
  String get acquisitionLeased;

  /// Purpose: Return the localized string for `acquisitionPurchasedWithSubscription`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @acquisitionPurchasedWithSubscription.
  ///
  /// In en, this message translates to:
  /// **'Purchase + Subscription'**
  String get acquisitionPurchasedWithSubscription;

  /// Purpose: Return the localized string for `acquisitionOther`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @acquisitionOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get acquisitionOther;

  /// Purpose: Return the localized string for `optionalNone`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @optionalNone.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get optionalNone;

  /// Purpose: Return the localized string for `purchasePrice`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @purchasePrice.
  ///
  /// In en, this message translates to:
  /// **'Purchase Price'**
  String get purchasePrice;

  /// Purpose: Return the localized string for `soldPrice`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @soldPrice.
  ///
  /// In en, this message translates to:
  /// **'Sold Price'**
  String get soldPrice;

  /// Purpose: Return the localized string for `priceAmount`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @priceAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get priceAmount;

  /// Purpose: Return the localized string for `exchangeRateAuto`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @exchangeRateAuto.
  ///
  /// In en, this message translates to:
  /// **'Use automatic exchange rate'**
  String get exchangeRateAuto;

  /// Purpose: Return the localized string for `exchangeRateAutoDisabled`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @exchangeRateAutoDisabled.
  ///
  /// In en, this message translates to:
  /// **'Automatic updates are disabled in Settings; saved rates or fallback rates will be used.'**
  String get exchangeRateAutoDisabled;

  /// Purpose: Return the localized string for `exchangeRateManual`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @exchangeRateManual.
  ///
  /// In en, this message translates to:
  /// **'Manual Exchange Rate'**
  String get exchangeRateManual;

  /// Purpose: Return the localized string for `exchangeRateManualHint`.
  /// Inputs: `from`, `to`.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @exchangeRateManualHint.
  ///
  /// In en, this message translates to:
  /// **'1 {from} = ? {to}'**
  String exchangeRateManualHint(String from, String to);

  /// Purpose: Return the localized string for `exchangeRateManualRequired`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @exchangeRateManualRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a manual exchange rate.'**
  String get exchangeRateManualRequired;

  /// Purpose: Return the localized string for `exchangeRateUnavailable`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @exchangeRateUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Exchange rate unavailable. Try refreshing rates or enter a manual rate.'**
  String get exchangeRateUnavailable;

  /// Purpose: Return the localized string for `recurringCosts`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @recurringCosts.
  ///
  /// In en, this message translates to:
  /// **'Recurring Costs'**
  String get recurringCosts;

  /// Purpose: Return the localized string for `recurringCostType`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @recurringCostType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get recurringCostType;

  /// Purpose: Return the localized string for `recurringCostName`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @recurringCostName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get recurringCostName;

  /// Purpose: Return the localized string for `recurringCostNameHint`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @recurringCostNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. AppleCare+, lease payment'**
  String get recurringCostNameHint;

  /// Purpose: Return the localized string for `recurringCostPrice`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @recurringCostPrice.
  ///
  /// In en, this message translates to:
  /// **'Recurring Price'**
  String get recurringCostPrice;

  /// Purpose: Return the localized string for `recurringCostLease`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @recurringCostLease.
  ///
  /// In en, this message translates to:
  /// **'Lease'**
  String get recurringCostLease;

  /// Purpose: Return the localized string for `recurringCostInsurance`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @recurringCostInsurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get recurringCostInsurance;

  /// Purpose: Return the localized string for `recurringCostSubscription`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @recurringCostSubscription.
  ///
  /// In en, this message translates to:
  /// **'Subscription'**
  String get recurringCostSubscription;

  /// Purpose: Return the localized string for `recurringCostOther`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @recurringCostOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get recurringCostOther;

  /// Purpose: Return the localized string for `billingCycle`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @billingCycle.
  ///
  /// In en, this message translates to:
  /// **'Billing Cycle'**
  String get billingCycle;

  /// Purpose: Return the localized string for `billingMonthly`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @billingMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get billingMonthly;

  /// Purpose: Return the localized string for `billingYearly`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @billingYearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get billingYearly;

  /// Purpose: Return the localized string for `financialOverview`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @financialOverview.
  ///
  /// In en, this message translates to:
  /// **'Financial Overview'**
  String get financialOverview;

  /// Purpose: Return the localized string for `financialTotalCost`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @financialTotalCost.
  ///
  /// In en, this message translates to:
  /// **'Total Cost'**
  String get financialTotalCost;

  /// Purpose: Return the localized string for `financialDailyCost`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @financialDailyCost.
  ///
  /// In en, this message translates to:
  /// **'Daily Cost'**
  String get financialDailyCost;

  /// Purpose: Return the localized string for `financialAssetDistribution`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @financialAssetDistribution.
  ///
  /// In en, this message translates to:
  /// **'Asset Distribution'**
  String get financialAssetDistribution;

  /// Purpose: Return the localized string for `financialDailyCostLogTrend`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @financialDailyCostLogTrend.
  ///
  /// In en, this message translates to:
  /// **'Daily Cost Trend (Log)'**
  String get financialDailyCostLogTrend;

  /// Purpose: Return the localized string for `financialDevicesWithFinance`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @financialDevicesWithFinance.
  ///
  /// In en, this message translates to:
  /// **'Tracked'**
  String get financialDevicesWithFinance;

  /// Purpose: Return the localized string for `financialHistory`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @financialHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get financialHistory;

  /// Purpose: Return the localized string for `financialFutureTrend`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @financialFutureTrend.
  ///
  /// In en, this message translates to:
  /// **'Future Trend'**
  String get financialFutureTrend;

  /// Purpose: Return the localized string for `financialRange1Year`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @financialRange1Year.
  ///
  /// In en, this message translates to:
  /// **'1Y'**
  String get financialRange1Year;

  /// Purpose: Return the localized string for `financialRange3Years`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @financialRange3Years.
  ///
  /// In en, this message translates to:
  /// **'3Y'**
  String get financialRange3Years;

  /// Purpose: Return the localized string for `financialRangeAll`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @financialRangeAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get financialRangeAll;

  /// Purpose: Return the localized string for `financialNoData`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @financialNoData.
  ///
  /// In en, this message translates to:
  /// **'No financial data'**
  String get financialNoData;

  /// Purpose: Return the localized string for `settingsDefaultCurrency`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsDefaultCurrency.
  ///
  /// In en, this message translates to:
  /// **'Default Currency'**
  String get settingsDefaultCurrency;

  /// Purpose: Return the localized string for `settingsAutoUpdateExchangeRates`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsAutoUpdateExchangeRates.
  ///
  /// In en, this message translates to:
  /// **'Auto-update Exchange Rates'**
  String get settingsAutoUpdateExchangeRates;

  /// Purpose: Return the localized string for `settingsRefreshExchangeRates`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @settingsRefreshExchangeRates.
  ///
  /// In en, this message translates to:
  /// **'Refresh Exchange Rates'**
  String get settingsRefreshExchangeRates;

  /// Purpose: Return the localized string for `exchangeRateUpdated`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @exchangeRateUpdated.
  ///
  /// In en, this message translates to:
  /// **'Exchange rates updated'**
  String get exchangeRateUpdated;

  /// Purpose: Return the localized string for `exchangeRateUpdateFailed`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @exchangeRateUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update exchange rates'**
  String get exchangeRateUpdateFailed;

  /// Purpose: Return the localized string for `navServices`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @navServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get navServices;

  /// Purpose: Return the localized string for `servicesOverview`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @servicesOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get servicesOverview;

  /// Purpose: Return the localized string for `servicesByDevice`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @servicesByDevice.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get servicesByDevice;

  /// Purpose: Return the localized string for `serviceRoutes`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceRoutes.
  ///
  /// In en, this message translates to:
  /// **'Routes'**
  String get serviceRoutes;

  /// Purpose: Return the localized string for `servicePorts`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @servicePorts.
  ///
  /// In en, this message translates to:
  /// **'Ports'**
  String get servicePorts;

  /// Purpose: Return the localized string for `noServices`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @noServices.
  ///
  /// In en, this message translates to:
  /// **'No services yet. Add a device service to track ports and routes.'**
  String get noServices;

  /// Purpose: Return the localized string for `noServiceRoutes`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @noServiceRoutes.
  ///
  /// In en, this message translates to:
  /// **'No service routes yet.'**
  String get noServiceRoutes;

  /// Purpose: Return the localized string for `addService`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @addService.
  ///
  /// In en, this message translates to:
  /// **'Add Service'**
  String get addService;

  /// Purpose: Return the localized string for `editService`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @editService.
  ///
  /// In en, this message translates to:
  /// **'Edit Service'**
  String get editService;

  /// Purpose: Return the localized string for `deleteService`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deleteService.
  ///
  /// In en, this message translates to:
  /// **'Delete Service'**
  String get deleteService;

  /// Purpose: Return the localized string for `deleteServiceConfirm`.
  /// Inputs: `name`.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deleteServiceConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete service \"{name}\"? Routes from this service will also be removed.'**
  String deleteServiceConfirm(String name);

  /// Purpose: Return the localized string for `serviceName`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceName.
  ///
  /// In en, this message translates to:
  /// **'Service Name'**
  String get serviceName;

  /// Purpose: Return the localized string for `serviceNameRequired`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a service name.'**
  String get serviceNameRequired;

  /// Purpose: Return the localized string for `serviceDevice`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get serviceDevice;

  /// Purpose: Return the localized string for `serviceTemplate`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceTemplate.
  ///
  /// In en, this message translates to:
  /// **'Template'**
  String get serviceTemplate;

  /// Purpose: Return the localized string for `serviceCustom`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom Service'**
  String get serviceCustom;

  /// Purpose: Return the localized string for `servicePickTemplate`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @servicePickTemplate.
  ///
  /// In en, this message translates to:
  /// **'Pick Service Template'**
  String get servicePickTemplate;

  /// Purpose: Return the localized string for `serviceCustomTemplateDesc`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceCustomTemplateDesc.
  ///
  /// In en, this message translates to:
  /// **'Start from a blank service record'**
  String get serviceCustomTemplateDesc;

  /// Purpose: Return the localized string for `serviceFeaturedTemplate`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceFeaturedTemplate.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get serviceFeaturedTemplate;

  /// Purpose: Return the localized string for `serviceIcon`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceIcon.
  ///
  /// In en, this message translates to:
  /// **'Icon Name'**
  String get serviceIcon;

  /// Purpose: Return the localized string for `serviceKind`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceKind.
  ///
  /// In en, this message translates to:
  /// **'Kind'**
  String get serviceKind;

  /// Purpose: Return the localized string for `serviceRuntime`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceRuntime.
  ///
  /// In en, this message translates to:
  /// **'Runtime'**
  String get serviceRuntime;

  /// Purpose: Return the localized string for `serviceState`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceState.
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get serviceState;

  /// Purpose: Return the localized string for `serviceEndpoints`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceEndpoints.
  ///
  /// In en, this message translates to:
  /// **'Endpoints'**
  String get serviceEndpoints;

  /// Purpose: Return the localized string for `serviceEndpoint`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Endpoint'**
  String get serviceEndpoint;

  /// Purpose: Return the localized string for `addServiceEndpoint`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @addServiceEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Add Endpoint'**
  String get addServiceEndpoint;

  /// Purpose: Return the localized string for `editServiceEndpoint`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @editServiceEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Edit Endpoint'**
  String get editServiceEndpoint;

  /// Purpose: Return the localized string for `serviceEndpointLabel`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceEndpointLabel.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get serviceEndpointLabel;

  /// Purpose: Return the localized string for `serviceProtocol`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceProtocol.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get serviceProtocol;

  /// Purpose: Return the localized string for `serviceTransport`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceTransport.
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get serviceTransport;

  /// Purpose: Return the localized string for `servicePort`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @servicePort.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get servicePort;

  /// Purpose: Return the localized string for `servicePortEnd`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @servicePortEnd.
  ///
  /// In en, this message translates to:
  /// **'Port End'**
  String get servicePortEnd;

  /// Purpose: Return the localized string for `serviceBindAddress`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceBindAddress.
  ///
  /// In en, this message translates to:
  /// **'Bind Address'**
  String get serviceBindAddress;

  /// Purpose: Return the localized string for `servicePath`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @servicePath.
  ///
  /// In en, this message translates to:
  /// **'Path'**
  String get servicePath;

  /// Purpose: Return the localized string for `serviceScope`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceScope.
  ///
  /// In en, this message translates to:
  /// **'Scope'**
  String get serviceScope;

  /// Purpose: Return the localized string for `servicePrimaryEndpoint`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @servicePrimaryEndpoint.
  ///
  /// In en, this message translates to:
  /// **'Primary endpoint'**
  String get servicePrimaryEndpoint;

  /// Purpose: Return the localized string for `serviceDockerCompose`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceDockerCompose.
  ///
  /// In en, this message translates to:
  /// **'Docker Compose'**
  String get serviceDockerCompose;

  /// Purpose: Return the localized string for `copyServiceCompose`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @copyServiceCompose.
  ///
  /// In en, this message translates to:
  /// **'Copy Compose'**
  String get copyServiceCompose;

  /// Purpose: Return the localized string for `serviceComposeCopied`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceComposeCopied.
  ///
  /// In en, this message translates to:
  /// **'Docker Compose copied'**
  String get serviceComposeCopied;

  /// Purpose: Return the localized string for `addServiceRoute`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @addServiceRoute.
  ///
  /// In en, this message translates to:
  /// **'Add Route'**
  String get addServiceRoute;

  /// Purpose: Return the localized string for `editServiceRoute`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @editServiceRoute.
  ///
  /// In en, this message translates to:
  /// **'Edit Route'**
  String get editServiceRoute;

  /// Purpose: Return the localized string for `deleteServiceRoute`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deleteServiceRoute.
  ///
  /// In en, this message translates to:
  /// **'Delete Route'**
  String get deleteServiceRoute;

  /// Purpose: Return the localized string for `deleteServiceRouteConfirm`.
  /// Inputs: `name`.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @deleteServiceRouteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete route \"{name}\"?'**
  String deleteServiceRouteConfirm(String name);

  /// Purpose: Return the localized string for `serviceRouteName`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceRouteName.
  ///
  /// In en, this message translates to:
  /// **'Route Name'**
  String get serviceRouteName;

  /// Purpose: Return the localized string for `routeSourceService`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @routeSourceService.
  ///
  /// In en, this message translates to:
  /// **'Source Service'**
  String get routeSourceService;

  /// Purpose: Return the localized string for `serviceAccessLevel`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceAccessLevel.
  ///
  /// In en, this message translates to:
  /// **'Access Level'**
  String get serviceAccessLevel;

  /// Purpose: Return the localized string for `serviceFinalUrl`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceFinalUrl.
  ///
  /// In en, this message translates to:
  /// **'Final URL / Address'**
  String get serviceFinalUrl;

  /// Purpose: Return the localized string for `serviceAddAccess`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceAddAccess.
  ///
  /// In en, this message translates to:
  /// **'Add Access'**
  String get serviceAddAccess;

  /// Purpose: Return the localized string for `serviceAdvancedRoute`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceAdvancedRoute.
  ///
  /// In en, this message translates to:
  /// **'Advanced Route'**
  String get serviceAdvancedRoute;

  /// Purpose: Return the localized string for `serviceTopology`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceTopology.
  ///
  /// In en, this message translates to:
  /// **'Service Topology'**
  String get serviceTopology;

  /// Purpose: Return the localized string for `serviceTopologyHint`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceTopologyHint.
  ///
  /// In en, this message translates to:
  /// **'Open the topology for node details, zooming, rotation, or PNG export.'**
  String get serviceTopologyHint;

  /// Purpose: Return the localized string for `serviceOpenTopology`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceOpenTopology.
  ///
  /// In en, this message translates to:
  /// **'Open Topology'**
  String get serviceOpenTopology;

  /// Purpose: Return the localized string for `serviceTopologySelectMode`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceTopologySelectMode.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get serviceTopologySelectMode;

  /// Purpose: Return the localized string for `serviceTopologyMoveMode`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceTopologyMoveMode.
  ///
  /// In en, this message translates to:
  /// **'Move / Zoom'**
  String get serviceTopologyMoveMode;

  /// Purpose: Return the localized string for `serviceRotateTopology`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceRotateTopology.
  ///
  /// In en, this message translates to:
  /// **'Rotate topology'**
  String get serviceRotateTopology;

  /// Purpose: Return the localized string for `serviceExportTopologyImage`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceExportTopologyImage.
  ///
  /// In en, this message translates to:
  /// **'Export PNG'**
  String get serviceExportTopologyImage;

  /// Purpose: Return the localized string for `shareCopy`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @shareCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get shareCopy;

  /// Purpose: Return the localized string for `shareCopied`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @shareCopied.
  ///
  /// In en, this message translates to:
  /// **'Image copied to clipboard'**
  String get shareCopied;

  /// Purpose: Return the localized string for `shareSaveAs`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @shareSaveAs.
  ///
  /// In en, this message translates to:
  /// **'Save As'**
  String get shareSaveAs;

  /// Purpose: Return the localized string for `shareSaved`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @shareSaved.
  ///
  /// In en, this message translates to:
  /// **'Image saved'**
  String get shareSaved;

  /// Purpose: Return the localized string for `shareFailed`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @shareFailed.
  ///
  /// In en, this message translates to:
  /// **'Share failed'**
  String get shareFailed;

  /// Purpose: Return the localized string for `serviceAccessMethod`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceAccessMethod.
  ///
  /// In en, this message translates to:
  /// **'Access Method'**
  String get serviceAccessMethod;

  /// Purpose: Return the localized string for `serviceRelayService`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceRelayService.
  ///
  /// In en, this message translates to:
  /// **'Relay / Proxy Service'**
  String get serviceRelayService;

  /// Purpose: Return the localized string for `serviceRemoteDevice`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceRemoteDevice.
  ///
  /// In en, this message translates to:
  /// **'Remote Device / VPS'**
  String get serviceRemoteDevice;

  /// Purpose: Return the localized string for `serviceRemoteHost`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceRemoteHost.
  ///
  /// In en, this message translates to:
  /// **'Remote Host / IP'**
  String get serviceRemoteHost;

  /// Purpose: Return the localized string for `serviceRemotePort`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceRemotePort.
  ///
  /// In en, this message translates to:
  /// **'Remote Port'**
  String get serviceRemotePort;

  /// Purpose: Return the localized string for `serviceRemotePortRequired`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceRemotePortRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid remote port.'**
  String get serviceRemotePortRequired;

  /// Purpose: Return the localized string for `serviceDomains`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceDomains.
  ///
  /// In en, this message translates to:
  /// **'Domains / Public Targets'**
  String get serviceDomains;

  /// Purpose: Return the localized string for `serviceDomainsHint`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceDomainsHint.
  ///
  /// In en, this message translates to:
  /// **'Optional for port mappings. Enter one domain per line or separate with commas.'**
  String get serviceDomainsHint;

  /// Purpose: Return the localized string for `serviceAccessTargetsHint`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceAccessTargetsHint.
  ///
  /// In en, this message translates to:
  /// **'Enter one URL or address per line. Multiple entries stay together on the same access route.'**
  String get serviceAccessTargetsHint;

  /// Purpose: Return the localized string for `serviceAccessTargetRequired`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceAccessTargetRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter at least one URL or address.'**
  String get serviceAccessTargetRequired;

  /// Purpose: Return the localized string for `routeHops`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @routeHops.
  ///
  /// In en, this message translates to:
  /// **'Route Hops'**
  String get routeHops;

  /// Purpose: Return the localized string for `addRouteHop`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @addRouteHop.
  ///
  /// In en, this message translates to:
  /// **'Add Hop'**
  String get addRouteHop;

  /// Purpose: Return the localized string for `editRouteHop`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @editRouteHop.
  ///
  /// In en, this message translates to:
  /// **'Edit Hop'**
  String get editRouteHop;

  /// Purpose: Return the localized string for `routeHopType`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @routeHopType.
  ///
  /// In en, this message translates to:
  /// **'Hop Type'**
  String get routeHopType;

  /// Purpose: Return the localized string for `routeMethod`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @routeMethod.
  ///
  /// In en, this message translates to:
  /// **'Method'**
  String get routeMethod;

  /// Purpose: Return the localized string for `routeHopService`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @routeHopService.
  ///
  /// In en, this message translates to:
  /// **'Hop Service'**
  String get routeHopService;

  /// Purpose: Return the localized string for `routeManualHop`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @routeManualHop.
  ///
  /// In en, this message translates to:
  /// **'Manual Hop'**
  String get routeManualHop;

  /// Purpose: Return the localized string for `routeHopLabel`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @routeHopLabel.
  ///
  /// In en, this message translates to:
  /// **'Hop Label'**
  String get routeHopLabel;

  /// Purpose: Return the localized string for `routeScheme`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @routeScheme.
  ///
  /// In en, this message translates to:
  /// **'Scheme'**
  String get routeScheme;

  /// Purpose: Return the localized string for `routeHost`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @routeHost.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get routeHost;

  /// Purpose: Return the localized string for `activeServices`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @activeServices.
  ///
  /// In en, this message translates to:
  /// **'Active Services'**
  String get activeServices;

  /// Purpose: Return the localized string for `serviceDevices`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get serviceDevices;

  /// Purpose: Return the localized string for `publicRoutes`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @publicRoutes.
  ///
  /// In en, this message translates to:
  /// **'Public Routes'**
  String get publicRoutes;

  /// Purpose: Return the localized string for `serviceWarnings`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceWarnings.
  ///
  /// In en, this message translates to:
  /// **'Warnings'**
  String get serviceWarnings;

  /// Purpose: Return the localized string for `servicePortConflicts`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @servicePortConflicts.
  ///
  /// In en, this message translates to:
  /// **'Port Conflicts'**
  String get servicePortConflicts;

  /// Purpose: Return the localized string for `servicePortUsage`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @servicePortUsage.
  ///
  /// In en, this message translates to:
  /// **'Port Usage'**
  String get servicePortUsage;

  /// Purpose: Return the localized string for `servicePotentialConflict`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @servicePotentialConflict.
  ///
  /// In en, this message translates to:
  /// **'potential'**
  String get servicePotentialConflict;

  /// Purpose: Return the localized string for `serviceAnyAddress`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceAnyAddress.
  ///
  /// In en, this message translates to:
  /// **'Any Address'**
  String get serviceAnyAddress;

  /// Purpose: Return the localized string for `servicePortConflict`.
  /// Inputs: `device`, `port`.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @servicePortConflict.
  ///
  /// In en, this message translates to:
  /// **'{device}: port {port} may be used by multiple services'**
  String servicePortConflict(String device, int port);

  /// Purpose: Return the localized string for `serviceRoutePreview`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceRoutePreview.
  ///
  /// In en, this message translates to:
  /// **'Route Preview'**
  String get serviceRoutePreview;

  /// Purpose: Return the localized string for `serviceMoveUp`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move Up'**
  String get serviceMoveUp;

  /// Purpose: Return the localized string for `serviceMoveDown`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move Down'**
  String get serviceMoveDown;

  /// Purpose: Return the localized string for `serviceWarningMissingDevice`.
  /// Inputs: `name`.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceWarningMissingDevice.
  ///
  /// In en, this message translates to:
  /// **'{name}: missing device'**
  String serviceWarningMissingDevice(String name);

  /// Purpose: Return the localized string for `serviceWarningInactiveDevice`.
  /// Inputs: `name`.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceWarningInactiveDevice.
  ///
  /// In en, this message translates to:
  /// **'{name}: device is not in service'**
  String serviceWarningInactiveDevice(String name);

  /// Purpose: Return the localized string for `serviceWarningMissingNetwork`.
  /// Inputs: `name`.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceWarningMissingNetwork.
  ///
  /// In en, this message translates to:
  /// **'{name}: missing endpoint network'**
  String serviceWarningMissingNetwork(String name);

  /// Purpose: Return the localized string for `serviceWarningMissingSource`.
  /// Inputs: `name`.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceWarningMissingSource.
  ///
  /// In en, this message translates to:
  /// **'{name}: missing source service'**
  String serviceWarningMissingSource(String name);

  /// Purpose: Return the localized string for `serviceWarningMissingSourceEndpoint`.
  /// Inputs: `name`.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceWarningMissingSourceEndpoint.
  ///
  /// In en, this message translates to:
  /// **'{name}: missing source endpoint'**
  String serviceWarningMissingSourceEndpoint(String name);

  /// Purpose: Return the localized string for `serviceWarningMissingHopService`.
  /// Inputs: `name`.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceWarningMissingHopService.
  ///
  /// In en, this message translates to:
  /// **'{name}: missing hop service'**
  String serviceWarningMissingHopService(String name);

  /// Purpose: Return the localized string for `serviceWarningMissingHopEndpoint`.
  /// Inputs: `name`.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceWarningMissingHopEndpoint.
  ///
  /// In en, this message translates to:
  /// **'{name}: missing hop endpoint'**
  String serviceWarningMissingHopEndpoint(String name);

  /// Purpose: Return the localized string for `serviceWarningMissingHopDevice`.
  /// Inputs: `name`.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceWarningMissingHopDevice.
  ///
  /// In en, this message translates to:
  /// **'{name}: missing hop device'**
  String serviceWarningMissingHopDevice(String name);

  /// Purpose: Return the localized string for `serviceWarningEmptyRoute`.
  /// Inputs: `name`.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceWarningEmptyRoute.
  ///
  /// In en, this message translates to:
  /// **'{name}: route has no hops'**
  String serviceWarningEmptyRoute(String name);

  /// Purpose: Return the localized string for `serviceWarningPublicRouteMissingUrl`.
  /// Inputs: `name`.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceWarningPublicRouteMissingUrl.
  ///
  /// In en, this message translates to:
  /// **'{name}: public route has no final URL'**
  String serviceWarningPublicRouteMissingUrl(String name);

  /// Purpose: Return the localized string for `serviceWarningDuplicateFinalUrl`.
  /// Inputs: `name`.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceWarningDuplicateFinalUrl.
  ///
  /// In en, this message translates to:
  /// **'{name}: duplicate final URL'**
  String serviceWarningDuplicateFinalUrl(String name);

  /// Purpose: Return the localized string for `serviceCount`.
  /// Inputs: `count`.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceCount.
  ///
  /// In en, this message translates to:
  /// **'{count} service(s)'**
  String serviceCount(int count);

  /// Purpose: Return the localized string for `serviceRouteCount`.
  /// Inputs: `count`.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @serviceRouteCount.
  ///
  /// In en, this message translates to:
  /// **'{count} route(s)'**
  String serviceRouteCount(int count);

  /// Purpose: Return the localized string for `backupModuleServices`.
  /// Inputs: None.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  /// No description provided for @backupModuleServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get backupModuleServices;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  /// Purpose: Create an app localizations delegate instance.
  /// Inputs: None.
  /// Returns: A new `_AppLocalizationsDelegate` instance.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  const _AppLocalizationsDelegate();

  /// Purpose: Return the localized string for `load`.
  /// Inputs: `locale`.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  /// Purpose: Return the localized string for `isSupported`.
  /// Inputs: `locale`.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'zh'].contains(locale.languageCode);

  /// Purpose: Return the localized string for `shouldReload`.
  /// Inputs: `old`.
  /// Returns: A localized `String`.
  /// Side effects: None.
  /// Notes: Generated localization accessor or override.
  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// Purpose: Return the localized string for `lookupAppLocalizations`.
/// Inputs: `locale`.
/// Returns: A localized `String`.
/// Side effects: None.
/// Notes: Generated localization accessor or override.
AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
