import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/utils/adaptive_layout.dart';

class PrivacyPolicyPage extends StatelessWidget {
  /// Purpose: Create a privacy policy page instance.
  /// Inputs: None.
  /// Returns: A new `PrivacyPolicyPage` instance.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: None.
  const PrivacyPolicyPage({super.key});

  /// Purpose: Build the current widget subtree for the active UI state.
  /// Inputs: `context`.
  /// Returns: The widget tree for the current state.
  /// Side effects: Creates UI widgets from the current state.
  /// Notes: Keep this method cheap because Flutter may call it often.
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context);
    final text = _getText(locale);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsPrivacyPolicy)),
      // Prose is capped at `readingMaxWidth` and centred: width only, so a
      // phone is unchanged and a desktop window keeps a readable measure.
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: readingMaxWidth),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ),
    );
  }

  /// Purpose: Provide the internal get text helper for this file.
  /// Inputs: `locale`.
  /// Returns: `String`.
  /// Side effects: May update UI state or trigger user-facing flows.
  /// Notes: Internal helper used within this file only.
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

• CPU/GPU chip search (full flavor only): When you actively search for chip specifications, the app sends requests to TechPowerUp (techpowerup.com), AMD (amd.com), and Intel (intel.com) to retrieve publicly available hardware information such as model names, architectures, core counts, and frequencies. Locating those pages also sends your search term to Startpage (startpage.com), which the app uses purely to resolve a product URL. This feature is not included in versions distributed through the App Store or Google Play.
• Device spec search (full flavor only): When you actively search for a device, the app sends the text you typed to Notebookcheck (notebookcheck.net) and PhoneDB (phonedb.net), for Apple products also to Apple Support (support.apple.com), and, only when none of these finds the device, to Wikipedia (en.wikipedia.org), to retrieve publicly available specifications such as chipset, memory, display, battery, operating system, and release date. If you then choose to download a device image, the app fetches that image from the same source (Apple's and Wikimedia's image servers for those two). This feature is not included in versions distributed through the App Store or Google Play.

• Map tiles: When you use the map view to set or display device locations, the app loads map tile images from OpenStreetMap (tile.openstreetmap.org).

• Exchange rates: If automatic exchange-rate updates are enabled or you refresh rates manually, the app requests rates from open.er-api.com. Only the base currency code is sent.

• WebDAV sync: If you enable WebDAV cloud sync, the app sends your data to a WebDAV server that you configure yourself. The app does not send data to any other server.

No other network communication takes place.

Third-Party Services

The full-featured version of the app uses the following third-party data sources for chip search:

• TechPowerUp (techpowerup.com) — CPU/GPU specification database
• Startpage (startpage.com) — used only to locate the chip pages above
• Notebookcheck (notebookcheck.net) — device specification database
• PhoneDB (phonedb.net) — device specification database
• Apple Support (support.apple.com, cdsassets.apple.com) — Apple product tech specs
• Wikipedia (en.wikipedia.org, upload.wikimedia.org) — device articles, used as a fallback
• AMD (amd.com) — CPU/GPU specification database
• Intel (intel.com) — CPU/GPU specification database

The app also uses the following service regardless of flavor:

• OpenStreetMap (openstreetmap.org) — Map tile provider
• open.er-api.com — Currency exchange-rate provider

These services have their own privacy policies, which we encourage you to review. MyDevice!!!!! only retrieves publicly available hardware information, map tiles, and currency rates, and does not send any of your personal data to these services.

Note: Versions distributed through the App Store and Google Play (store flavor) do not include the online chip or device search features, and do not connect to TechPowerUp, AMD, Intel, Startpage, Notebookcheck, PhoneDB, Apple Support, or Wikipedia.

On-Device AI (optional, since 1.6.0)

The Financial Overview and Services pages can optionally show short summaries and suggestions written by the language model built into your device — Gemini Nano through Android AICore, or the model that is part of Apple Intelligence on iOS 26 and macOS 26 or later. This is off by default and runs only after you turn on "Use on-device AI" in Settings. It is not available on Windows or Linux.

• Everything the model does happens on your device. It is given only figures the app has already calculated: for the Financial Overview, cost totals and daily costs, cost by category, recurring-cost totals and the names of a few devices; for Services, counts of services, endpoints, access paths, ports and warnings by type. Serial numbers, notes, locations, host names, IP addresses, URLs and port numbers are never given to it.

• On Android, the model is downloaded by the AICore system service from Google, and only when you tap Download in Settings. On Apple devices the model is part of Apple Intelligence and is managed by the system.

