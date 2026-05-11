// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'MyDevice!!!!!';

  @override
  String get navDevices => 'デバイス';

  @override
  String get navSettings => '設定';

  @override
  String get deviceCategoryDesktop => 'デスクトップ';

  @override
  String get deviceCategoryLaptop => 'ノートPC';

  @override
  String get deviceCategoryPhone => 'スマートフォン';

  @override
  String get deviceCategoryTablet => 'タブレット';

  @override
  String get deviceCategoryHeadphone => 'ヘッドホン';

  @override
  String get deviceCategoryWatch => 'スマートウォッチ';

  @override
  String get deviceCategoryRouter => 'ルーター';

  @override
  String get deviceCategoryGameConsole => 'ゲーム機';

  @override
  String get deviceCategoryVps => 'VPS';

  @override
  String get deviceCategoryDevBoard => '開発ボード';

  @override
  String get deviceCategoryOther => 'その他';

  @override
  String get deviceName => '名前';

  @override
  String get deviceBrand => 'ブランド';

  @override
  String get deviceModel => 'モデル';

  @override
  String get deviceCategory => 'カテゴリ';

  @override
  String get devicePurchaseDate => '購入日';

  @override
  String get deviceReleaseDate => '発売日';

  @override
  String get deviceNotes => 'メモ';

  @override
  String get deviceLocation => '場所';

  @override
  String get mapPickLocation => '場所を選択';

  @override
  String get mapSearchHint => '場所を検索...';

  @override
  String get cpuInfo => 'CPU';

  @override
  String get cpuModel => 'モデル';

  @override
  String get cpuArchitecture => 'アーキテクチャ';

  @override
  String get cpuFrequency => 'クロック周波数';

  @override
  String get cpuPCores => 'Pコア';

  @override
  String get cpuECores => 'Eコア';

  @override
  String get cpuThreads => 'スレッド';

  @override
  String get cpuCache => 'キャッシュ';

  @override
  String get gpuInfo => 'GPU';

  @override
  String get gpuModel => 'モデル';

  @override
  String get gpuArchitecture => 'アーキテクチャ';

  @override
  String get ram => 'RAM';

  @override
  String get storage => 'ストレージ';

  @override
  String get screenSize => '画面サイズ';

  @override
  String get screenResolution => '解像度';

  @override
  String get ppi => 'PPI';

  @override
  String get battery => 'バッテリー';

  @override
  String get os => 'OS';

  @override
  String get addDevice => 'デバイスを追加';

  @override
  String get editDevice => 'デバイスを編集';

  @override
  String get deleteDevice => 'デバイスを削除';

  @override
  String deleteDeviceConfirm(String name) {
    return '「$name」を削除しますか？';
  }

  @override
  String get save => '保存';

  @override
  String get cancel => 'キャンセル';

  @override
  String get delete => '削除';

  @override
  String get noDevices => 'デバイスがありません。＋をタップして追加しましょう！';

  @override
  String get deviceDetail => 'デバイス詳細';

  @override
  String get swipeEditHint => '編集';

  @override
  String get swipeDeleteHint => '削除';

  @override
  String get fromTemplate => 'テンプレートから作成';

  @override
  String get settingsTheme => 'テーマ';

  @override
  String get settingsThemeSystem => 'システム';

  @override
  String get settingsThemeLight => 'ライト';

  @override
  String get settingsThemeDark => 'ダーク';

  @override
  String get settingsLanguage => '言語';

  @override
  String get settingsLanguageSystem => 'システム';

  @override
  String get settingsGeneral => '一般';

  @override
  String get settingsData => 'データ';

  @override
  String get settingsAbout => 'このアプリについて';

  @override
  String get settingsVersion => 'バージョン';

  @override
  String get settingsPrivacyPolicy => 'プライバシーポリシー';

  @override
  String get settingsLicense => 'ライセンス (GPLv3)';

  @override
  String get settingsLicenses => 'オープンソースライセンス';

  @override
  String get backupTitle => 'バックアップ';

  @override
  String get backupSubtitle => '完全ローカルバックアップ（データ＋画像）';

  @override
  String get backupCreate => 'バックアップを作成';

  @override
  String get backupCreated => 'バックアップを作成しました';

  @override
  String get backupAutoBackup => '自動バックアップ';

  @override
  String get backupRetention => '保持期間';

  @override
  String get backupKeepForever => '永久に保持';

  @override
  String backupKeepDays(int days) {
    return '$days 日間';
  }

  @override
  String backupHistory(int count) {
    return '履歴 ($count)';
  }

  @override
  String get backupNoBackups => 'バックアップはまだありません';

  @override
  String get backupRestore => '復元';

  @override
  String get backupRestoreConfirm => '現在のデータが上書きされます。続行しますか？';

  @override
  String get backupRestored => 'バックアップを復元しました';

  @override
  String get backupRestoreFailed => '復元に失敗しました';

  @override
  String get backupDeleteConfirm => 'このバックアップを削除しますか？';

  @override
  String get exportData => 'データをエクスポート';

  @override
  String get exportAsZip => 'ZIPでエクスポート';

  @override
  String get exportAsZipDesc => '完全データアーカイブ（デバイスデータ＋画像）、バックアップや移行用';

  @override
  String get exportAsMarkdown => 'Markdownでエクスポート';

  @override
  String get exportAsMarkdownDesc => 'ネットワーク・データセット情報付きデバイス一覧、LLMパーソナライズ用';

  @override
  String get importData => 'データをインポート';

  @override
  String get exportSuccess => 'データをエクスポートしました';

  @override
  String get importSuccess => 'データをインポートしました';

  @override
  String get importFailed => 'インポートに失敗しました';

  @override
  String get importConfirm => '現在のデータが上書きされます。続行しますか？';

  @override
  String get dataMigration => 'データフォルダを開く';

  @override
  String get dataMigrationDesc => 'アプリケーションデータのディレクトリを開く';

  @override
  String get settingsStorageLocation => '保存場所';

  @override
  String get settingsStoragePathHint => 'データ保存先のディレクトリパスを入力。空欄でデフォルトを使用。';

  @override
  String get settingsDirectoryPath => 'ディレクトリパス';

  @override
  String get settingsResetDefault => 'デフォルトに戻す';

  @override
  String get settingsResetDefaultLocation => 'デフォルトの保存場所に戻しました';

  @override
  String get settingsStoragePathUpdated => '保存パスを更新しました';

  @override
  String totalDevices(int count) {
    return '$count 台のデバイス';
  }

  @override
  String get storageType => '種類';

  @override
  String get storageInterface => 'インターフェース';

  @override
  String get storageTypeSsd => 'SSD';

  @override
  String get storageTypeSdCard => 'SDカード';

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
  String get ramType => 'RAMタイプ';

  @override
  String get sortTitle => '並べ替え';

  @override
  String get sortCustom => 'カスタム順';

  @override
  String get sortAlphabetical => '五十音順';

  @override
  String get sortPurchaseDate => '購入日';

  @override
  String get sortReleaseDate => '発売日';

  @override
  String get sortAscending => '昇順';

  @override
  String get sortSubnet => 'サブネット';

  @override
  String get sortGroupByCategory => 'カテゴリでグループ';

  @override
  String get sortReorder => '並べ替え…';

  @override
  String get sortByIp => 'IPアドレス';

  @override
  String get sortExitNodeFirst => '出口ノード優先';

  @override
  String get navNetworks => 'ネットワーク';

  @override
  String get noNetworks => 'ネットワークがありません。＋をタップして追加しましょう！';

  @override
  String get addNetwork => 'ネットワークを追加';

  @override
  String get editNetwork => 'ネットワークを編集';

  @override
  String get deleteNetwork => 'ネットワークを削除';

  @override
  String get deleteNetworkConfirm => 'このネットワークとすべてのデバイス割り当てを削除します。続行しますか？';

  @override
  String get networkName => '名前';

  @override
  String get networkType => '種類';

  @override
  String get networkSubnet => 'サブネット';

  @override
  String get networkGateway => 'ゲートウェイ';

  @override
  String get networkDns => 'DNSサーバー';

  @override
  String get networkNotes => 'メモ';

  @override
  String get networkNotesHint => '設定情報、キー、メモ…';

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
  String get networkTypeOther => 'その他';

  @override
  String get networkDevices => 'デバイス';

  @override
  String get noNetworkDevices => 'このネットワークにはまだデバイスがありません。';

  @override
  String get networkDeviceConfig => 'デバイス設定';

  @override
  String get networkAddressMode => 'アドレスモード';

  @override
  String get addressModeDhcp => 'DHCP';

  @override
  String get addressModeStatic => '静的IP';

  @override
  String get networkIpAddress => 'IPアドレス';

  @override
  String get networkHostname => 'ホスト名';

  @override
  String get networkExitNode => '出口ノード';

  @override
  String get networkPickDevice => 'デバイスを選択';

  @override
  String get removeDevice => 'デバイスを削除';

  @override
  String get removeDeviceConfirm => 'このデバイスをネットワークから削除しますか？';

  @override
  String get settingsConfirm => '確認';

  @override
  String get settingsWebDAVSync => 'WebDAV同期';

  @override
  String get settingsWebDAVServerURL => 'サーバーURL';

  @override
  String get settingsWebDAVUsername => 'ユーザー名';

  @override
  String get settingsWebDAVPassword => 'パスワード';

  @override
  String get settingsWebDAVRemotePath => 'リモートパス';

  @override
  String get settingsWebDAVNextcloud => 'Nextcloud';

  @override
  String get settingsWebDAVTestConnection => '接続テスト';

  @override
  String get settingsWebDAVConnectionSuccess => '接続に成功しました';

  @override
  String get settingsWebDAVConnectionFailed => '接続に失敗しました';

  @override
  String get settingsWebDAVConfigSaved => 'WebDAV設定を保存しました';

  @override
  String get settingsWebDAVSyncNow => '今すぐ同期';

  @override
  String get settingsWebDAVSyncing => '同期中…';

  @override
  String get settingsWebDAVSyncSuccess => '同期が完了しました';

  @override
  String get settingsWebDAVSyncFailed => '同期に失敗しました';

  @override
  String settingsWebDAVSyncImageWarnings(int count) {
    return '同期完了（画像$count件の転送に失敗）';
  }

  @override
  String get settingsWebDAVAutoSync => '自動同期';

  @override
  String get settingsWebDAVAutoSyncDesc => 'データ変更時に自動的に同期';

  @override
  String get settingsWebDAVDisconnect => '切断';

  @override
  String get settingsWebDAVConfigRemoved => 'WebDAV設定を削除しました';

  @override
  String get backupRestoreModules => '復元するモジュールを選択';

  @override
  String get backupSelectAll => 'すべて選択';

  @override
  String get backupModuleDevices => 'デバイス';

  @override
  String get backupModuleNetworks => 'ネットワーク';

  @override
  String get backupModuleDatasets => 'データセット';

  @override
  String get navDataSets => 'データセット';

  @override
  String get noDataSets => 'データセットがありません。＋をタップして追加しましょう！';

  @override
  String get addDataSet => 'データセットを追加';

  @override
  String get editDataSet => 'データセットを編集';

  @override
  String get deleteDataSet => 'データセットを削除';

  @override
  String deleteDataSetConfirm(String name) {
    return '「$name」を削除しますか？';
  }

  @override
  String get dataSetName => '名前';

  @override
  String get dataSetEmoji => '絵文字';

  @override
  String get dataSetStorages => 'リンクされたストレージ';

  @override
  String get dataSetNoDeviceStorages => 'ストレージを持つデバイスが見つかりません';

  @override
  String get mapViewDevices => 'デバイスマップ';

  @override
  String get mapViewNetworkDevices => 'ネットワークデバイスマップ';

  @override
  String get mapNoLocations => '位置情報が設定されているデバイスがありません。';

  @override
  String get deviceEmoji => '絵文字';

  @override
  String get deviceImage => '画像';

  @override
  String get devicePickImage => '画像を選択';

  @override
  String get deviceChangeImage => '変更';

  @override
  String get deviceRemoveIcon => 'アイコンを削除';

  @override
  String get deviceSerialNumber => 'シリアル番号';

  @override
  String get storageBrand => 'ブランド';

  @override
  String get storageSerialNumber => 'シリアル番号';

  @override
  String get fetchFromInternet => 'オンライン検索';

  @override
  String get searchDeviceInfo => 'デバイス情報を取得';

  @override
  String get searchHint => 'デバイス名を検索...';

  @override
  String get searchButton => '検索';

  @override
  String get searchNoResults => '結果が見つかりません';

  @override
  String get searchApply => '適用';

  @override
  String get searchCurrent => '現在';

  @override
  String get searchFetched => '取得';

  @override
  String get searchDeviceImage => 'デバイス画像';

  @override
  String get searchFetchImage => 'ダウンロード';

  @override
  String get searchFetchingDetail => '詳細を取得中...';

  @override
  String get searchCpuInfo => 'CPU を検索';

  @override
  String get searchGpuInfo => 'GPU を検索';

  @override
  String get searchCpuHint => 'CPUモデルを入力...';

  @override
  String get searchGpuHint => 'GPUモデルを入力...';

  @override
  String get searchTemplatePlaceholder => '検索…';

  @override
  String get cpuPresetSearch => 'CPUを検索…';

  @override
  String get gpuPresetSearch => 'GPUを検索…';

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
  String get locationHint => '例：自宅、オフィス、東京DC';

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
  String get backupModuleImages => '画像';

  @override
  String syncConflictTitle(String name) {
    return '同期の競合：$name';
  }

  @override
  String get syncConflictBody => 'このレコードは最後の同期以降、両端で変更されています。';

  @override
  String get syncConflictLocalVersion => 'ローカル版：';

  @override
  String get syncConflictRemoteVersion => 'リモート版：';

  @override
  String get syncConflictKeepLocal => 'ローカルを保持';

  @override
  String get syncConflictKeepRemote => 'リモートを保持';

  @override
  String get trayShow => '表示';

  @override
  String get trayQuit => '終了';

  @override
  String get settingsMinimizeToTray => 'トレイに最小化';

  @override
  String get settingsCloseToTray => '閉じるときトレイに格納';

  @override
  String get settingsAutoStart => '起動時に自動実行';

  @override
  String get settingsApiServer => 'APIサーバー設定';

  @override
  String get settingsApiEnabled => 'ローカルAPIサーバー';

  @override
  String get settingsApiListenAddress => 'リッスンアドレス';

  @override
  String get settingsApiPort => 'ポート';

  @override
  String get settingsApiUsername => 'ユーザー名';

  @override
  String get settingsApiPassword => 'パスワード';

  @override
  String settingsApiRunning(int port) {
    return 'ポート$portで実行中';
  }

  @override
  String get settingsApiStopped => '停止中';

  @override
  String get settingsApiNeedCredentials =>
      'localhost以外でリッスンする場合、ユーザー名とパスワードを設定してください';

  @override
  String settingsApiRestarted(int port) {
    return 'APIサーバーをポート$portで再起動しました';
  }

  @override
  String get settingsDesktop => 'デスクトップ';

  @override
  String get lifecycleAndFinance => 'ライフサイクルと費用';

  @override
  String get deviceStatus => 'ステータス';

  @override
  String get statusInService => '稼働中';

  @override
  String get statusRetired => '退役済み';

  @override
  String get statusSold => '売却済み';

  @override
  String get filterAll => 'すべて';

  @override
  String get deviceRetired => '退役済み';

  @override
  String get deviceRetiredDate => '退役日';

  @override
  String get deviceSold => '売却済み';

  @override
  String get acquisitionType => '取得方法';

  @override
  String get acquisitionPurchased => '一括購入';

  @override
  String get acquisitionLeased => 'リース';

  @override
  String get acquisitionPurchasedWithSubscription => '購入 + サブスク';

  @override
  String get acquisitionOther => 'その他';

  @override
  String get optionalNone => '未設定';

  @override
  String get purchasePrice => '購入価格';

  @override
  String get soldPrice => '売却価格';

  @override
  String get priceAmount => '金額';

  @override
  String get exchangeRateAuto => '自動為替レートを使う';

  @override
  String get exchangeRateAutoDisabled =>
      '設定で自動更新が無効です。保存済みレートまたは内蔵の予備レートを使用します。';

  @override
  String get exchangeRateManual => '手動為替レート';

  @override
  String exchangeRateManualHint(String from, String to) {
    return '1 $from = ? $to';
  }

  @override
  String get exchangeRateManualRequired => '手動為替レートを入力してください。';

  @override
  String get exchangeRateUnavailable => '為替レートを取得できません。レートを更新するか手動で入力してください。';

  @override
  String get recurringCosts => '継続費用';

  @override
  String get recurringCostType => '種類';

  @override
  String get recurringCostName => '名前';

  @override
  String get recurringCostNameHint => '例: AppleCare+、リース料金';

  @override
  String get recurringCostPrice => '継続価格';

  @override
  String get recurringCostLease => 'リース';

  @override
  String get recurringCostInsurance => '保険';

  @override
  String get recurringCostSubscription => 'サブスク';

  @override
  String get recurringCostOther => 'その他';

  @override
  String get billingCycle => '請求周期';

  @override
  String get billingMonthly => '毎月';

  @override
  String get billingYearly => '毎年';

  @override
  String get financialOverview => '財務概要';

  @override
  String get financialTotalCost => '総コスト';

  @override
  String get financialDailyCost => '日次コスト';

  @override
  String get financialAssetDistribution => '資産分布';

  @override
  String get financialDailyCostLogTrend => '日次コスト推移（対数）';

  @override
  String get financialDevicesWithFinance => '記録済み';

  @override
  String get financialHistory => '履歴';

  @override
  String get financialFutureTrend => '将来推移';

  @override
  String get financialRange1Year => '1年';

  @override
  String get financialRange3Years => '3年';

  @override
  String get financialRangeAll => 'すべて';

  @override
  String get financialNoData => '財務データがありません';

  @override
  String get settingsDefaultCurrency => '既定通貨';

  @override
  String get settingsAutoUpdateExchangeRates => '為替レートを自動更新';

  @override
  String get settingsRefreshExchangeRates => '為替レートを更新';

  @override
  String get exchangeRateUpdated => '為替レートを更新しました';

  @override
  String get exchangeRateUpdateFailed => '為替レートの更新に失敗しました';

  @override
  String get navServices => 'サービス';

  @override
  String get servicesOverview => '概要';

  @override
  String get servicesByDevice => 'デバイス';

  @override
  String get serviceRoutes => 'ルート';

  @override
  String get servicePorts => 'ポート';

  @override
  String get noServices => 'サービスがありません。デバイス上のサービスを追加して、ポートとルートを記録できます。';

  @override
  String get noServiceRoutes => 'サービスルートがありません。';

  @override
  String get addService => 'サービスを追加';

  @override
  String get editService => 'サービスを編集';

  @override
  String get deleteService => 'サービスを削除';

  @override
  String deleteServiceConfirm(String name) {
    return 'サービス「$name」を削除しますか？このサービスからのルートも削除されます。';
  }

  @override
  String get serviceName => 'サービス名';

  @override
  String get serviceNameRequired => 'サービス名を入力してください。';

  @override
  String get serviceDevice => 'デバイス';

  @override
  String get serviceTemplate => 'テンプレート';

  @override
  String get serviceCustom => 'カスタムサービス';

  @override
  String get servicePickTemplate => 'サービステンプレートを選択';

  @override
  String get serviceCustomTemplateDesc => '空のサービス記録から開始します';

  @override
  String get serviceFeaturedTemplate => 'おすすめ';

  @override
  String get serviceIcon => 'アイコン名';

  @override
  String get serviceKind => '種類';

  @override
  String get serviceRuntime => '実行方式';

  @override
  String get serviceState => '状態';

  @override
  String get serviceEndpoints => 'エンドポイント';

  @override
  String get serviceEndpoint => 'エンドポイント';

  @override
  String get addServiceEndpoint => 'エンドポイントを追加';

  @override
  String get editServiceEndpoint => 'エンドポイントを編集';

  @override
  String get serviceEndpointLabel => 'ラベル';

  @override
  String get serviceProtocol => 'プロトコル';

  @override
  String get serviceTransport => 'トランスポート';

  @override
  String get servicePort => 'ポート';

  @override
  String get servicePortEnd => '終了ポート';

  @override
  String get serviceBindAddress => 'バインドアドレス';

  @override
  String get servicePath => 'パス';

  @override
  String get serviceScope => 'スコープ';

  @override
  String get servicePrimaryEndpoint => '主要エンドポイント';

  @override
  String get serviceDockerCompose => 'Docker Compose';

  @override
  String get copyServiceCompose => 'Composeをコピー';

  @override
  String get serviceComposeCopied => 'Docker Composeをコピーしました';

  @override
  String get addServiceRoute => 'ルートを追加';

  @override
  String get editServiceRoute => 'ルートを編集';

  @override
  String get deleteServiceRoute => 'ルートを削除';

  @override
  String deleteServiceRouteConfirm(String name) {
    return 'ルート「$name」を削除しますか？';
  }

  @override
  String get serviceRouteName => 'ルート名';

  @override
  String get routeSourceService => '元サービス';

  @override
  String get serviceAccessLevel => 'アクセスレベル';

  @override
  String get serviceFinalUrl => '最終URL / アドレス';

  @override
  String get serviceAddAccess => 'アクセス方式を追加';

  @override
  String get serviceAdvancedRoute => '詳細ルート';

  @override
  String get serviceTopology => 'サービストポロジー';

  @override
  String get serviceTopologyHint => 'トポロジーを開くとノード詳細、ズーム、回転、PNGエクスポートを使えます。';

  @override
  String get serviceOpenTopology => 'トポロジーを開く';

  @override
  String get serviceTopologySelectMode => '選択';

  @override
  String get serviceTopologyMoveMode => '移動 / ズーム';

  @override
  String get serviceRotateTopology => 'トポロジーを回転';

  @override
  String get serviceExportTopologyImage => 'PNGを書き出し';

  @override
  String get shareCopy => 'コピー';

  @override
  String get shareCopied => '画像をクリップボードにコピーしました';

  @override
  String get shareSaveAs => '名前を付けて保存';

  @override
  String get shareSaved => '画像を保存しました';

  @override
  String get shareFailed => '共有に失敗しました';

  @override
  String get serviceAccessMethod => 'アクセス方式';

  @override
  String get serviceRelayService => '中継 / プロキシサービス';

  @override
  String get serviceRemoteDevice => 'リモートデバイス / VPS';

  @override
  String get serviceRemoteHost => 'リモートホスト / IP';

  @override
  String get serviceRemotePort => 'リモートポート';

  @override
  String get serviceRemotePortRequired => '有効なリモートポートを入力してください。';

  @override
  String get serviceDomains => 'ドメイン / 公開先';

  @override
  String get serviceDomainsHint => 'ポートマッピングでは任意です。1行に1つ、またはカンマ区切りで入力します。';

  @override
  String get serviceAccessTargetsHint =>
      '1行に1つのURLまたはアドレスを入力します。複数入力しても同じアクセスルートにまとめます。';

  @override
  String get serviceAccessTargetRequired => '少なくとも1つのURLまたはアドレスを入力してください。';

  @override
  String get routeHops => 'ルートホップ';

  @override
  String get addRouteHop => 'ホップを追加';

  @override
  String get editRouteHop => 'ホップを編集';

  @override
  String get routeHopType => 'ホップ種別';

  @override
  String get routeMethod => '方式';

  @override
  String get routeHopService => 'ホップサービス';

  @override
  String get routeManualHop => '手動ホップ';

  @override
  String get routeHopLabel => 'ホップラベル';

  @override
  String get routeScheme => 'スキーム';

  @override
  String get routeHost => 'ホスト';

  @override
  String get activeServices => '稼働サービス';

  @override
  String get serviceDevices => 'デバイス';

  @override
  String get publicRoutes => '公開ルート';

  @override
  String get serviceWarnings => '警告';

  @override
  String get servicePortConflicts => 'ポート競合';

  @override
  String get servicePortUsage => 'ポート使用状況';

  @override
  String get servicePotentialConflict => '可能性';

  @override
  String get serviceAnyAddress => '任意アドレス';

  @override
  String servicePortConflict(String device, int port) {
    return '$device: ポート $port は複数のサービスで使われている可能性があります';
  }

  @override
  String get serviceRoutePreview => 'ルートプレビュー';

  @override
  String get serviceMoveUp => '上へ';

  @override
  String get serviceMoveDown => '下へ';

  @override
  String serviceWarningMissingDevice(String name) {
    return '$name: デバイスが見つかりません';
  }

  @override
  String serviceWarningInactiveDevice(String name) {
    return '$name: デバイスは稼働中ではありません';
  }

  @override
  String serviceWarningMissingNetwork(String name) {
    return '$name: エンドポイントのネットワークが見つかりません';
  }

  @override
  String serviceWarningMissingSource(String name) {
    return '$name: 元サービスが見つかりません';
  }

  @override
  String serviceWarningMissingSourceEndpoint(String name) {
    return '$name: 元エンドポイントが見つかりません';
  }

  @override
  String serviceWarningMissingHopService(String name) {
    return '$name: ホップサービスが見つかりません';
  }

  @override
  String serviceWarningMissingHopEndpoint(String name) {
    return '$name: ホップエンドポイントが見つかりません';
  }

  @override
  String serviceWarningMissingHopDevice(String name) {
    return '$name: ホップデバイスが見つかりません';
  }

  @override
  String serviceWarningEmptyRoute(String name) {
    return '$name: ルートにホップがありません';
  }

  @override
  String serviceWarningPublicRouteMissingUrl(String name) {
    return '$name: 公開ルートに最終URLがありません';
  }

  @override
  String serviceWarningDuplicateFinalUrl(String name) {
    return '$name: 最終URLが重複しています';
  }

  @override
  String serviceCount(int count) {
    return '$count 件のサービス';
  }

  @override
  String serviceRouteCount(int count) {
    return '$count 件のルート';
  }

  @override
  String get backupModuleServices => 'サービス';
}
