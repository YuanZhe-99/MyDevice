// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'MyDevice!!!!!';

  @override
  String get navDevices => 'Devices';

  @override
  String get navSettings => 'Settings';

  @override
  String get deviceCategoryDesktop => 'Desktop';

  @override
  String get deviceCategoryLaptop => 'Laptop';

  @override
  String get deviceCategoryPhone => 'Phone';

  @override
  String get deviceCategoryTablet => 'Tablet';

  @override
  String get deviceCategoryHeadphone => 'Headphone';

  @override
  String get deviceCategoryWatch => 'Watch';

  @override
  String get deviceCategoryRouter => 'Router';

  @override
  String get deviceCategoryGameConsole => 'Game Console';

  @override
  String get deviceCategoryVps => 'VPS';

  @override
  String get deviceCategoryDevBoard => 'Dev Board';

  @override
  String get deviceCategoryOther => 'Other';

  @override
  String get deviceName => 'Name';

  @override
  String get deviceBrand => 'Brand';

  @override
  String get deviceModel => 'Model';

  @override
  String get deviceCategory => 'Category';

  @override
  String get devicePurchaseDate => 'Purchase Date';

  @override
  String get deviceReleaseDate => 'Release Date';

  @override
  String get deviceNotes => 'Notes';

  @override
  String get deviceLocation => 'Location';

  @override
  String get mapPickLocation => 'Pick Location';

  @override
  String get mapSearchHint => 'Search location...';

  @override
  String get cpuInfo => 'CPU';

  @override
  String get cpuModel => 'Model';

  @override
  String get cpuArchitecture => 'Architecture';

  @override
  String get cpuFrequency => 'Frequency';

  @override
  String get cpuPCores => 'P-Cores';

  @override
  String get cpuECores => 'E-Cores';

  @override
  String get cpuThreads => 'Threads';

  @override
  String get cpuCache => 'Cache';

  @override
  String get gpuInfo => 'GPU';

  @override
  String get gpuModel => 'Model';

  @override
  String get gpuArchitecture => 'Architecture';

  @override
  String get ram => 'RAM';

  @override
  String get storage => 'Storage';

  @override
  String get screenSize => 'Screen Size';

  @override
  String get screenResolution => 'Resolution';

  @override
  String get ppi => 'PPI';

  @override
  String get battery => 'Battery';

  @override
  String get os => 'OS';

  @override
  String get addDevice => 'Add Device';

  @override
  String get editDevice => 'Edit Device';

  @override
  String get deleteDevice => 'Delete Device';

  @override
  String deleteDeviceConfirm(String name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get noDevices => 'No devices yet. Tap + to add one!';

  @override
  String get deviceDetail => 'Device Detail';

  @override
  String get swipeEditHint => 'Edit';

  @override
  String get swipeDeleteHint => 'Delete';

  @override
  String get fromTemplate => 'From Template';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsData => 'Data';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsPrivacyPolicy => 'Privacy Policy';

  @override
  String get settingsLicense => 'License (GPLv3)';

  @override
  String get settingsLicenses => 'Open Source Licenses';

  @override
  String get backupTitle => 'Backup';

  @override
  String get backupSubtitle => 'Full local backup (data + images)';

  @override
  String get backupCreate => 'Create Backup';

  @override
  String get backupCreated => 'Backup created';

  @override
  String get backupAutoBackup => 'Auto Backup';

  @override
  String get backupRetention => 'Retention Period';

  @override
  String get backupKeepForever => 'Keep forever';

  @override
  String backupKeepDays(int days) {
    return '$days days';
  }

  @override
  String backupHistory(int count) {
    return 'History ($count)';
  }

  @override
  String get backupNoBackups => 'No backups yet';

  @override
  String get backupRestore => 'Restore';

  @override
  String get backupRestoreConfirm =>
      'This will overwrite your current data. Continue?';

  @override
  String get backupRestored => 'Backup restored';

  @override
  String get backupRestoreFailed => 'Restore failed';

  @override
  String get backupDeleteConfirm => 'Delete this backup?';

  @override
  String get exportData => 'Export Data';

  @override
  String get importData => 'Import Data';

  @override
  String get exportSuccess => 'Data exported successfully';

  @override
  String get importSuccess => 'Data imported successfully';

  @override
  String get importFailed => 'Import failed';

  @override
  String get importConfirm =>
      'This will overwrite your current data. Continue?';

  @override
  String get dataMigration => 'Open Data Folder';

  @override
  String get dataMigrationDesc => 'Open the application data directory';

  @override
  String get settingsStorageLocation => 'Storage Location';

  @override
  String get settingsStoragePathHint =>
      'Enter the directory path for storing data. Leave empty to use default.';

  @override
  String get settingsDirectoryPath => 'Directory Path';

  @override
  String get settingsResetDefault => 'Reset to Default';

  @override
  String get settingsResetDefaultLocation => 'Reset to default location';

  @override
  String get settingsStoragePathUpdated => 'Storage path updated';

  @override
  String totalDevices(int count) {
    return '$count device(s)';
  }

  @override
  String get storageType => 'Type';

  @override
  String get storageInterface => 'Interface';

  @override
  String get storageTypeSsd => 'SSD';

  @override
  String get storageTypeSdCard => 'SD Card';

  @override
  String get storageTypeHdd => 'HDD';

  @override
  String get storageInterfaceM2Nvme => 'M.2 NVMe';

  @override
  String get storageInterfaceSata25 => '2.5\" SATA';

  @override
  String get storageInterfaceM2Sata => 'M.2 SATA';

  @override
  String get storageInterfaceUsb => 'USB';

  @override
  String get ramType => 'RAM Type';

  @override
  String get sortTitle => 'Sort';

  @override
  String get sortCustom => 'Custom Order';

  @override
  String get sortAlphabetical => 'Alphabetical';

  @override
  String get sortPurchaseDate => 'Purchase Date';

  @override
  String get sortReleaseDate => 'Release Date';

  @override
  String get sortAscending => 'Ascending';

  @override
  String get sortSubnet => 'Subnet';

  @override
  String get sortGroupByCategory => 'Group by Category';

  @override
  String get sortReorder => 'Reorder...';

  @override
  String get sortByIp => 'IP Address';

  @override
  String get sortExitNodeFirst => 'Exit Nodes First';

  @override
  String get navNetworks => 'Networks';

  @override
  String get noNetworks => 'No networks yet. Tap + to add one!';

  @override
  String get addNetwork => 'Add Network';

  @override
  String get editNetwork => 'Edit Network';

  @override
  String get deleteNetwork => 'Delete Network';

  @override
  String get deleteNetworkConfirm =>
      'This will delete the network and all device assignments. Continue?';

  @override
  String get networkName => 'Name';

  @override
  String get networkType => 'Type';

  @override
  String get networkSubnet => 'Subnet';

  @override
  String get networkGateway => 'Gateway';

  @override
  String get networkDns => 'DNS Servers';

  @override
  String get networkNotes => 'Notes';

  @override
  String get networkNotesHint => 'Config info, keys, remarks…';

  @override
  String get networkTypeLan => 'LAN';

  @override
  String get networkTypeTailscale => 'Tailscale';

  @override
  String get networkTypeZerotier => 'ZeroTier';

  @override
  String get networkTypeEasytier => 'EasyTier';

  @override
  String get networkTypeWireguard => 'WireGuard';

  @override
  String get networkTypeOther => 'Other';

  @override
  String get networkDevices => 'Devices';

  @override
  String get noNetworkDevices => 'No devices in this network yet.';

  @override
  String get networkDeviceConfig => 'Device Config';

  @override
  String get networkAddressMode => 'Address Mode';

  @override
  String get addressModeDhcp => 'DHCP';

  @override
  String get addressModeStatic => 'Static IP';

  @override
  String get networkIpAddress => 'IP Address';

  @override
  String get networkHostname => 'Hostname';

  @override
  String get networkExitNode => 'Exit Node';

  @override
  String get networkPickDevice => 'Select Device';

  @override
  String get removeDevice => 'Remove Device';

  @override
  String get removeDeviceConfirm => 'Remove this device from the network?';

  @override
  String get settingsConfirm => 'Confirm';

  @override
  String get settingsWebDAVSync => 'WebDAV Sync';

  @override
  String get settingsWebDAVServerURL => 'Server URL';

  @override
  String get settingsWebDAVUsername => 'Username';

  @override
  String get settingsWebDAVPassword => 'Password';

  @override
  String get settingsWebDAVRemotePath => 'Remote Path';

  @override
  String get settingsWebDAVNextcloud => 'Nextcloud';

  @override
  String get settingsWebDAVTestConnection => 'Test Connection';

  @override
  String get settingsWebDAVConnectionSuccess => 'Connection successful';

  @override
  String get settingsWebDAVConnectionFailed => 'Connection failed';

  @override
  String get settingsWebDAVConfigSaved => 'WebDAV configuration saved';

  @override
  String get settingsWebDAVSyncNow => 'Sync Now';

  @override
  String get settingsWebDAVSyncing => 'Syncing…';

  @override
  String get settingsWebDAVSyncSuccess => 'Sync completed';

  @override
  String get settingsWebDAVSyncFailed => 'Sync failed';

  @override
  String get settingsWebDAVAutoSync => 'Auto Sync';

  @override
  String get settingsWebDAVAutoSyncDesc =>
      'Sync automatically when data changes';

  @override
  String get settingsWebDAVDisconnect => 'Disconnect';

  @override
  String get settingsWebDAVConfigRemoved => 'WebDAV configuration removed';

  @override
  String get backupRestoreModules => 'Select Modules to Restore';

  @override
  String get backupSelectAll => 'Select All';

  @override
  String get backupModuleDevices => 'Devices';

  @override
  String get backupModuleNetworks => 'Networks';

  @override
  String get backupModuleDatasets => 'Data Sets';

  @override
  String get navDataSets => 'Data Sets';

  @override
  String get noDataSets => 'No data sets yet. Tap + to add one!';

  @override
  String get addDataSet => 'Add Data Set';

  @override
  String get editDataSet => 'Edit Data Set';

  @override
  String get deleteDataSet => 'Delete Data Set';

  @override
  String deleteDataSetConfirm(String name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get dataSetName => 'Name';

  @override
  String get dataSetEmoji => 'Emoji';

  @override
  String get dataSetStorages => 'Linked Storages';

  @override
  String get dataSetNoDeviceStorages => 'No devices with storage found';

  @override
  String get mapViewDevices => 'Device Map';

  @override
  String get mapViewNetworkDevices => 'Network Device Map';

  @override
  String get mapNoLocations => 'No devices have location data set.';

  @override
  String get deviceEmoji => 'Icon';

  @override
  String get deviceImage => 'Image';

  @override
  String get devicePickImage => 'Pick Image';

  @override
  String get deviceChangeImage => 'Change';

  @override
  String get deviceRemoveIcon => 'Remove Icon';

  @override
  String get deviceSerialNumber => 'Serial Number';

  @override
  String get storageBrand => 'Brand';

  @override
  String get storageSerialNumber => 'Serial Number';

  @override
  String get fetchFromInternet => 'Fetch Online';

  @override
  String get searchDeviceInfo => 'Fetch Device Info';

  @override
  String get searchHint => 'Search device name...';

  @override
  String get searchButton => 'Search';

  @override
  String get searchNoResults => 'No results found';

  @override
  String get searchApply => 'Apply';

  @override
  String get searchCurrent => 'Current';

  @override
  String get searchFetched => 'Fetched';

  @override
  String get searchDeviceImage => 'Device Image';

  @override
  String get searchFetchImage => 'Download';

  @override
  String get searchFetchingDetail => 'Fetching details...';

  @override
  String get searchCpuInfo => 'Search CPU';

  @override
  String get searchGpuInfo => 'Search GPU';

  @override
  String get searchCpuHint => 'Enter CPU model...';

  @override
  String get searchGpuHint => 'Enter GPU model...';
}