• Generated results stay on your device: they are neither synced, backed up nor exported, and you can clear them in Settings. No cloud model is used, including Apple's Private Cloud Compute.

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

• CPU/GPU芯片搜索（仅完整版）：当您主动搜索芯片规格时，应用会向 TechPowerUp（techpowerup.com）、AMD（amd.com）和 Intel（intel.com）发送请求，以获取公开的硬件信息，如型号、架构、核心数和频率。定位这些页面时还会将搜索词发送至 Startpage（startpage.com），应用仅用它解析产品页地址。通过 App Store 或 Google Play 分发的版本不包含此功能。
• 设备规格搜索（仅完整版）：当您主动搜索设备时，应用会将您输入的文本发送至 Notebookcheck（notebookcheck.net）和 PhoneDB（phonedb.net）；对 Apple 产品还会发送至 Apple 支持（support.apple.com）；仅当以上来源都找不到该设备时，才会发送至维基百科（en.wikipedia.org），以获取公开的规格信息，如芯片、内存、屏幕、电池、操作系统和发布日期。若您随后选择下载设备图片，应用会从同一来源获取该图片（后两者分别为 Apple 和 Wikimedia 的图片服务器）。通过 App Store 或 Google Play 分发的版本不包含此功能。

• 地图瓦片：当您使用地图视图设置或显示设备位置时，应用会从 OpenStreetMap（tile.openstreetmap.org）加载地图瓦片图片。

• 汇率：如果您启用了自动汇率更新，或手动刷新汇率，应用会向 open.er-api.com 请求汇率。请求中只包含默认币种代码。

• WebDAV 同步：如果您启用了 WebDAV 云同步，应用会将您的数据发送到您自行配置的 WebDAV 服务器。应用不会向其他任何服务器发送数据。

除此之外不进行任何网络通信。

第三方服务

完整版应用使用以下第三方数据源进行芯片搜索：

• TechPowerUp（techpowerup.com）—— CPU/GPU 规格数据库
• Startpage（startpage.com）—— 仅用于定位上述芯片页面
• Notebookcheck（notebookcheck.net）—— 设备规格数据库
• PhoneDB（phonedb.net）—— 设备规格数据库
• Apple 支持（support.apple.com、cdsassets.apple.com）—— Apple 产品技术规格
• 维基百科（en.wikipedia.org、upload.wikimedia.org）—— 设备条目，作为后备来源
• AMD（amd.com）—— CPU/GPU 规格数据库
• Intel（intel.com）—— CPU/GPU 规格数据库

无论版本如何，应用还使用以下服务：

• OpenStreetMap（openstreetmap.org）—— 地图瓦片提供商
• open.er-api.com —— 货币汇率提供商

这些服务有各自的隐私政策，建议您查阅。MyDevice!!!!! 仅获取公开的硬件信息、地图瓦片和货币汇率，不会向这些服务发送任何个人数据。

注意：通过 App Store 和 Google Play 分发的版本（商店版）不包含在线芯片搜索和设备搜索功能，不会连接 TechPowerUp、AMD、Intel、Startpage、Notebookcheck、PhoneDB、Apple 支持或维基百科。

端侧 AI（可选，自 1.6.0 起）

财务总览和服务页面可以选择显示由您设备内置的语言模型写出的简短总结与建议——Android 上通过 AICore 使用 Gemini Nano，iOS 26 和 macOS 26 及以上使用 Apple Intelligence 的模型。此功能默认关闭，只有在您于设置中开启「使用端侧 AI」后才会运行。Windows 和 Linux 上不提供。

• 模型的所有处理都在您的设备上完成。它只会拿到应用已经算好的数字：财务总览为成本合计和日均成本、按类别的成本、周期费用合计以及少数几台设备的名称；服务为按类型统计的服务、端点、访问路径、端口和警告数量。序列号、备注、位置、主机名、IP 地址、URL 和端口号永远不会交给模型。

• 在 Android 上，模型由系统服务 AICore 从 Google 下载，并且只在您于设置中点「下载」时才开始。在 Apple 设备上，模型属于 Apple Intelligence，由系统管理。

• 生成的结果只保存在您的设备上：不会同步、备份或导出，您可以在设置中清除。不使用任何云端模型，包括 Apple 的私有云计算（Private Cloud Compute）。

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

