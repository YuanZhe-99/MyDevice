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
  String get exportAsZip => 'Export as ZIP';

  @override
  String get exportAsZipDesc =>
      'Full data archive (device data + images) for backup or migration';

  @override
  String get exportAsMarkdown => 'Export as Markdown';

  @override
  String get exportAsMarkdownDesc =>
      'Device inventory with network & dataset info, for LLM personalization';

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
  String settingsWebDAVSyncImageWarnings(int count) {
    return 'Sync completed, but $count image(s) failed to transfer';
  }

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

  @override
  String get searchTemplatePlaceholder => 'Search...';

  @override
  String get cpuPresetSearch => 'Search CPU...';

  @override
  String get gpuPresetSearch => 'Search GPU...';

  @override
  String get cpuArchHint => 'e.g. ARM Cortex-A78, x86-64';

  @override
  String get cpuFreqHint => 'e.g. 3.5 GHz';

  @override
  String get cpuCacheHint => 'e.g. L2 4MB / L3 32MB';

  @override
  String get gpuArchHint => 'e.g. Ada Lovelace, RDNA 3';

  @override
  String get ramHint => 'e.g. 16';

  @override
  String get storageCapacityHint => 'e.g. 512';

  @override
  String get storageBrandHint => 'e.g. Samsung, WD';

  @override
  String get screenSizeHint => 'e.g. 6.7\"';

  @override
  String get batteryHint => 'e.g. 5000 mAh';

  @override
  String get osHint => 'e.g. Windows 11, Android 15';

  @override
  String get locationHint => 'e.g. Home, Office, Tokyo DC';

  @override
  String get networkSubnetHint => 'e.g. 192.168.1.0/24, 100.64.0.0/10';

  @override
  String get networkGatewayHint => 'e.g. 192.168.1.1';

  @override
  String get networkDnsHint => 'e.g. 8.8.8.8, 1.1.1.1';

  @override
  String get networkIpHint => 'e.g. 192.168.1.100';

  @override
  String get networkHostnameHint => 'e.g. my-server';

  @override
  String get backupModuleImages => 'Images';

  @override
  String syncConflictTitle(String name) {
    return 'Sync Conflict: $name';
  }

  @override
  String get syncConflictBody =>
      'This record was modified on both devices since last sync.';

  @override
  String get syncConflictLocalVersion => 'Local version:';

  @override
  String get syncConflictRemoteVersion => 'Remote version:';

  @override
  String get syncConflictKeepLocal => 'Keep Local';

  @override
  String get syncConflictKeepRemote => 'Keep Remote';

  @override
  String get trayShow => 'Show';

  @override
  String get trayQuit => 'Quit';

  @override
  String get settingsMinimizeToTray => 'Minimize to Tray';

  @override
  String get settingsCloseToTray => 'Close to Tray';

  @override
  String get settingsAutoStart => 'Launch at Startup';

  @override
  String get settingsApiServer => 'API Server Settings';

  @override
  String get settingsApiEnabled => 'Local API Server';

  @override
  String get settingsApiListenAddress => 'Listen Address';

  @override
  String get settingsApiPort => 'Port';

  @override
  String get settingsApiUsername => 'Username';

  @override
  String get settingsApiPassword => 'Password';

  @override
  String settingsApiRunning(int port) {
    return 'Running on port $port';
  }

  @override
  String get settingsApiStopped => 'Stopped';

  @override
  String get settingsApiNeedCredentials =>
      'Set username and password before listening on non-localhost';

  @override
  String settingsApiRestarted(int port) {
    return 'API server restarted on port $port';
  }

  @override
  String get settingsDesktop => 'Desktop';

  @override
  String get lifecycleAndFinance => 'Lifecycle & Finance';

  @override
  String get deviceStatus => 'Status';

  @override
  String get statusInService => 'In Service';

  @override
  String get statusRetired => 'Retired';

  @override
  String get statusSold => 'Sold';

  @override
  String get filterAll => 'All';

  @override
  String get deviceRetired => 'Retired';

  @override
  String get deviceRetiredDate => 'Retirement Date';

  @override
  String get deviceSold => 'Sold';

  @override
  String get acquisitionType => 'Acquisition Type';

  @override
  String get acquisitionPurchased => 'One-time Purchase';

  @override
  String get acquisitionLeased => 'Lease';

  @override
  String get acquisitionPurchasedWithSubscription => 'Purchase + Subscription';

  @override
  String get acquisitionOther => 'Other';

  @override
  String get optionalNone => 'None';

  @override
  String get purchasePrice => 'Purchase Price';

  @override
  String get soldPrice => 'Sold Price';

  @override
  String get priceAmount => 'Amount';

  @override
  String get exchangeRateAuto => 'Use automatic exchange rate';

  @override
  String get exchangeRateAutoDisabled =>
      'Automatic updates are disabled in Settings; saved rates or fallback rates will be used.';

  @override
  String get exchangeRateManual => 'Manual Exchange Rate';

  @override
  String exchangeRateManualHint(String from, String to) {
    return '1 $from = ? $to';
  }

  @override
  String get exchangeRateManualRequired =>
      'Please enter a manual exchange rate.';

  @override
  String get exchangeRateUnavailable =>
      'Exchange rate unavailable. Try refreshing rates or enter a manual rate.';

  @override
  String get recurringCosts => 'Recurring Costs';

  @override
  String get recurringCostType => 'Type';

  @override
  String get recurringCostName => 'Name';

  @override
  String get recurringCostNameHint => 'e.g. AppleCare+, lease payment';

  @override
  String get recurringCostPrice => 'Recurring Price';

  @override
  String get recurringCostLease => 'Lease';

  @override
  String get recurringCostInsurance => 'Insurance';

  @override
  String get recurringCostSubscription => 'Subscription';

  @override
  String get recurringCostOther => 'Other';

  @override
  String get billingCycle => 'Billing Cycle';

  @override
  String get billingMonthly => 'Monthly';

  @override
  String get billingYearly => 'Yearly';

  @override
  String get financialOverview => 'Financial Overview';

  @override
  String get financialTotalCost => 'Total Cost';

  @override
  String get financialDailyCost => 'Daily Cost';

  @override
  String get financialAssetDistribution => 'Asset Distribution';

  @override
  String get financialDailyCostLogTrend => 'Daily Cost Trend (Log)';

  @override
  String get financialDevicesWithFinance => 'Tracked';

  @override
  String get financialHistory => 'History';

  @override
  String get financialFutureTrend => 'Future Trend';

  @override
  String get financialRange1Year => '1Y';

  @override
  String get financialRange3Years => '3Y';

  @override
  String get financialRangeAll => 'All';

  @override
  String get financialNoData => 'No financial data';

  @override
  String get settingsDefaultCurrency => 'Default Currency';

  @override
  String get settingsAutoUpdateExchangeRates => 'Auto-update Exchange Rates';

  @override
  String get settingsRefreshExchangeRates => 'Refresh Exchange Rates';

  @override
  String get exchangeRateUpdated => 'Exchange rates updated';

  @override
  String get exchangeRateUpdateFailed => 'Failed to update exchange rates';

  @override
  String get navServices => 'Services';

  @override
  String get servicesOverview => 'Overview';

  @override
  String get servicesByDevice => 'Devices';

  @override
  String get serviceRoutes => 'Routes';

  @override
  String get servicePorts => 'Ports';

  @override
  String get noServices =>
      'No services yet. Add a device service to track ports and routes.';

  @override
  String get noServiceRoutes => 'No service routes yet.';

  @override
  String get addService => 'Add Service';

  @override
  String get editService => 'Edit Service';

  @override
  String get deleteService => 'Delete Service';

  @override
  String deleteServiceConfirm(String name) {
    return 'Delete service \"$name\"? Routes from this service will also be removed.';
  }

  @override
  String get serviceName => 'Service Name';

  @override
  String get serviceNameRequired => 'Enter a service name.';

  @override
  String get serviceDevice => 'Device';

  @override
  String get serviceTemplate => 'Template';

  @override
  String get serviceCustom => 'Custom Service';

  @override
  String get servicePickTemplate => 'Pick Service Template';

  @override
  String get serviceCustomTemplateDesc => 'Start from a blank service record';

  @override
  String get serviceFeaturedTemplate => 'Featured';

  @override
  String get serviceIcon => 'Icon Name';

  @override
  String get serviceKind => 'Kind';

  @override
  String get serviceRuntime => 'Runtime';

  @override
  String get serviceState => 'State';

  @override
  String get serviceEndpoints => 'Endpoints';

  @override
  String get serviceEndpoint => 'Endpoint';

  @override
  String get addServiceEndpoint => 'Add Endpoint';

  @override
  String get editServiceEndpoint => 'Edit Endpoint';

  @override
  String get serviceEndpointLabel => 'Label';

  @override
  String get serviceProtocol => 'Protocol';

  @override
  String get serviceTransport => 'Transport';

  @override
  String get servicePort => 'Port';

  @override
  String get servicePortEnd => 'Port End';

  @override
  String get serviceBindAddress => 'Bind Address';

  @override
  String get servicePath => 'Path';

  @override
  String get serviceScope => 'Scope';

  @override
  String get servicePrimaryEndpoint => 'Primary endpoint';

  @override
  String get serviceDockerCompose => 'Docker Compose';

  @override
  String get copyServiceCompose => 'Copy Compose';

  @override
  String get serviceComposeCopied => 'Docker Compose copied';

  @override
  String get addServiceRoute => 'Add Route';

  @override
  String get editServiceRoute => 'Edit Route';

  @override
  String get deleteServiceRoute => 'Delete Route';

  @override
  String deleteServiceRouteConfirm(String name) {
    return 'Delete route \"$name\"?';
  }

  @override
  String get serviceRouteName => 'Route Name';

  @override
  String get routeSourceService => 'Source Service';

  @override
  String get serviceAccessLevel => 'Access Level';

  @override
  String get serviceFinalUrl => 'Final URL / Address';

  @override
  String get serviceAddAccess => 'Add Access';

  @override
  String get serviceAdvancedRoute => 'Advanced Route';

  @override
  String get serviceTopology => 'Service Topology';

  @override
  String get serviceTopologyHint =>
      'Preview devices, local ports, relays, remote entries, and domains. Open the topology for node details or zooming.';

  @override
  String get serviceOpenTopology => 'Open Topology';

  @override
  String get serviceTopologySelectMode => 'Select';

  @override
  String get serviceTopologyMoveMode => 'Move / Zoom';

  @override
  String get serviceAccessMethod => 'Access Method';

  @override
  String get serviceRelayService => 'Relay / Proxy Service';

  @override
  String get serviceRemoteDevice => 'Remote Device / VPS';

  @override
  String get serviceRemoteHost => 'Remote Host / IP';

  @override
  String get serviceRemotePort => 'Remote Port';

  @override
  String get serviceRemotePortRequired => 'Enter a valid remote port.';

  @override
  String get serviceDomains => 'Domains / Public Targets';

  @override
  String get serviceDomainsHint =>
      'Optional for port mappings. Enter one domain per line or separate with commas.';

  @override
  String get serviceAccessTargetsHint =>
      'Enter one URL or address per line. Multiple entries stay together on the same access route.';

  @override
  String get serviceAccessTargetRequired =>
      'Enter at least one URL or address.';

  @override
  String get routeHops => 'Route Hops';

  @override
  String get addRouteHop => 'Add Hop';

  @override
  String get editRouteHop => 'Edit Hop';

  @override
  String get routeHopType => 'Hop Type';

  @override
  String get routeMethod => 'Method';

  @override
  String get routeHopService => 'Hop Service';

  @override
  String get routeManualHop => 'Manual Hop';

  @override
  String get routeHopLabel => 'Hop Label';

  @override
  String get routeScheme => 'Scheme';

  @override
  String get routeHost => 'Host';

  @override
  String get activeServices => 'Active Services';

  @override
  String get serviceDevices => 'Devices';

  @override
  String get publicRoutes => 'Public Routes';

  @override
  String get serviceWarnings => 'Warnings';

  @override
  String get servicePortConflicts => 'Port Conflicts';

  @override
  String get servicePortUsage => 'Port Usage';

  @override
  String get servicePotentialConflict => 'potential';

  @override
  String get serviceAnyAddress => 'Any Address';

  @override
  String servicePortConflict(String device, int port) {
    return '$device: port $port may be used by multiple services';
  }

  @override
  String get serviceRoutePreview => 'Route Preview';

  @override
  String get serviceMoveUp => 'Move Up';

  @override
  String get serviceMoveDown => 'Move Down';

  @override
  String serviceWarningMissingDevice(String name) {
    return '$name: missing device';
  }

  @override
  String serviceWarningInactiveDevice(String name) {
    return '$name: device is not in service';
  }

  @override
  String serviceWarningMissingNetwork(String name) {
    return '$name: missing endpoint network';
  }

  @override
  String serviceWarningMissingSource(String name) {
    return '$name: missing source service';
  }

  @override
  String serviceWarningMissingSourceEndpoint(String name) {
    return '$name: missing source endpoint';
  }

  @override
  String serviceWarningMissingHopService(String name) {
    return '$name: missing hop service';
  }

  @override
  String serviceWarningMissingHopEndpoint(String name) {
    return '$name: missing hop endpoint';
  }

  @override
  String serviceWarningMissingHopDevice(String name) {
    return '$name: missing hop device';
  }

  @override
  String serviceWarningEmptyRoute(String name) {
    return '$name: route has no hops';
  }

  @override
  String serviceWarningPublicRouteMissingUrl(String name) {
    return '$name: public route has no final URL';
  }

  @override
  String serviceWarningDuplicateFinalUrl(String name) {
    return '$name: duplicate final URL';
  }

  @override
  String serviceCount(int count) {
    return '$count service(s)';
  }

  @override
  String serviceRouteCount(int count) {
    return '$count route(s)';
  }

  @override
  String get backupModuleServices => 'Services';
}
