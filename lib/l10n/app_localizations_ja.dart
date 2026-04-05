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
}