• CPU/GPU 晶片搜尋（僅完整版）：當您主動搜尋晶片規格時，應用程式會向 TechPowerUp（techpowerup.com）、AMD（amd.com）和 Intel（intel.com）傳送請求，以取得公開的硬體資訊，如型號、架構、核心數和頻率。定位這些頁面時還會將搜尋詞傳送至 Startpage（startpage.com），應用程式僅用它解析產品頁網址。透過 App Store 或 Google Play 分發的版本不包含此功能。
• 裝置規格搜尋（僅完整版）：當您主動搜尋裝置時，應用程式會將您輸入的文字傳送至 Notebookcheck（notebookcheck.net）和 PhoneDB（phonedb.net）；對 Apple 產品也會傳送至 Apple 支援（support.apple.com）；僅當以上來源都找不到該裝置時，才會傳送至維基百科（en.wikipedia.org），以取得公開的規格資訊，如晶片、記憶體、螢幕、電池、作業系統和發表日期。若您隨後選擇下載裝置圖片，應用程式會從同一來源取得該圖片（後兩者分別為 Apple 和 Wikimedia 的圖片伺服器）。透過 App Store 或 Google Play 分發的版本不包含此功能。

• 地圖圖磚：當您使用地圖視圖設定或顯示裝置位置時，應用程式會從 OpenStreetMap（tile.openstreetmap.org）載入地圖圖磚圖片。

• 匯率：如果您啟用了自動匯率更新，或手動刷新匯率，應用程式會向 open.er-api.com 請求匯率。請求中只包含預設幣種代碼。

• WebDAV 同步：如果您啟用了 WebDAV 雲端同步，應用程式會將您的資料傳送到您自行設定的 WebDAV 伺服器。應用程式不會向其他任何伺服器傳送資料。

除此之外不進行任何網路通訊。

第三方服務

完整版應用程式使用以下第三方資料來源進行晶片搜尋：

• TechPowerUp（techpowerup.com）—— CPU/GPU 規格資料庫
• Startpage（startpage.com）—— 僅用於定位上述晶片頁面
• Notebookcheck（notebookcheck.net）—— 裝置規格資料庫
• PhoneDB（phonedb.net）—— 裝置規格資料庫
• Apple 支援（support.apple.com、cdsassets.apple.com）—— Apple 產品技術規格
• 維基百科（en.wikipedia.org、upload.wikimedia.org）—— 裝置條目，作為備援來源
• AMD（amd.com）—— CPU/GPU 規格資料庫
• Intel（intel.com）—— CPU/GPU 規格資料庫

無論版本如何，應用程式還使用以下服務：

• OpenStreetMap（openstreetmap.org）—— 地圖圖磚提供商
• open.er-api.com —— 貨幣匯率提供商

這些服務有各自的隱私政策，建議您查閱。MyDevice!!!!! 僅取得公開的硬體資訊、地圖圖磚和貨幣匯率，不會向這些服務傳送任何個人資料。

注意：透過 App Store 和 Google Play 分發的版本（商店版）不包含線上晶片搜尋和裝置搜尋功能，不會連線 TechPowerUp、AMD、Intel、Startpage、Notebookcheck、PhoneDB、Apple 支援或維基百科。

裝置端 AI（可選，自 1.6.0 起）

財務總覽和服務頁面可以選擇顯示由您裝置內建的語言模型寫出的簡短總結與建議——Android 上透過 AICore 使用 Gemini Nano，iOS 26 和 macOS 26 及以上使用 Apple Intelligence 的模型。此功能預設關閉，只有在您於設定中開啟「使用裝置端 AI」後才會執行。Windows 和 Linux 上不提供。

• 模型的所有處理都在您的裝置上完成。它只會拿到應用程式已經算好的數字：財務總覽為成本合計和日均成本、按類別的成本、週期費用合計以及少數幾台裝置的名稱；服務為按類型統計的服務、端點、存取路徑、連接埠和警告數量。序號、備註、位置、主機名稱、IP 位址、URL 和連接埠號永遠不會交給模型。

• 在 Android 上，模型由系統服務 AICore 從 Google 下載，並且只在您於設定中點「下載」時才開始。在 Apple 裝置上，模型屬於 Apple Intelligence，由系統管理。

• 生成的結果只儲存在您的裝置上：不會同步、備份或匯出，您可以在設定中清除。不使用任何雲端模型，包括 Apple 的私有雲運算（Private Cloud Compute）。

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

