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
    Locale('ja'),
    Locale('zh'),
    Locale('zh', 'TW'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'MyDevice!!!!!'**
  String get appTitle;

  /// No description provided for @navDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get navDevices;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @deviceCategoryDesktop.
  ///
  /// In en, this message translates to:
  /// **'Desktop'**
  String get deviceCategoryDesktop;

  /// No description provided for @deviceCategoryLaptop.
  ///
  /// In en, this message translates to:
  /// **'Laptop'**
  String get deviceCategoryLaptop;

  /// No description provided for @deviceCategoryPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get deviceCategoryPhone;

  /// No description provided for @deviceCategoryTablet.
  ///
  /// In en, this message translates to:
  /// **'Tablet'**
  String get deviceCategoryTablet;

  /// No description provided for @deviceCategoryHeadphone.
  ///
  /// In en, this message translates to:
  /// **'Headphone'**
  String get deviceCategoryHeadphone;

  /// No description provided for @deviceCategoryWatch.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get deviceCategoryWatch;

  /// No description provided for @deviceCategoryRouter.
  ///
  /// In en, this message translates to:
  /// **'Router'**
  String get deviceCategoryRouter;

  /// No description provided for @deviceCategoryGameConsole.
  ///
  /// In en, this message translates to:
  /// **'Game Console'**
  String get deviceCategoryGameConsole;

  /// No description provided for @deviceCategoryVps.
  ///
  /// In en, this message translates to:
  /// **'VPS'**
  String get deviceCategoryVps;

  /// No description provided for @deviceCategoryDevBoard.
  ///
  /// In en, this message translates to:
  /// **'Dev Board'**
  String get deviceCategoryDevBoard;

  /// No description provided for @deviceCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get deviceCategoryOther;

  /// No description provided for @deviceName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get deviceName;

  /// No description provided for @deviceBrand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get deviceBrand;

  /// No description provided for @deviceModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get deviceModel;

  /// No description provided for @deviceCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get deviceCategory;

  /// No description provided for @devicePurchaseDate.
  ///
  /// In en, this message translates to:
  /// **'Purchase Date'**
  String get devicePurchaseDate;

  /// No description provided for @deviceReleaseDate.
  ///
  /// In en, this message translates to:
  /// **'Release Date'**
  String get deviceReleaseDate;

  /// No description provided for @deviceNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get deviceNotes;

  /// No description provided for @deviceLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get deviceLocation;

  /// No description provided for @mapPickLocation.
  ///
  /// In en, this message translates to:
  /// **'Pick Location'**
  String get mapPickLocation;

  /// No description provided for @mapSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search location...'**
  String get mapSearchHint;

  /// No description provided for @cpuInfo.
  ///
  /// In en, this message translates to:
  /// **'CPU'**
  String get cpuInfo;

  /// No description provided for @cpuModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get cpuModel;

  /// No description provided for @cpuArchitecture.
  ///
  /// In en, this message translates to:
  /// **'Architecture'**
  String get cpuArchitecture;

  /// No description provided for @cpuFrequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get cpuFrequency;

  /// No description provided for @cpuPCores.
  ///
  /// In en, this message translates to:
  /// **'P-Cores'**
  String get cpuPCores;

  /// No description provided for @cpuECores.
  ///
  /// In en, this message translates to:
  /// **'E-Cores'**
  String get cpuECores;

  /// No description provided for @cpuThreads.
  ///
  /// In en, this message translates to:
  /// **'Threads'**
  String get cpuThreads;

  /// No description provided for @cpuCache.
  ///
  /// In en, this message translates to:
  /// **'Cache'**
  String get cpuCache;

  /// No description provided for @gpuInfo.
  ///
  /// In en, this message translates to:
  /// **'GPU'**
  String get gpuInfo;

  /// No description provided for @gpuModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get gpuModel;

  /// No description provided for @gpuArchitecture.
  ///
  /// In en, this message translates to:
  /// **'Architecture'**
  String get gpuArchitecture;

  /// No description provided for @ram.
  ///
  /// In en, this message translates to:
  /// **'RAM'**
  String get ram;

  /// No description provided for @storage.
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get storage;

  /// No description provided for @screenSize.
  ///
  /// In en, this message translates to:
  /// **'Screen Size'**
  String get screenSize;

  /// No description provided for @screenResolution.
  ///
  /// In en, this message translates to:
  /// **'Resolution'**
  String get screenResolution;

  /// No description provided for @ppi.
  ///
  /// In en, this message translates to:
  /// **'PPI'**
  String get ppi;

  /// No description provided for @battery.
  ///
  /// In en, this message translates to:
  /// **'Battery'**
  String get battery;

  /// No description provided for @os.
  ///
  /// In en, this message translates to:
  /// **'OS'**
  String get os;

  /// No description provided for @addDevice.
  ///
  /// In en, this message translates to:
  /// **'Add Device'**
  String get addDevice;

  /// No description provided for @editDevice.
  ///
  /// In en, this message translates to:
  /// **'Edit Device'**
  String get editDevice;

  /// No description provided for @deleteDevice.
  ///
  /// In en, this message translates to:
  /// **'Delete Device'**
  String get deleteDevice;

  /// No description provided for @deleteDeviceConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String deleteDeviceConfirm(String name);

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @noDevices.
  ///
  /// In en, this message translates to:
  /// **'No devices yet. Tap + to add one!'**
  String get noDevices;

  /// No description provided for @deviceDetail.
  ///
  /// In en, this message translates to:
  /// **'Device Detail'**
  String get deviceDetail;

  /// No description provided for @swipeEditHint.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get swipeEditHint;

  /// No description provided for @swipeDeleteHint.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get swipeDeleteHint;

  /// No description provided for @fromTemplate.
  ///
  /// In en, this message translates to:
  /// **'From Template'**
  String get fromTemplate;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @settingsData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsData;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacyPolicy;

  /// No description provided for @settingsLicense.
  ///
  /// In en, this message translates to:
  /// **'License (GPLv3)'**
  String get settingsLicense;

  /// No description provided for @settingsLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open Source Licenses'**
  String get settingsLicenses;

  /// No description provided for @backupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get backupTitle;

  /// No description provided for @backupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Full local backup (data + images)'**
  String get backupSubtitle;

  /// No description provided for @backupCreate.
  ///
  /// In en, this message translates to:
  /// **'Create Backup'**
  String get backupCreate;

  /// No description provided for @backupCreated.
  ///
  /// In en, this message translates to:
  /// **'Backup created'**
  String get backupCreated;

  /// No description provided for @backupAutoBackup.
  ///
  /// In en, this message translates to:
  /// **'Auto Backup'**
  String get backupAutoBackup;

  /// No description provided for @backupRetention.
  ///
  /// In en, this message translates to:
  /// **'Retention Period'**
  String get backupRetention;

  /// No description provided for @backupKeepForever.
  ///
  /// In en, this message translates to:
  /// **'Keep forever'**
  String get backupKeepForever;

  /// No description provided for @backupKeepDays.
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String backupKeepDays(int days);

  /// No description provided for @backupHistory.
  ///
  /// In en, this message translates to:
  /// **'History ({count})'**
  String backupHistory(int count);

  /// No description provided for @backupNoBackups.
  ///
  /// In en, this message translates to:
  /// **'No backups yet'**
  String get backupNoBackups;

  /// No description provided for @backupRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get backupRestore;

  /// No description provided for @backupRestoreConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will overwrite your current data. Continue?'**
  String get backupRestoreConfirm;

  /// No description provided for @backupRestored.
  ///
  /// In en, this message translates to:
  /// **'Backup restored'**
  String get backupRestored;

  /// No description provided for @backupRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Restore failed'**
  String get backupRestoreFailed;

  /// No description provided for @backupDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this backup?'**
  String get backupDeleteConfirm;

  /// No description provided for @exportData.
  ///
  /// In en, this message translates to:
  /// **'Export Data'**
  String get exportData;

  /// No description provided for @importData.
  ///
  /// In en, this message translates to:
  /// **'Import Data'**
  String get importData;

  /// No description provided for @exportSuccess.
  ///
  /// In en, this message translates to:
  /// **'Data exported successfully'**
  String get exportSuccess;

  /// No description provided for @importSuccess.
  ///
  /// In en, this message translates to:
  /// **'Data imported successfully'**
  String get importSuccess;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed'**
  String get importFailed;

  /// No description provided for @importConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will overwrite your current data. Continue?'**
  String get importConfirm;

  /// No description provided for @dataMigration.
  ///
  /// In en, this message translates to:
  /// **'Open Data Folder'**
  String get dataMigration;

  /// No description provided for @dataMigrationDesc.
  ///
  /// In en, this message translates to:
  /// **'Open the application data directory'**
  String get dataMigrationDesc;

  /// No description provided for @settingsStorageLocation.
  ///
  /// In en, this message translates to:
  /// **'Storage Location'**
  String get settingsStorageLocation;

  /// No description provided for @settingsStoragePathHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the directory path for storing data. Leave empty to use default.'**
  String get settingsStoragePathHint;

  /// No description provided for @settingsDirectoryPath.
  ///
  /// In en, this message translates to:
  /// **'Directory Path'**
  String get settingsDirectoryPath;

  /// No description provided for @settingsResetDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to Default'**
  String get settingsResetDefault;

  /// No description provided for @settingsResetDefaultLocation.
  ///
  /// In en, this message translates to:
  /// **'Reset to default location'**
  String get settingsResetDefaultLocation;

  /// No description provided for @settingsStoragePathUpdated.
  ///
  /// In en, this message translates to:
  /// **'Storage path updated'**
  String get settingsStoragePathUpdated;

  /// No description provided for @totalDevices.
  ///
  /// In en, this message translates to:
  /// **'{count} device(s)'**
  String totalDevices(int count);

  /// No description provided for @storageType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get storageType;

  /// No description provided for @storageInterface.
  ///
  /// In en, this message translates to:
  /// **'Interface'**
  String get storageInterface;

  /// No description provided for @storageTypeSsd.
  ///
  /// In en, this message translates to:
  /// **'SSD'**
  String get storageTypeSsd;

  /// No description provided for @storageTypeSdCard.
  ///
  /// In en, this message translates to:
  /// **'SD Card'**
  String get storageTypeSdCard;

  /// No description provided for @storageTypeHdd.
  ///
  /// In en, this message translates to:
  /// **'HDD'**
  String get storageTypeHdd;

  /// No description provided for @storageInterfaceM2Nvme.
  ///
  /// In en, this message translates to:
  /// **'M.2 NVMe'**
  String get storageInterfaceM2Nvme;

  /// No description provided for @storageInterfaceSata25.
  ///
  /// In en, this message translates to:
  /// **'2.5\" SATA'**
  String get storageInterfaceSata25;

  /// No description provided for @storageInterfaceM2Sata.
  ///
  /// In en, this message translates to:
  /// **'M.2 SATA'**
  String get storageInterfaceM2Sata;

  /// No description provided for @storageInterfaceUsb.
  ///
  /// In en, this message translates to:
  /// **'USB'**
  String get storageInterfaceUsb;

  /// No description provided for @ramType.
  ///
  /// In en, this message translates to:
  /// **'RAM Type'**
  String get ramType;

  /// No description provided for @sortTitle.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortTitle;

  /// No description provided for @sortCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom Order'**
  String get sortCustom;

  /// No description provided for @sortAlphabetical.
  ///
  /// In en, this message translates to:
  /// **'Alphabetical'**
  String get sortAlphabetical;

  /// No description provided for @sortPurchaseDate.
  ///
  /// In en, this message translates to:
  /// **'Purchase Date'**
  String get sortPurchaseDate;

  /// No description provided for @sortReleaseDate.
  ///
  /// In en, this message translates to:
  /// **'Release Date'**
  String get sortReleaseDate;

  /// No description provided for @sortAscending.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get sortAscending;

  /// No description provided for @sortSubnet.
  ///
  /// In en, this message translates to:
  /// **'Subnet'**
  String get sortSubnet;

  /// No description provided for @sortGroupByCategory.
  ///
  /// In en, this message translates to:
  /// **'Group by Category'**
  String get sortGroupByCategory;

  /// No description provided for @sortReorder.
  ///
  /// In en, this message translates to:
  /// **'Reorder...'**
  String get sortReorder;

  /// No description provided for @sortByIp.
  ///
  /// In en, this message translates to:
  /// **'IP Address'**
  String get sortByIp;

  /// No description provided for @sortExitNodeFirst.
  ///
  /// In en, this message translates to:
  /// **'Exit Nodes First'**
  String get sortExitNodeFirst;

  /// No description provided for @navNetworks.
  ///
  /// In en, this message translates to:
  /// **'Networks'**
  String get navNetworks;

  /// No description provided for @noNetworks.
  ///
  /// In en, this message translates to:
  /// **'No networks yet. Tap + to add one!'**
  String get noNetworks;

  /// No description provided for @addNetwork.
  ///
  /// In en, this message translates to:
  /// **'Add Network'**
  String get addNetwork;

  /// No description provided for @editNetwork.
  ///
  /// In en, this message translates to:
  /// **'Edit Network'**
  String get editNetwork;

  /// No description provided for @deleteNetwork.
  ///
  /// In en, this message translates to:
  /// **'Delete Network'**
  String get deleteNetwork;

  /// No description provided for @deleteNetworkConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will delete the network and all device assignments. Continue?'**
  String get deleteNetworkConfirm;

  /// No description provided for @networkName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get networkName;

  /// No description provided for @networkType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get networkType;

  /// No description provided for @networkSubnet.
  ///
  /// In en, this message translates to:
  /// **'Subnet'**
  String get networkSubnet;

  /// No description provided for @networkGateway.
  ///
  /// In en, this message translates to:
  /// **'Gateway'**
  String get networkGateway;

  /// No description provided for @networkDns.
  ///
  /// In en, this message translates to:
  /// **'DNS Servers'**
  String get networkDns;

  /// No description provided for @networkTypeLan.
  ///
  /// In en, this message translates to:
  /// **'LAN'**
  String get networkTypeLan;

  /// No description provided for @networkTypeTailscale.
  ///
  /// In en, this message translates to:
  /// **'Tailscale'**
  String get networkTypeTailscale;

  /// No description provided for @networkTypeZerotier.
  ///
  /// In en, this message translates to:
  /// **'ZeroTier'**
  String get networkTypeZerotier;

  /// No description provided for @networkTypeEasytier.
  ///
  /// In en, this message translates to:
  /// **'EasyTier'**
  String get networkTypeEasytier;

  /// No description provided for @networkTypeWireguard.
  ///
  /// In en, this message translates to:
  /// **'WireGuard'**
  String get networkTypeWireguard;

  /// No description provided for @networkTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get networkTypeOther;

  /// No description provided for @networkDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get networkDevices;

  /// No description provided for @noNetworkDevices.
  ///
  /// In en, this message translates to:
  /// **'No devices in this network yet.'**
  String get noNetworkDevices;

  /// No description provided for @networkDeviceConfig.
  ///
  /// In en, this message translates to:
  /// **'Device Config'**
  String get networkDeviceConfig;

  /// No description provided for @networkAddressMode.
  ///
  /// In en, this message translates to:
  /// **'Address Mode'**
  String get networkAddressMode;

  /// No description provided for @addressModeDhcp.
  ///
  /// In en, this message translates to:
  /// **'DHCP'**
  String get addressModeDhcp;

  /// No description provided for @addressModeStatic.
  ///
  /// In en, this message translates to:
  /// **'Static IP'**
  String get addressModeStatic;

  /// No description provided for @networkIpAddress.
  ///
  /// In en, this message translates to:
  /// **'IP Address'**
  String get networkIpAddress;

  /// No description provided for @networkHostname.
  ///
  /// In en, this message translates to:
  /// **'Hostname'**
  String get networkHostname;

  /// No description provided for @networkExitNode.
  ///
  /// In en, this message translates to:
  /// **'Exit Node'**
  String get networkExitNode;

  /// No description provided for @networkPickDevice.
  ///
  /// In en, this message translates to:
  /// **'Select Device'**
  String get networkPickDevice;

  /// No description provided for @removeDevice.
  ///
  /// In en, this message translates to:
  /// **'Remove Device'**
  String get removeDevice;

  /// No description provided for @removeDeviceConfirm.
  ///
  /// In en, this message translates to:
  /// **'Remove this device from the network?'**
  String get removeDeviceConfirm;

  /// No description provided for @settingsConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get settingsConfirm;

  /// No description provided for @settingsWebDAVSync.
  ///
  /// In en, this message translates to:
  /// **'WebDAV Sync'**
  String get settingsWebDAVSync;

  /// No description provided for @settingsWebDAVServerURL.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get settingsWebDAVServerURL;

  /// No description provided for @settingsWebDAVUsername.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get settingsWebDAVUsername;

  /// No description provided for @settingsWebDAVPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get settingsWebDAVPassword;

  /// No description provided for @settingsWebDAVRemotePath.
  ///
  /// In en, this message translates to:
  /// **'Remote Path'**
  String get settingsWebDAVRemotePath;

  /// No description provided for @settingsWebDAVNextcloud.
  ///
  /// In en, this message translates to:
  /// **'Nextcloud'**
  String get settingsWebDAVNextcloud;

  /// No description provided for @settingsWebDAVTestConnection.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get settingsWebDAVTestConnection;

  /// No description provided for @settingsWebDAVConnectionSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connection successful'**
  String get settingsWebDAVConnectionSuccess;

  /// No description provided for @settingsWebDAVConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get settingsWebDAVConnectionFailed;

  /// No description provided for @settingsWebDAVConfigSaved.
  ///
  /// In en, this message translates to:
  /// **'WebDAV configuration saved'**
  String get settingsWebDAVConfigSaved;

  /// No description provided for @settingsWebDAVSyncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get settingsWebDAVSyncNow;

  /// No description provided for @settingsWebDAVSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get settingsWebDAVSyncing;

  /// No description provided for @settingsWebDAVSyncSuccess.
  ///
  /// In en, this message translates to:
  /// **'Sync completed'**
  String get settingsWebDAVSyncSuccess;

  /// No description provided for @settingsWebDAVSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get settingsWebDAVSyncFailed;

  /// No description provided for @settingsWebDAVAutoSync.
  ///
  /// In en, this message translates to:
  /// **'Auto Sync'**
  String get settingsWebDAVAutoSync;

  /// No description provided for @settingsWebDAVAutoSyncDesc.
  ///
  /// In en, this message translates to:
  /// **'Sync automatically when data changes'**
  String get settingsWebDAVAutoSyncDesc;

  /// No description provided for @settingsWebDAVDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get settingsWebDAVDisconnect;

  /// No description provided for @settingsWebDAVConfigRemoved.
  ///
  /// In en, this message translates to:
  /// **'WebDAV configuration removed'**
  String get settingsWebDAVConfigRemoved;

  /// No description provided for @backupRestoreModules.
  ///
  /// In en, this message translates to:
  /// **'Select Modules to Restore'**
  String get backupRestoreModules;

  /// No description provided for @backupSelectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get backupSelectAll;

  /// No description provided for @backupModuleDevices.
  ///
  /// In en, this message translates to:
  /// **'Devices'**
  String get backupModuleDevices;

  /// No description provided for @backupModuleNetworks.
  ///
  /// In en, this message translates to:
  /// **'Networks'**
  String get backupModuleNetworks;

  /// No description provided for @backupModuleDatasets.
  ///
  /// In en, this message translates to:
  /// **'Data Sets'**
  String get backupModuleDatasets;

  /// No description provided for @navDataSets.
  ///
  /// In en, this message translates to:
  /// **'Data Sets'**
  String get navDataSets;

  /// No description provided for @noDataSets.
  ///
  /// In en, this message translates to:
  /// **'No data sets yet. Tap + to add one!'**
  String get noDataSets;

  /// No description provided for @addDataSet.
  ///
  /// In en, this message translates to:
  /// **'Add Data Set'**
  String get addDataSet;

  /// No description provided for @editDataSet.
  ///
  /// In en, this message translates to:
  /// **'Edit Data Set'**
  String get editDataSet;

  /// No description provided for @deleteDataSet.
  ///
  /// In en, this message translates to:
  /// **'Delete Data Set'**
  String get deleteDataSet;

  /// No description provided for @deleteDataSetConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String deleteDataSetConfirm(String name);

  /// No description provided for @dataSetName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get dataSetName;

  /// No description provided for @dataSetEmoji.
  ///
  /// In en, this message translates to:
  /// **'Emoji'**
  String get dataSetEmoji;

  /// No description provided for @dataSetStorages.
  ///
  /// In en, this message translates to:
  /// **'Linked Storages'**
  String get dataSetStorages;

  /// No description provided for @dataSetNoDeviceStorages.
  ///
  /// In en, this message translates to:
  /// **'No devices with storage found'**
  String get dataSetNoDeviceStorages;

  /// No description provided for @mapViewDevices.
  ///
  /// In en, this message translates to:
  /// **'Device Map'**
  String get mapViewDevices;

  /// No description provided for @mapViewNetworkDevices.
  ///
  /// In en, this message translates to:
  /// **'Network Device Map'**
  String get mapViewNetworkDevices;

  /// No description provided for @mapNoLocations.
  ///
  /// In en, this message translates to:
  /// **'No devices have location data set.'**
  String get mapNoLocations;

  /// No description provided for @deviceEmoji.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get deviceEmoji;

  /// No description provided for @deviceImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get deviceImage;

  /// No description provided for @devicePickImage.
  ///
  /// In en, this message translates to:
  /// **'Pick Image'**
  String get devicePickImage;

  /// No description provided for @deviceChangeImage.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get deviceChangeImage;

  /// No description provided for @deviceRemoveIcon.
  ///
  /// In en, this message translates to:
  /// **'Remove Icon'**
  String get deviceRemoveIcon;

  /// No description provided for @deviceSerialNumber.
  ///
  /// In en, this message translates to:
  /// **'Serial Number'**
  String get deviceSerialNumber;

  /// No description provided for @storageBrand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get storageBrand;

  /// No description provided for @storageSerialNumber.
  ///
  /// In en, this message translates to:
  /// **'Serial Number'**
  String get storageSerialNumber;

  /// No description provided for @fetchFromInternet.
  ///
  /// In en, this message translates to:
  /// **'Fetch Online'**
  String get fetchFromInternet;

  /// No description provided for @searchDeviceInfo.
  ///
  /// In en, this message translates to:
  /// **'Fetch Device Info'**
  String get searchDeviceInfo;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search device name...'**
  String get searchHint;

  /// No description provided for @searchButton.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get searchButton;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get searchNoResults;

  /// No description provided for @searchApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get searchApply;

  /// No description provided for @searchCurrent.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get searchCurrent;

  /// No description provided for @searchFetched.
  ///
  /// In en, this message translates to:
  /// **'Fetched'**
  String get searchFetched;

  /// No description provided for @searchDeviceImage.
  ///
  /// In en, this message translates to:
  /// **'Device Image'**
  String get searchDeviceImage;

  /// No description provided for @searchFetchImage.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get searchFetchImage;

  /// No description provided for @searchFetchingDetail.
  ///
  /// In en, this message translates to:
  /// **'Fetching details...'**
  String get searchFetchingDetail;

  /// No description provided for @searchCpuInfo.
  ///
  /// In en, this message translates to:
  /// **'Search CPU'**
  String get searchCpuInfo;

  /// No description provided for @searchGpuInfo.
  ///
  /// In en, this message translates to:
  /// **'Search GPU'**
  String get searchGpuInfo;

  /// No description provided for @searchCpuHint.
  ///
  /// In en, this message translates to:
  /// **'Enter CPU model...'**
  String get searchCpuHint;

  /// No description provided for @searchGpuHint.
  ///
  /// In en, this message translates to:
  /// **'Enter GPU model...'**
  String get searchGpuHint;
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
      <String>['en', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

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
