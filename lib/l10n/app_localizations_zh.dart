// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'MyDevice!!!!!';

  @override
  String get navDevices => '设备';

  @override
  String get navSettings => '设置';

  @override
  String get deviceCategoryDesktop => '台式机';

  @override
  String get deviceCategoryLaptop => '笔记本';

  @override
  String get deviceCategoryPhone => '手机';

  @override
  String get deviceCategoryTablet => '平板';

  @override
  String get deviceCategoryHeadphone => '耳机';

  @override
  String get deviceCategoryWatch => '手表';

  @override
  String get deviceCategoryRouter => '路由器';

  @override
  String get deviceCategoryGameConsole => '游戏机';

  @override
  String get deviceCategoryVps => '云服务器';

  @override
  String get deviceCategoryDevBoard => '开发板';

  @override
  String get deviceCategoryOther => '其他';

  @override
  String get deviceName => '名称';

  @override
  String get deviceBrand => '品牌';

  @override
  String get deviceModel => '型号';

  @override
  String get deviceCategory => '类别';

  @override
  String get devicePurchaseDate => '购入日期';

  @override
  String get deviceReleaseDate => '发布时间';

  @override
  String get deviceNotes => '备注';

  @override
  String get deviceLocation => '位置';

  @override
  String get mapPickLocation => '选择位置';

  @override
  String get mapSearchHint => '搜索位置...';

  @override
  String get cpuInfo => 'CPU';

  @override
  String get cpuModel => '型号';

  @override
  String get cpuArchitecture => '架构';

  @override
  String get cpuFrequency => '主频';

  @override
  String get cpuPCores => '大核';

  @override
  String get cpuECores => '小核';

  @override
  String get cpuThreads => '线程';

  @override
  String get cpuCache => '缓存';

  @override
  String get gpuInfo => 'GPU';

  @override
  String get gpuModel => '型号';

  @override
  String get gpuArchitecture => '架构';

  @override
  String get ram => '内存';

  @override
  String get storage => '存储';

  @override
  String get screenSize => '屏幕尺寸';

  @override
  String get screenResolution => '分辨率';

  @override
  String get ppi => 'PPI';

  @override
  String get battery => '电池';

  @override
  String get os => '操作系统';

  @override
  String get addDevice => '添加设备';

  @override
  String get editDevice => '编辑设备';

  @override
  String get deleteDevice => '删除设备';

  @override
  String deleteDeviceConfirm(String name) {
    return '确定要删除「$name」吗？';
  }

  @override
  String get save => '保存';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get noDevices => '还没有设备，点击 + 添加一个吧！';

  @override
  String get deviceDetail => '设备详情';

  @override
  String get swipeEditHint => '编辑';

  @override
  String get swipeDeleteHint => '删除';

  @override
  String get fromTemplate => '从模板创建';

  @override
  String get settingsTheme => '主题';

  @override
  String get settingsThemeSystem => '跟随系统';

  @override
  String get settingsThemeLight => '浅色';

  @override
  String get settingsThemeDark => '深色';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsLanguageSystem => '跟随系统';

  @override
  String get settingsGeneral => '通用';

  @override
  String get settingsData => '数据';

  @override
  String get settingsAbout => '关于';

  @override
  String get settingsVersion => '版本';

  @override
  String get settingsPrivacyPolicy => '隐私政策';

  @override
  String get settingsLicense => '许可证 (GPLv3)';

  @override
  String get settingsLicenses => '开源许可证';

  @override
  String get backupTitle => '备份';

  @override
  String get backupSubtitle => '完整本机备份（数据 + 图片）';

  @override
  String get backupCreate => '创建备份';

  @override
  String get backupCreated => '备份已创建';

  @override
  String get backupAutoBackup => '自动备份';

  @override
  String get backupRetention => '保留时间';

  @override
  String get backupKeepForever => '永久保留';

  @override
  String backupKeepDays(int days) {
    return '$days 天';
  }

  @override
  String backupHistory(int count) {
    return '历史记录 ($count)';
  }

  @override
  String get backupNoBackups => '暂无备份';

  @override
  String get backupRestore => '还原';

  @override
  String get backupRestoreConfirm => '这将覆盖当前数据，确定继续吗？';

  @override
  String get backupRestored => '备份已还原';

  @override
  String get backupRestoreFailed => '还原失败';

  @override
  String get backupDeleteConfirm => '确定删除这个备份吗？';

  @override
  String get exportData => '导出数据';

  @override
  String get exportAsZip => '导出为 ZIP';

  @override
  String get exportAsZipDesc => '完整数据压缩包（设备数据 + 图片），用于备份或迁移';

  @override
  String get exportAsMarkdown => '导出为 Markdown';

  @override
  String get exportAsMarkdownDesc => '设备清单及网络、资料集信息，用于 LLM 个性化学习';

  @override
  String get importData => '导入数据';

  @override
  String get exportSuccess => '数据导出成功';

  @override
  String get importSuccess => '数据导入成功';

  @override
  String get importFailed => '导入失败';

  @override
  String get importConfirm => '这将覆盖当前数据，确定继续吗？';

  @override
  String get dataMigration => '打开数据文件夹';

  @override
  String get dataMigrationDesc => '打开应用程序数据目录';

  @override
  String get settingsStorageLocation => '存储位置';

  @override
  String get settingsStoragePathHint => '输入数据存储目录路径。留空使用默认路径。';

  @override
  String get settingsDirectoryPath => '目录路径';

  @override
  String get settingsResetDefault => '恢复默认';

  @override
  String get settingsResetDefaultLocation => '已恢复默认存储位置';

  @override
  String get settingsStoragePathUpdated => '存储路径已更新';

  @override
  String totalDevices(int count) {
    return '$count 台设备';
  }

  @override
  String get storageType => '类型';

  @override
  String get storageInterface => '接口';

  @override
  String get storageTypeSsd => 'SSD';

  @override
  String get storageTypeSdCard => 'SD 卡';

  @override
  String get storageTypeHdd => '机械硬盘';

  @override
  String get storageInterfaceM2Nvme => 'M.2 NVMe';

  @override
  String get storageInterfaceSata25 => '2.5\" SATA';

  @override
  String get storageInterfaceM2Sata => 'M.2 SATA';

  @override
  String get storageInterfaceUsb => 'USB';

  @override
  String get ramType => '内存类型';

  @override
  String get sortTitle => '排序';

  @override
  String get sortCustom => '自定义顺序';

  @override
  String get sortAlphabetical => '字典序';

  @override
  String get sortPurchaseDate => '购买时间';

  @override
  String get sortReleaseDate => '发布时间';

  @override
  String get sortAscending => '正序';

  @override
  String get sortSubnet => '子网';

  @override
  String get sortGroupByCategory => '按类别分组';

  @override
  String get sortReorder => '调整顺序…';

  @override
  String get sortByIp => 'IP地址';

  @override
  String get sortExitNodeFirst => '出口节点置顶';

  @override
  String get navNetworks => '网络';

  @override
  String get noNetworks => '还没有网络，点击 + 添加一个吧！';

  @override
  String get addNetwork => '添加网络';

  @override
  String get editNetwork => '编辑网络';

  @override
  String get deleteNetwork => '删除网络';

  @override
  String get deleteNetworkConfirm => '这将删除该网络及其所有设备分配，确定继续吗？';

  @override
  String get networkName => '名称';

  @override
  String get networkType => '类型';

  @override
  String get networkSubnet => '子网';

  @override
  String get networkGateway => '网关';

  @override
  String get networkDns => 'DNS 服务器';

  @override
  String get networkNotes => '备注';

  @override
  String get networkNotesHint => '配置信息、密钥、备注…';

  @override
  String get networkTypeLan => '局域网';

  @override
  String get networkTypeTailscale => 'Tailscale';

  @override
  String get networkTypeZerotier => 'ZeroTier';

  @override
  String get networkTypeEasytier => 'EasyTier';

  @override
  String get networkTypeWireguard => 'WireGuard';

  @override
  String get networkTypeOther => '其他';

  @override
  String get networkDevices => '设备';

  @override
  String get noNetworkDevices => '该网络下还没有设备。';

  @override
  String get networkDeviceConfig => '设备配置';

  @override
  String get networkAddressMode => '地址模式';

  @override
  String get addressModeDhcp => 'DHCP';

  @override
  String get addressModeStatic => '静态 IP';

  @override
  String get networkIpAddress => 'IP 地址';

  @override
  String get networkHostname => '主机名';

  @override
  String get networkExitNode => '出口节点';

  @override
  String get networkPickDevice => '选择设备';

  @override
  String get removeDevice => '移除设备';

  @override
  String get removeDeviceConfirm => '确定从该网络中移除此设备吗？';

  @override
  String get settingsConfirm => '确认';

  @override
  String get settingsWebDAVSync => 'WebDAV 同步';

  @override
  String get settingsWebDAVServerURL => '服务器地址';

  @override
  String get settingsWebDAVUsername => '用户名';

  @override
  String get settingsWebDAVPassword => '密码';

  @override
  String get settingsWebDAVRemotePath => '远程路径';

  @override
  String get settingsWebDAVNextcloud => 'Nextcloud';

  @override
  String get settingsWebDAVTestConnection => '测试连接';

  @override
  String get settingsWebDAVConnectionSuccess => '连接成功';

  @override
  String get settingsWebDAVConnectionFailed => '连接失败';

  @override
  String get settingsWebDAVConfigSaved => 'WebDAV 配置已保存';

  @override
  String get settingsWebDAVSyncNow => '立即同步';

  @override
  String get settingsWebDAVSyncing => '同步中…';

  @override
  String get settingsWebDAVSyncSuccess => '同步完成';

  @override
  String get settingsWebDAVSyncFailed => '同步失败';

  @override
  String settingsWebDAVSyncImageWarnings(int count) {
    return '同步完成，但$count张图片传输失败';
  }

  @override
  String get settingsWebDAVAutoSync => '自动同步';

  @override
  String get settingsWebDAVAutoSyncDesc => '数据变更时自动同步';

  @override
  String get settingsWebDAVDisconnect => '断开连接';

  @override
  String get settingsWebDAVConfigRemoved => 'WebDAV 配置已移除';

  @override
  String get backupRestoreModules => '选择要还原的模块';

  @override
  String get backupSelectAll => '全选';

  @override
  String get backupModuleDevices => '设备';

  @override
  String get backupModuleNetworks => '网络';

  @override
  String get backupModuleDatasets => '资料集';

  @override
  String get navDataSets => '资料集';

  @override
  String get noDataSets => '还没有资料集，点击 + 添加一个吧！';

  @override
  String get addDataSet => '添加资料集';

  @override
  String get editDataSet => '编辑资料集';

  @override
  String get deleteDataSet => '删除资料集';

  @override
  String deleteDataSetConfirm(String name) {
    return '确定要删除「$name」吗？';
  }

  @override
  String get dataSetName => '名称';

  @override
  String get dataSetEmoji => '图标';

  @override
  String get dataSetStorages => '关联存储';

  @override
  String get dataSetNoDeviceStorages => '没有找到包含存储的设备';

  @override
  String get mapViewDevices => '设备地图';

  @override
  String get mapViewNetworkDevices => '网络设备地图';

  @override
  String get mapNoLocations => '没有设备设置了位置信息。';

  @override
  String get deviceEmoji => '图标';

  @override
  String get deviceImage => '图片';

  @override
  String get devicePickImage => '选择图片';

  @override
  String get deviceChangeImage => '更换';

  @override
  String get deviceRemoveIcon => '移除图标';

  @override
  String get deviceSerialNumber => '序列号';

  @override
  String get storageBrand => '品牌';

  @override
  String get storageSerialNumber => '序列号';

  @override
  String get fetchFromInternet => '联网查询';

  @override
  String get searchDeviceInfo => '获取设备信息';

  @override
  String get searchHint => '搜索设备名称...';

  @override
  String get searchButton => '搜索';

  @override
  String get searchNoResults => '未找到结果';

  @override
  String get searchApply => '应用';

  @override
  String get searchCurrent => '当前';

  @override
  String get searchFetched => '获取';

  @override
  String get searchDeviceImage => '设备图片';

  @override
  String get searchFetchImage => '下载';

  @override
  String get searchFetchingDetail => '正在获取详情...';

  @override
  String get searchCpuInfo => '搜索 CPU';

  @override
  String get searchGpuInfo => '搜索 GPU';

  @override
  String get searchCpuHint => '输入 CPU 型号...';

  @override
  String get searchGpuHint => '输入 GPU 型号...';

  @override
  String get searchTemplatePlaceholder => '搜索…';

  @override
  String get cpuPresetSearch => '搜索 CPU…';

  @override
  String get gpuPresetSearch => '搜索 GPU…';

  @override
  String get cpuArchHint => '例：ARM Cortex-A78、x86-64';

  @override
  String get cpuFreqHint => '例：3.5 GHz';

  @override
  String get cpuCacheHint => '例：L2 4MB / L3 32MB';

  @override
  String get gpuArchHint => '例：Ada Lovelace、RDNA 3';

  @override
  String get ramHint => '例：16';

  @override
  String get storageCapacityHint => '例：512';

  @override
  String get storageBrandHint => '例：三星、WD';

  @override
  String get screenSizeHint => '例：6.7\"';

  @override
  String get batteryHint => '例：5000 mAh';

  @override
  String get osHint => '例：Windows 11、Android 15';

  @override
  String get locationHint => '例：家、办公室、东京机房';

  @override
  String get networkSubnetHint => '例：192.168.1.0/24、100.64.0.0/10';

  @override
  String get networkGatewayHint => '例：192.168.1.1';

  @override
  String get networkDnsHint => '例：8.8.8.8、1.1.1.1';

  @override
  String get networkIpHint => '例：192.168.1.100';

  @override
  String get networkHostnameHint => '例：my-server';

  @override
  String get backupModuleImages => '图片';

  @override
  String syncConflictTitle(String name) {
    return '同步冲突：$name';
  }

  @override
  String get syncConflictBody => '此记录在上次同步后在两端均有修改。';

  @override
  String get syncConflictLocalVersion => '本地版本：';

  @override
  String get syncConflictRemoteVersion => '远端版本：';

  @override
  String get syncConflictKeepLocal => '保留本地';

  @override
  String get syncConflictKeepRemote => '保留远端';

  @override
  String get trayShow => '显示';

  @override
  String get trayQuit => '退出';

  @override
  String get settingsMinimizeToTray => '最小化到托盘';

  @override
  String get settingsCloseToTray => '关闭时最小化到托盘';

  @override
  String get settingsAutoStart => '开机自启';

  @override
  String get settingsApiServer => 'API 服务器设置';

  @override
  String get settingsApiEnabled => '本地 API 服务器';

  @override
  String get settingsApiListenAddress => '监听地址';

  @override
  String get settingsApiPort => '端口';

  @override
  String get settingsApiUsername => '用户名';

  @override
  String get settingsApiPassword => '密码';

  @override
  String settingsApiRunning(int port) {
    return '正在端口 $port 上运行';
  }

  @override
  String get settingsApiStopped => '已停止';

  @override
  String get settingsApiNeedCredentials => '监听非 localhost 时需设置用户名和密码';

  @override
  String settingsApiRestarted(int port) {
    return 'API 服务器已在端口 $port 上重启';
  }

  @override
  String get settingsDesktop => '桌面端';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get appTitle => 'MyDevice!!!!!';

  @override
  String get navDevices => '裝置';

  @override
  String get navSettings => '設定';

  @override
  String get deviceCategoryDesktop => '桌上型電腦';

  @override
  String get deviceCategoryLaptop => '筆記型電腦';

  @override
  String get deviceCategoryPhone => '手機';

  @override
  String get deviceCategoryTablet => '平板';

  @override
  String get deviceCategoryHeadphone => '耳機';

  @override
  String get deviceCategoryWatch => '手錶';

  @override
  String get deviceCategoryRouter => '路由器';

  @override
  String get deviceCategoryGameConsole => '遊戲機';

  @override
  String get deviceCategoryVps => '雲端伺服器';

  @override
  String get deviceCategoryDevBoard => '開發板';

  @override
  String get deviceCategoryOther => '其他';

  @override
  String get deviceName => '名稱';

  @override
  String get deviceBrand => '品牌';

  @override
  String get deviceModel => '型號';

  @override
  String get deviceCategory => '類別';

  @override
  String get devicePurchaseDate => '購入日期';

  @override
  String get deviceReleaseDate => '發佈時間';

  @override
  String get deviceNotes => '備註';

  @override
  String get deviceLocation => '位置';

  @override
  String get mapPickLocation => '選擇位置';

  @override
  String get mapSearchHint => '搜尋位置...';

  @override
  String get cpuInfo => 'CPU';

  @override
  String get cpuModel => '型號';

  @override
  String get cpuArchitecture => '架構';

  @override
  String get cpuFrequency => '主頻';

  @override
  String get cpuPCores => '大核';

  @override
  String get cpuECores => '小核';

  @override
  String get cpuThreads => '執行緒';

  @override
  String get cpuCache => '快取';

  @override
  String get gpuInfo => 'GPU';

  @override
  String get gpuModel => '型號';

  @override
  String get gpuArchitecture => '架構';

  @override
  String get ram => '記憶體';

  @override
  String get storage => '儲存';

  @override
  String get screenSize => '螢幕尺寸';

  @override
  String get screenResolution => '解析度';

  @override
  String get ppi => 'PPI';

  @override
  String get battery => '電池';

  @override
  String get os => '作業系統';

  @override
  String get addDevice => '新增裝置';

  @override
  String get editDevice => '編輯裝置';

  @override
  String get deleteDevice => '刪除裝置';

  @override
  String deleteDeviceConfirm(String name) {
    return '確定要刪除「$name」嗎？';
  }

  @override
  String get save => '儲存';

  @override
  String get cancel => '取消';

  @override
  String get delete => '刪除';

  @override
  String get noDevices => '還沒有裝置，點選 + 新增一個吧！';

  @override
  String get deviceDetail => '裝置詳情';

  @override
  String get swipeEditHint => '編輯';

  @override
  String get swipeDeleteHint => '刪除';

  @override
  String get fromTemplate => '從範本建立';

  @override
  String get settingsTheme => '主題';

  @override
  String get settingsThemeSystem => '跟隨系統';

  @override
  String get settingsThemeLight => '淺色';

  @override
  String get settingsThemeDark => '深色';

  @override
  String get settingsLanguage => '語言';

  @override
  String get settingsLanguageSystem => '跟隨系統';

  @override
  String get settingsGeneral => '一般';

  @override
  String get settingsData => '資料';

  @override
  String get settingsAbout => '關於';

  @override
  String get settingsVersion => '版本';

  @override
  String get settingsPrivacyPolicy => '隱私政策';

  @override
  String get settingsLicense => '授權條款 (GPLv3)';

  @override
  String get settingsLicenses => '開源授權';

  @override
  String get backupTitle => '備份';

  @override
  String get backupSubtitle => '完整本機備份（資料 + 圖片）';

  @override
  String get backupCreate => '建立備份';

  @override
  String get backupCreated => '備份已建立';

  @override
  String get backupAutoBackup => '自動備份';

  @override
  String get backupRetention => '保留時間';

  @override
  String get backupKeepForever => '永久保留';

  @override
  String backupKeepDays(int days) {
    return '$days 天';
  }

  @override
  String backupHistory(int count) {
    return '歷史紀錄 ($count)';
  }

  @override
  String get backupNoBackups => '暫無備份';

  @override
  String get backupRestore => '還原';

  @override
  String get backupRestoreConfirm => '這將覆蓋目前的資料，確定要繼續嗎？';

  @override
  String get backupRestored => '備份已還原';

  @override
  String get backupRestoreFailed => '還原失敗';

  @override
  String get backupDeleteConfirm => '確定刪除這個備份嗎？';

  @override
  String get exportData => '匯出資料';

  @override
  String get exportAsZip => '匯出為 ZIP';

  @override
  String get exportAsZipDesc => '完整資料壓縮檔（裝置資料 + 圖片），用於備份或遷移';

  @override
  String get exportAsMarkdown => '匯出為 Markdown';

  @override
  String get exportAsMarkdownDesc => '裝置清單及網路、資料集資訊，用於 LLM 個人化學習';

  @override
  String get importData => '匯入資料';

  @override
  String get exportSuccess => '資料匯出成功';

  @override
  String get importSuccess => '資料匯入成功';

  @override
  String get importFailed => '匯入失敗';

  @override
  String get importConfirm => '這將覆蓋目前的資料，確定要繼續嗎？';

  @override
  String get dataMigration => '開啟資料資料夾';

  @override
  String get dataMigrationDesc => '開啟應用程式資料目錄';

  @override
  String get settingsStorageLocation => '儲存位置';

  @override
  String get settingsStoragePathHint => '輸入資料儲存目錄路徑。留空使用預設路徑。';

  @override
  String get settingsDirectoryPath => '目錄路徑';

  @override
  String get settingsResetDefault => '恢復預設';

  @override
  String get settingsResetDefaultLocation => '已恢復預設儲存位置';

  @override
  String get settingsStoragePathUpdated => '儲存路徑已更新';

  @override
  String totalDevices(int count) {
    return '$count 台裝置';
  }

  @override
  String get storageType => '類型';

  @override
  String get storageInterface => '介面';

  @override
  String get storageTypeSsd => 'SSD';

  @override
  String get storageTypeSdCard => 'SD 卡';

  @override
  String get storageTypeHdd => '機械硬碟';

  @override
  String get storageInterfaceM2Nvme => 'M.2 NVMe';

  @override
  String get storageInterfaceSata25 => '2.5\" SATA';

  @override
  String get storageInterfaceM2Sata => 'M.2 SATA';

  @override
  String get storageInterfaceUsb => 'USB';

  @override
  String get ramType => '記憶體類型';

  @override
  String get sortTitle => '排序';

  @override
  String get sortCustom => '自訂順序';

  @override
  String get sortAlphabetical => '字母順序';

  @override
  String get sortPurchaseDate => '購買時間';

  @override
  String get sortReleaseDate => '發佈時間';

  @override
  String get sortAscending => '正序';

  @override
  String get sortSubnet => '子網路';

  @override
  String get sortGroupByCategory => '按類別分組';

  @override
  String get sortReorder => '調整順序…';

  @override
  String get sortByIp => 'IP位址';

  @override
  String get sortExitNodeFirst => '出口節點置頂';

  @override
  String get navNetworks => '網路';

  @override
  String get noNetworks => '還沒有網路，點選 + 新增一個吧！';

  @override
  String get addNetwork => '新增網路';

  @override
  String get editNetwork => '編輯網路';

  @override
  String get deleteNetwork => '刪除網路';

  @override
  String get deleteNetworkConfirm => '這將刪除該網路及其所有裝置分配，確定要繼續嗎？';

  @override
  String get networkName => '名稱';

  @override
  String get networkType => '類型';

  @override
  String get networkSubnet => '子網路';

  @override
  String get networkGateway => '閘道';

  @override
  String get networkDns => 'DNS 伺服器';

  @override
  String get networkNotes => '備註';

  @override
  String get networkNotesHint => '配置資訊、金鑰、備註…';

  @override
  String get networkTypeLan => '區域網路';

  @override
  String get networkTypeTailscale => 'Tailscale';

  @override
  String get networkTypeZerotier => 'ZeroTier';

  @override
  String get networkTypeEasytier => 'EasyTier';

  @override
  String get networkTypeWireguard => 'WireGuard';

  @override
  String get networkTypeOther => '其他';

  @override
  String get networkDevices => '裝置';

  @override
  String get noNetworkDevices => '該網路下還沒有裝置。';

  @override
  String get networkDeviceConfig => '裝置設定';

  @override
  String get networkAddressMode => '位址模式';

  @override
  String get addressModeDhcp => 'DHCP';

  @override
  String get addressModeStatic => '靜態 IP';

  @override
  String get networkIpAddress => 'IP 位址';

  @override
  String get networkHostname => '主機名稱';

  @override
  String get networkExitNode => '出口節點';

  @override
  String get networkPickDevice => '選擇裝置';

  @override
  String get removeDevice => '移除裝置';

  @override
  String get removeDeviceConfirm => '確定從該網路中移除此裝置嗎？';

  @override
  String get settingsConfirm => '確認';

  @override
  String get settingsWebDAVSync => 'WebDAV 同步';

  @override
  String get settingsWebDAVServerURL => '伺服器位址';

  @override
  String get settingsWebDAVUsername => '使用者名稱';

  @override
  String get settingsWebDAVPassword => '密碼';

  @override
  String get settingsWebDAVRemotePath => '遠端路徑';

  @override
  String get settingsWebDAVNextcloud => 'Nextcloud';

  @override
  String get settingsWebDAVTestConnection => '測試連線';

  @override
  String get settingsWebDAVConnectionSuccess => '連線成功';

  @override
  String get settingsWebDAVConnectionFailed => '連線失敗';

  @override
  String get settingsWebDAVConfigSaved => 'WebDAV 設定已儲存';

  @override
  String get settingsWebDAVSyncNow => '立即同步';

  @override
  String get settingsWebDAVSyncing => '同步中…';

  @override
  String get settingsWebDAVSyncSuccess => '同步完成';

  @override
  String get settingsWebDAVSyncFailed => '同步失敗';

  @override
  String settingsWebDAVSyncImageWarnings(int count) {
    return '同步完成，但$count張圖片傳輸失敗';
  }

  @override
  String get settingsWebDAVAutoSync => '自動同步';

  @override
  String get settingsWebDAVAutoSyncDesc => '資料變更時自動同步';

  @override
  String get settingsWebDAVDisconnect => '中斷連線';

  @override
  String get settingsWebDAVConfigRemoved => 'WebDAV 設定已移除';

  @override
  String get backupRestoreModules => '選擇要還原的模組';

  @override
  String get backupSelectAll => '全選';

  @override
  String get backupModuleDevices => '裝置';

  @override
  String get backupModuleNetworks => '網路';

  @override
  String get backupModuleDatasets => '資料集';

  @override
  String get navDataSets => '資料集';

  @override
  String get noDataSets => '還沒有資料集，點選 + 新增一個吧！';

  @override
  String get addDataSet => '新增資料集';

  @override
  String get editDataSet => '編輯資料集';

  @override
  String get deleteDataSet => '刪除資料集';

  @override
  String deleteDataSetConfirm(String name) {
    return '確定要刪除「$name」嗎？';
  }

  @override
  String get dataSetName => '名稱';

  @override
  String get dataSetEmoji => '圖示';

  @override
  String get dataSetStorages => '關聯儲存';

  @override
  String get dataSetNoDeviceStorages => '沒有找到包含儲存的裝置';

  @override
  String get mapViewDevices => '裝置地圖';

  @override
  String get mapViewNetworkDevices => '網路裝置地圖';

  @override
  String get mapNoLocations => '沒有裝置設定了位置資訊。';

  @override
  String get deviceEmoji => '圖示';

  @override
  String get deviceImage => '圖片';

  @override
  String get devicePickImage => '選擇圖片';

  @override
  String get deviceChangeImage => '更換';

  @override
  String get deviceRemoveIcon => '移除圖示';

  @override
  String get deviceSerialNumber => '序號';

  @override
  String get storageBrand => '品牌';

  @override
  String get storageSerialNumber => '序號';

  @override
  String get fetchFromInternet => '線上查詢';

  @override
  String get searchDeviceInfo => '取得裝置資訊';

  @override
  String get searchHint => '搜尋裝置名稱...';

  @override
  String get searchButton => '搜尋';

  @override
  String get searchNoResults => '找不到結果';

  @override
  String get searchApply => '套用';

  @override
  String get searchCurrent => '目前';

  @override
  String get searchFetched => '取得';

  @override
  String get searchDeviceImage => '裝置圖片';

  @override
  String get searchFetchImage => '下載';

  @override
  String get searchFetchingDetail => '正在取得詳細資訊...';

  @override
  String get searchCpuInfo => '搜尋 CPU';

  @override
  String get searchGpuInfo => '搜尋 GPU';

  @override
  String get searchCpuHint => '輸入 CPU 型號...';

  @override
  String get searchGpuHint => '輸入 GPU 型號...';

  @override
  String get searchTemplatePlaceholder => '搜尋…';

  @override
  String get cpuPresetSearch => '搜尋 CPU…';

  @override
  String get gpuPresetSearch => '搜尋 GPU…';

  @override
  String get cpuArchHint => '例：ARM Cortex-A78、x86-64';

  @override
  String get cpuFreqHint => '例：3.5 GHz';

  @override
  String get cpuCacheHint => '例：L2 4MB / L3 32MB';

  @override
  String get gpuArchHint => '例：Ada Lovelace、RDNA 3';

  @override
  String get ramHint => '例：16';

  @override
  String get storageCapacityHint => '例：512';

  @override
  String get storageBrandHint => '例：Samsung、WD';

  @override
  String get screenSizeHint => '例：6.7\"';

  @override
  String get batteryHint => '例：5000 mAh';

  @override
  String get osHint => '例：Windows 11、Android 15';

  @override
  String get locationHint => '例：家、辦公室、東京機房';

  @override
  String get networkSubnetHint => '例：192.168.1.0/24、100.64.0.0/10';

  @override
  String get networkGatewayHint => '例：192.168.1.1';

  @override
  String get networkDnsHint => '例：8.8.8.8、1.1.1.1';

  @override
  String get networkIpHint => '例：192.168.1.100';

  @override
  String get networkHostnameHint => '例：my-server';

  @override
  String get backupModuleImages => '圖片';

  @override
  String syncConflictTitle(String name) {
    return '同步衝突：$name';
  }

  @override
  String get syncConflictBody => '此記錄在上次同步後在兩端均有修改。';

  @override
  String get syncConflictLocalVersion => '本機版本：';

  @override
  String get syncConflictRemoteVersion => '遠端版本：';

  @override
  String get syncConflictKeepLocal => '保留本機';

  @override
  String get syncConflictKeepRemote => '保留遠端';

  @override
  String get trayShow => '顯示';

  @override
  String get trayQuit => '結束';

  @override
  String get settingsMinimizeToTray => '最小化至系統匣';

  @override
  String get settingsCloseToTray => '關閉時最小化至系統匣';

  @override
  String get settingsAutoStart => '開機自動啟動';

  @override
  String get settingsApiServer => 'API 伺服器設定';

  @override
  String get settingsApiEnabled => '本機 API 伺服器';

  @override
  String get settingsApiListenAddress => '監聽位址';

  @override
  String get settingsApiPort => '連接埠';

  @override
  String get settingsApiUsername => '使用者名稱';

  @override
  String get settingsApiPassword => '密碼';

  @override
  String settingsApiRunning(int port) {
    return '正在連接埠 $port 上執行';
  }

  @override
  String get settingsApiStopped => '已停止';

  @override
  String get settingsApiNeedCredentials => '監聽非 localhost 時需設定使用者名稱和密碼';

  @override
  String settingsApiRestarted(int port) {
    return 'API 伺服器已在連接埠 $port 上重啟';
  }

  @override
  String get settingsDesktop => '桌面端';
}
