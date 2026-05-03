import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final text = _getText(locale);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsPrivacyPolicy)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          text,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }

  String _getText(Locale locale) {
    if (locale.languageCode == 'zh' && locale.countryCode == 'TW') {
      return _zhTW;
    }
    switch (locale.languageCode) {
      case 'zh':
        return _zh;
      case 'ja':
        return _ja;
      default:
        return _en;
    }
  }

  static const _en = '''Privacy Policy

Thank you for using MyDevice!!!!!. We take your privacy seriously. This privacy policy explains how the app handles your data.

Data Collection

MyDevice!!!!! does not collect, upload, or share any personal information. The app contains no analytics, advertising trackers, or data collection of any kind.

Data Storage

All data you enter in the app — device information, specs, cover images, and settings — is stored locally on your device. You may change this to a custom path at any time (Desktop Version Only).

Network Access

MyDevice!!!!! accesses the internet only in the following situations:

• CPU/GPU chip search (full flavor only): When you actively search for chip specifications, the app sends requests to TechPowerUp (techpowerup.com), AMD (amd.com), and Intel (intel.com) to retrieve publicly available hardware information such as model names, architectures, core counts, and frequencies. This feature is not included in versions distributed through the App Store or Google Play.

• Map tiles: When you use the map view to set or display device locations, the app loads map tile images from OpenStreetMap (tile.openstreetmap.org).

• Exchange rates: If automatic exchange-rate updates are enabled or you refresh rates manually, the app requests rates from open.er-api.com. Only the base currency code is sent.

• WebDAV sync: If you enable WebDAV cloud sync, the app sends your data to a WebDAV server that you configure yourself. The app does not send data to any other server.

No other network communication takes place.

Third-Party Services

The full-featured version of the app uses the following third-party data sources for chip search:

• TechPowerUp (techpowerup.com) — CPU/GPU specification database
• AMD (amd.com) — CPU/GPU specification database
• Intel (intel.com) — CPU/GPU specification database

The app also uses the following service regardless of flavor:

• OpenStreetMap (openstreetmap.org) — Map tile provider
• open.er-api.com — Currency exchange-rate provider

These services have their own privacy policies, which we encourage you to review. MyDevice!!!!! only retrieves publicly available hardware information, map tiles, and currency rates, and does not send any of your personal data to these services.

Note: Versions distributed through the App Store and Google Play (store flavor) do not include the online chip search feature and do not connect to TechPowerUp, AMD, or Intel.

Data Backup

The app provides a local backup feature. Backup files are stored on your device and include all your device data and cover images. The storage and management of backup files is entirely under your control.

Changes to This Policy

This privacy policy may be updated from time to time. Updated versions will be published within the app or on the relevant distribution channels.''';

  static const _zh = '''隐私政策

感谢您使用 MyDevice!!!!!。我们非常重视您的隐私。本隐私政策说明了应用如何处理您的数据。

数据收集

MyDevice!!!!! 不收集、上传或共享任何个人信息。应用不包含任何分析工具、广告追踪器或数据收集功能。

数据存储

您在应用中输入的所有数据——设备信息、规格参数、封面图片和设置——均存储在您的设备本地。您可以随时更改存储路径（仅桌面版）。

网络访问

MyDevice!!!!! 仅在以下情况下访问互联网：

• CPU/GPU芯片搜索（仅完整版）：当您主动搜索芯片规格时，应用会向 TechPowerUp（techpowerup.com）、AMD（amd.com）和 Intel（intel.com）发送请求，以获取公开的硬件信息，如型号、架构、核心数和频率。通过 App Store 或 Google Play 分发的版本不包含此功能。

• 地图瓦片：当您使用地图视图设置或显示设备位置时，应用会从 OpenStreetMap（tile.openstreetmap.org）加载地图瓦片图片。

• 汇率：如果您启用了自动汇率更新，或手动刷新汇率，应用会向 open.er-api.com 请求汇率。请求中只包含默认币种代码。

• WebDAV 同步：如果您启用了 WebDAV 云同步，应用会将您的数据发送到您自行配置的 WebDAV 服务器。应用不会向其他任何服务器发送数据。

除此之外不进行任何网络通信。

第三方服务

完整版应用使用以下第三方数据源进行芯片搜索：

• TechPowerUp（techpowerup.com）—— CPU/GPU 规格数据库
• AMD（amd.com）—— CPU/GPU 规格数据库
• Intel（intel.com）—— CPU/GPU 规格数据库

无论版本如何，应用还使用以下服务：

• OpenStreetMap（openstreetmap.org）—— 地图瓦片提供商
• open.er-api.com —— 货币汇率提供商

这些服务有各自的隐私政策，建议您查阅。MyDevice!!!!! 仅获取公开的硬件信息、地图瓦片和货币汇率，不会向这些服务发送任何个人数据。

注意：通过 App Store 和 Google Play 分发的版本（商店版）不包含在线芯片搜索功能，不会连接 TechPowerUp、AMD 或 Intel。

数据备份

应用提供本地备份功能。备份文件存储在您的设备上，包含您的所有设备数据和封面图片。备份文件的存储和管理完全由您掌控。

政策变更

本隐私政策可能会不时更新。更新版本将在应用内或相关分发渠道发布。''';

  static const _zhTW = '''隱私政策

感謝您使用 MyDevice!!!!!。我們非常重視您的隱私。本隱私政策說明了應用程式如何處理您的資料。

資料收集

MyDevice!!!!! 不收集、上傳或分享任何個人資訊。應用程式不包含任何分析工具、廣告追蹤器或資料收集功能。

資料儲存

您在應用程式中輸入的所有資料——裝置資訊、規格參數、封面圖片和設定——均儲存在您的裝置本機。您可以隨時更改儲存路徑（僅桌面版）。

網路存取

MyDevice!!!!! 僅在以下情況下存取網際網路：

• CPU/GPU 晶片搜尋（僅完整版）：當您主動搜尋晶片規格時，應用程式會向 TechPowerUp（techpowerup.com）、AMD（amd.com）和 Intel（intel.com）傳送請求，以取得公開的硬體資訊，如型號、架構、核心數和頻率。透過 App Store 或 Google Play 分發的版本不包含此功能。

• 地圖圖磚：當您使用地圖視圖設定或顯示裝置位置時，應用程式會從 OpenStreetMap（tile.openstreetmap.org）載入地圖圖磚圖片。

• 匯率：如果您啟用了自動匯率更新，或手動刷新匯率，應用程式會向 open.er-api.com 請求匯率。請求中只包含預設幣種代碼。

• WebDAV 同步：如果您啟用了 WebDAV 雲端同步，應用程式會將您的資料傳送到您自行設定的 WebDAV 伺服器。應用程式不會向其他任何伺服器傳送資料。

除此之外不進行任何網路通訊。

第三方服務

完整版應用程式使用以下第三方資料來源進行晶片搜尋：

• TechPowerUp（techpowerup.com）—— CPU/GPU 規格資料庫
• AMD（amd.com）—— CPU/GPU 規格資料庫
• Intel（intel.com）—— CPU/GPU 規格資料庫

無論版本如何，應用程式還使用以下服務：

• OpenStreetMap（openstreetmap.org）—— 地圖圖磚提供商
• open.er-api.com —— 貨幣匯率提供商

這些服務有各自的隱私政策，建議您查閱。MyDevice!!!!! 僅取得公開的硬體資訊、地圖圖磚和貨幣匯率，不會向這些服務傳送任何個人資料。

注意：透過 App Store 和 Google Play 分發的版本（商店版）不包含線上晶片搜尋功能，不會連線 TechPowerUp、AMD 或 Intel。

資料備份

應用程式提供本機備份功能。備份檔案儲存在您的裝置上，包含您的所有裝置資料和封面圖片。備份檔案的儲存和管理完全由您掌控。

政策變更

本隱私政策可能會不時更新。更新版本將在應用程式內或相關分發管道發布。''';

  static const _ja = '''プライバシーポリシー

MyDevice!!!!! をご利用いただきありがとうございます。私たちはお客様のプライバシーを重視しています。このプライバシーポリシーは、アプリがお客様のデータをどのように取り扱うかを説明します。

データ収集

MyDevice!!!!! は個人情報の収集、アップロード、共有を一切行いません。アプリにはアナリティクス、広告トラッカー、データ収集機能は含まれていません。

データ保存

アプリに入力されたすべてのデータ（デバイス情報、スペック、カバー画像、設定）は、お客様のデバイスにローカルで保存されます。保存先はいつでも変更できます（デスクトップ版のみ）。

ネットワークアクセス

MyDevice!!!!! は以下の場合にのみインターネットにアクセスします：

• CPU/GPUチップ検索（完全版のみ）：お客様がチップのスペックを検索した際、アプリは TechPowerUp（techpowerup.com）、AMD（amd.com）、Intel（intel.com）にリクエストを送信し、モデル名、アーキテクチャ、コア数、周波数などの公開ハードウェア情報を取得します。App Store または Google Play で配信されるバージョンにはこの機能は含まれていません。

• 地図タイル：デバイスの位置を設定または表示するために地図ビューを使用した際、アプリは OpenStreetMap（tile.openstreetmap.org）から地図タイル画像を読み込みます。

• 為替レート：自動為替レート更新を有効にした場合、または手動でレートを更新した場合、アプリは open.er-api.com にレートをリクエストします。送信されるのは基準通貨コードのみです。

• WebDAV同期：WebDAVクラウド同期を有効にした場合、アプリはお客様が設定したWebDAVサーバーにデータを送信します。それ以外のサーバーにデータを送信することはありません。

上記以外のネットワーク通信は行われません。

サードパーティサービス

完全版アプリはチップ検索のために以下のサードパーティデータソースを使用しています：

• TechPowerUp（techpowerup.com）—— CPU/GPU仕様データベース
• AMD（amd.com）—— CPU/GPU仕様データベース
• Intel（intel.com）—— CPU/GPU仕様データベース

フレーバーに関わらず、アプリは以下のサービスも使用しています：

• OpenStreetMap（openstreetmap.org）—— 地図タイルプロバイダー
• open.er-api.com —— 通貨為替レートプロバイダー

これらのサービスには独自のプライバシーポリシーがあります。ご確認をお勧めします。MyDevice!!!!! は公開されているハードウェア情報、地図タイル、通貨レートのみを取得し、お客様の個人データをこれらのサービスに送信することはありません。

注意：App Store および Google Play で配信されるバージョン（ストア版）にはオンラインチップ検索機能は含まれておらず、TechPowerUp、AMD、Intel には接続しません。

データバックアップ

アプリはローカルバックアップ機能を提供しています。バックアップファイルはお客様のデバイスに保存され、すべてのデバイスデータとカバー画像が含まれます。バックアップファイルの保存と管理はすべてお客様のご判断に委ねられています。

ポリシーの変更

このプライバシーポリシーは随時更新される場合があります。更新版はアプリ内または関連する配信チャンネルで公開されます。''';
}