• CPU/GPUチップ検索（完全版のみ）：お客様がチップのスペックを検索した際、アプリは TechPowerUp（techpowerup.com）、AMD（amd.com）、Intel（intel.com）にリクエストを送信し、モデル名、アーキテクチャ、コア数、周波数などの公開ハードウェア情報を取得します。これらのページを特定する際、検索語は Startpage（startpage.com）にも送信されます。アプリは製品ページの URL を解決する目的でのみ使用します。App Store または Google Play で配信されるバージョンにはこの機能は含まれていません。
• デバイススペック検索（完全版のみ）：お客様がデバイスを検索した際、アプリは入力されたテキストを Notebookcheck（notebookcheck.net）および PhoneDB（phonedb.net）に、Apple 製品の場合は Apple サポート（support.apple.com）にも送信し、これらのいずれでも見つからない場合に限り Wikipedia（en.wikipedia.org）に送信して、チップセット、メモリ、ディスプレイ、バッテリー、オペレーティングシステム、発売日などの公開スペック情報を取得します。その後デバイス画像のダウンロードを選択した場合、アプリは同じ情報源から画像を取得します（後の二つはそれぞれ Apple と Wikimedia の画像サーバー）。App Store または Google Play で配信されるバージョンにはこの機能は含まれていません。

• 地図タイル：デバイスの位置を設定または表示するために地図ビューを使用した際、アプリは OpenStreetMap（tile.openstreetmap.org）から地図タイル画像を読み込みます。

• 為替レート：自動為替レート更新を有効にした場合、または手動でレートを更新した場合、アプリは open.er-api.com にレートをリクエストします。送信されるのは基準通貨コードのみです。

• WebDAV同期：WebDAVクラウド同期を有効にした場合、アプリはお客様が設定したWebDAVサーバーにデータを送信します。それ以外のサーバーにデータを送信することはありません。

上記以外のネットワーク通信は行われません。

サードパーティサービス

完全版アプリはチップ検索のために以下のサードパーティデータソースを使用しています：

• TechPowerUp（techpowerup.com）—— CPU/GPU仕様データベース
• Startpage（startpage.com）—— 上記チップページの特定にのみ使用
• Notebookcheck（notebookcheck.net）—— デバイス仕様データベース
• PhoneDB（phonedb.net）—— デバイス仕様データベース
• Apple サポート（support.apple.com、cdsassets.apple.com）—— Apple 製品の技術仕様
• Wikipedia（en.wikipedia.org、upload.wikimedia.org）—— デバイスの記事（フォールバック）
• AMD（amd.com）—— CPU/GPU仕様データベース
• Intel（intel.com）—— CPU/GPU仕様データベース

フレーバーに関わらず、アプリは以下のサービスも使用しています：

• OpenStreetMap（openstreetmap.org）—— 地図タイルプロバイダー
• open.er-api.com —— 通貨為替レートプロバイダー

これらのサービスには独自のプライバシーポリシーがあります。ご確認をお勧めします。MyDevice!!!!! は公開されているハードウェア情報、地図タイル、通貨レートのみを取得し、お客様の個人データをこれらのサービスに送信することはありません。

注意：App Store および Google Play で配信されるバージョン（ストア版）にはオンラインのチップ検索およびデバイス検索機能は含まれておらず、TechPowerUp、AMD、Intel、Startpage、Notebookcheck、PhoneDB、Apple サポート、Wikipedia には接続しません。

オンデバイスAI（任意、1.6.0 以降）

財務概要とサービスの各ページでは、端末に内蔵された言語モデル（Android では AICore 経由の Gemini Nano、iOS 26 / macOS 26 以降では Apple Intelligence のモデル）が書いた短い要約と提案を表示できます。初期状態ではオフで、設定で「オンデバイスAIを使う」をオンにした後にのみ動作します。Windows と Linux では利用できません。

• モデルの処理はすべて端末内で行われます。モデルに渡されるのは、アプリが計算済みの数値だけです：財務概要では費用の合計と1日あたりの費用、カテゴリ別の費用、継続費用の合計と数台のデバイス名、サービスでは種類別のサービス・エンドポイント・アクセス経路・ポート・警告の件数です。シリアル番号、メモ、場所、ホスト名、IP アドレス、URL、ポート番号がモデルに渡されることはありません。

• Android では、モデルは AICore システムサービスが Google からダウンロードし、設定で「ダウンロード」をタップしたときだけ行われます。Apple のデバイスでは、モデルは Apple Intelligence の一部としてシステムが管理します。

• 生成された結果は端末内にのみ保存され、同期・バックアップ・エクスポートされることはなく、設定から消去できます。Apple の Private Cloud Compute を含め、クラウドのモデルは一切使用しません。

データバックアップ

アプリはローカルバックアップ機能を提供しています。バックアップファイルはお客様のデバイスに保存され、すべてのデバイスデータとカバー画像が含まれます。バックアップファイルの保存と管理はすべてお客様のご判断に委ねられています。

ポリシーの変更

このプライバシーポリシーは随時更新される場合があります。更新版はアプリ内または関連する配信チャンネルで公開されます。''';
}
