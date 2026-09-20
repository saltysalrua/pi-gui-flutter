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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('zh'),
  ];

  /// No description provided for @appName.
  ///
  /// In zh, this message translates to:
  /// **'Pi'**
  String get appName;

  /// No description provided for @newConversation.
  ///
  /// In zh, this message translates to:
  /// **'新对话'**
  String get newConversation;

  /// No description provided for @projects.
  ///
  /// In zh, this message translates to:
  /// **'项目列表'**
  String get projects;

  /// No description provided for @settings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// No description provided for @noSessions.
  ///
  /// In zh, this message translates to:
  /// **'暂无历史对话'**
  String get noSessions;

  /// No description provided for @inputPlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'给 Pi 输入需求，或指派代码任务...'**
  String get inputPlaceholder;

  /// No description provided for @selectModel.
  ///
  /// In zh, this message translates to:
  /// **'切换模型'**
  String get selectModel;

  /// No description provided for @sendMessage.
  ///
  /// In zh, this message translates to:
  /// **'发送'**
  String get sendMessage;

  /// No description provided for @environmentLocal.
  ///
  /// In zh, this message translates to:
  /// **'Local RPC (已连接)'**
  String get environmentLocal;

  /// No description provided for @agentMain.
  ///
  /// In zh, this message translates to:
  /// **'Main Agent'**
  String get agentMain;

  /// No description provided for @windowMinimize.
  ///
  /// In zh, this message translates to:
  /// **'最小化'**
  String get windowMinimize;

  /// No description provided for @windowMaximize.
  ///
  /// In zh, this message translates to:
  /// **'最大化'**
  String get windowMaximize;

  /// No description provided for @windowRestore.
  ///
  /// In zh, this message translates to:
  /// **'还原'**
  String get windowRestore;

  /// No description provided for @windowClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get windowClose;

  /// No description provided for @currentWorkspace.
  ///
  /// In zh, this message translates to:
  /// **'当前项目'**
  String get currentWorkspace;

  /// No description provided for @thinkingIntensity.
  ///
  /// In zh, this message translates to:
  /// **'思考强度'**
  String get thinkingIntensity;

  /// No description provided for @thinkingNone.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get thinkingNone;

  /// No description provided for @thinkingLow.
  ///
  /// In zh, this message translates to:
  /// **'低'**
  String get thinkingLow;

  /// No description provided for @thinkingMedium.
  ///
  /// In zh, this message translates to:
  /// **'中'**
  String get thinkingMedium;

  /// No description provided for @thinkingHigh.
  ///
  /// In zh, this message translates to:
  /// **'高'**
  String get thinkingHigh;

  /// No description provided for @thinkingXHigh.
  ///
  /// In zh, this message translates to:
  /// **'超高'**
  String get thinkingXHigh;

  /// No description provided for @thinkingMax.
  ///
  /// In zh, this message translates to:
  /// **'最高'**
  String get thinkingMax;

  /// No description provided for @defaultGroup.
  ///
  /// In zh, this message translates to:
  /// **'默认'**
  String get defaultGroup;

  /// No description provided for @recommendedModels.
  ///
  /// In zh, this message translates to:
  /// **'推荐模型集'**
  String get recommendedModels;

  /// No description provided for @reset.
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get reset;

  /// No description provided for @back.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get back;

  /// No description provided for @thinkingMinimal.
  ///
  /// In zh, this message translates to:
  /// **'极低'**
  String get thinkingMinimal;

  /// No description provided for @modelSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索模型…'**
  String get modelSearchHint;

  /// No description provided for @clearSearch.
  ///
  /// In zh, this message translates to:
  /// **'清空搜索'**
  String get clearSearch;

  /// No description provided for @modelsLoading.
  ///
  /// In zh, this message translates to:
  /// **'正在从 Pi 读取模型…'**
  String get modelsLoading;

  /// No description provided for @modelsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'Pi 没有可用模型。请在 Pi 中配置提供商后刷新。'**
  String get modelsEmpty;

  /// No description provided for @modelSearchEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有找到匹配的模型'**
  String get modelSearchEmpty;

  /// No description provided for @modelLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取模型。请确认已安装 Pi，且 PATH 中可以找到 pi，然后重试。'**
  String get modelLoadFailed;

  /// No description provided for @modelChangeFailed.
  ///
  /// In zh, this message translates to:
  /// **'Pi 未能确认模型切换结果。请刷新后重试。'**
  String get modelChangeFailed;

  /// No description provided for @modelThinkingFailed.
  ///
  /// In zh, this message translates to:
  /// **'Pi 未能确认思考等级。请刷新后重试。'**
  String get modelThinkingFailed;

  /// No description provided for @piDisconnected.
  ///
  /// In zh, this message translates to:
  /// **'已与 Pi 断开连接，请刷新重连。'**
  String get piDisconnected;

  /// No description provided for @piNotConnected.
  ///
  /// In zh, this message translates to:
  /// **'Pi 未连接'**
  String get piNotConnected;

  /// No description provided for @modelNoSelection.
  ///
  /// In zh, this message translates to:
  /// **'请选择模型'**
  String get modelNoSelection;

  /// No description provided for @modelRefresh.
  ///
  /// In zh, this message translates to:
  /// **'从 Pi 刷新'**
  String get modelRefresh;

  /// No description provided for @modelUpdating.
  ///
  /// In zh, this message translates to:
  /// **'正在等待 Pi 确认…'**
  String get modelUpdating;

  /// No description provided for @thinkingUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'Pi 未返回思考等级，请更新 Pi 后刷新。'**
  String get thinkingUnavailable;

  /// No description provided for @thinkingNotSupported.
  ///
  /// In zh, this message translates to:
  /// **'此模型不支持思考。'**
  String get thinkingNotSupported;

  /// No description provided for @modelPickerDismiss.
  ///
  /// In zh, this message translates to:
  /// **'关闭模型选择器'**
  String get modelPickerDismiss;

  /// No description provided for @modelAndThinking.
  ///
  /// In zh, this message translates to:
  /// **'{model} · {level}'**
  String modelAndThinking(String model, String level);

  /// No description provided for @availableModelCount.
  ///
  /// In zh, this message translates to:
  /// **'可用模型（{count}）'**
  String availableModelCount(int count);

  /// No description provided for @extensionUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'暂不支持这类 Pi 扩展界面请求。'**
  String get extensionUnsupported;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get confirm;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get close;

  /// No description provided for @piExtensionInvalidRequest.
  ///
  /// In zh, this message translates to:
  /// **'Pi 扩展发来了一条无法显示的请求，连接未中断。'**
  String get piExtensionInvalidRequest;

  /// No description provided for @piReconnecting.
  ///
  /// In zh, this message translates to:
  /// **'正在重新连接 Pi…'**
  String get piReconnecting;

  /// No description provided for @chatYou.
  ///
  /// In zh, this message translates to:
  /// **'你'**
  String get chatYou;

  /// 当前会话中每条 AI 发言的编号，不按用户问答轮次计数。
  ///
  /// In zh, this message translates to:
  /// **'#{number}'**
  String chatAssistantNumber(int number);

  /// No description provided for @chatReady.
  ///
  /// In zh, this message translates to:
  /// **'就绪'**
  String get chatReady;

  /// No description provided for @chatWorking.
  ///
  /// In zh, this message translates to:
  /// **'正在处理…'**
  String get chatWorking;

  /// No description provided for @chatRetrying.
  ///
  /// In zh, this message translates to:
  /// **'服务暂时不可用，Pi 正在重试…'**
  String get chatRetrying;

  /// No description provided for @chatCompacting.
  ///
  /// In zh, this message translates to:
  /// **'正在整理上下文…'**
  String get chatCompacting;

  /// No description provided for @chatStopping.
  ///
  /// In zh, this message translates to:
  /// **'正在停止…'**
  String get chatStopping;

  /// No description provided for @chatStop.
  ///
  /// In zh, this message translates to:
  /// **'停止'**
  String get chatStop;

  /// No description provided for @chatLoading.
  ///
  /// In zh, this message translates to:
  /// **'正在读取对话…'**
  String get chatLoading;

  /// No description provided for @chatWelcome.
  ///
  /// In zh, this message translates to:
  /// **'从一个问题开始'**
  String get chatWelcome;

  /// No description provided for @chatWelcomeHint.
  ///
  /// In zh, this message translates to:
  /// **'询问代码、分析问题，或让 Pi 修改当前项目。'**
  String get chatWelcomeHint;

  /// No description provided for @chatInputHint.
  ///
  /// In zh, this message translates to:
  /// **'Enter 发送 · Shift+Enter 换行'**
  String get chatInputHint;

  /// No description provided for @chatBusyHint.
  ///
  /// In zh, this message translates to:
  /// **'可以先写下一条，当前任务结束后再发送。'**
  String get chatBusyHint;

  /// No description provided for @chatThinking.
  ///
  /// In zh, this message translates to:
  /// **'思考过程'**
  String get chatThinking;

  /// No description provided for @chatCopy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get chatCopy;

  /// No description provided for @chatCopied.
  ///
  /// In zh, this message translates to:
  /// **'已复制'**
  String get chatCopied;

  /// No description provided for @chatCopyFailed.
  ///
  /// In zh, this message translates to:
  /// **'复制失败，请重试。'**
  String get chatCopyFailed;

  /// No description provided for @chatCode.
  ///
  /// In zh, this message translates to:
  /// **'代码'**
  String get chatCode;

  /// No description provided for @chatOutput.
  ///
  /// In zh, this message translates to:
  /// **'输出'**
  String get chatOutput;

  /// No description provided for @chatArguments.
  ///
  /// In zh, this message translates to:
  /// **'参数'**
  String get chatArguments;

  /// No description provided for @chatPreviewLimited.
  ///
  /// In zh, this message translates to:
  /// **'内容较长，仅显示预览；复制可获得完整内容。'**
  String get chatPreviewLimited;

  /// No description provided for @chatShowMore.
  ///
  /// In zh, this message translates to:
  /// **'展开内容'**
  String get chatShowMore;

  /// No description provided for @chatShowLess.
  ///
  /// In zh, this message translates to:
  /// **'收起内容'**
  String get chatShowLess;

  /// No description provided for @chatOutputEvicted.
  ///
  /// In zh, this message translates to:
  /// **'完整输出已从内存释放以节省内存，不影响已保存的会话历史。'**
  String get chatOutputEvicted;

  /// No description provided for @chatReloadOutput.
  ///
  /// In zh, this message translates to:
  /// **'重新读取'**
  String get chatReloadOutput;

  /// No description provided for @chatHibernated.
  ///
  /// In zh, this message translates to:
  /// **'此会话已休眠以释放内存；历史已保存，唤醒后会继续。'**
  String get chatHibernated;

  /// No description provided for @chatWake.
  ///
  /// In zh, this message translates to:
  /// **'唤醒'**
  String get chatWake;

  /// No description provided for @chatWaking.
  ///
  /// In zh, this message translates to:
  /// **'正在唤醒…'**
  String get chatWaking;

  /// No description provided for @chatToolPreparing.
  ///
  /// In zh, this message translates to:
  /// **'准备执行'**
  String get chatToolPreparing;

  /// No description provided for @chatToolRunning.
  ///
  /// In zh, this message translates to:
  /// **'执行中'**
  String get chatToolRunning;

  /// No description provided for @chatToolDone.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get chatToolDone;

  /// No description provided for @chatToolFailed.
  ///
  /// In zh, this message translates to:
  /// **'执行失败'**
  String get chatToolFailed;

  /// No description provided for @chatToolInterrupted.
  ///
  /// In zh, this message translates to:
  /// **'已中断'**
  String get chatToolInterrupted;

  /// No description provided for @chatNoOutput.
  ///
  /// In zh, this message translates to:
  /// **'此工具没有返回文字输出。'**
  String get chatNoOutput;

  /// No description provided for @chatChanges.
  ///
  /// In zh, this message translates to:
  /// **'文件改动'**
  String get chatChanges;

  /// No description provided for @chatChangesEmpty.
  ///
  /// In zh, this message translates to:
  /// **'本会话还没有文件改动。'**
  String get chatChangesEmpty;

  /// No description provided for @chatChangesScope.
  ///
  /// In zh, this message translates to:
  /// **'按文件汇总本会话的成功编辑记录，不是 Git 净改动。终端命令产生的改动不会自动列在这里。'**
  String get chatChangesScope;

  /// No description provided for @chatSelectChange.
  ///
  /// In zh, this message translates to:
  /// **'选择文件查看编辑记录'**
  String get chatSelectChange;

  /// No description provided for @chatViewDiff.
  ///
  /// In zh, this message translates to:
  /// **'查看改动'**
  String get chatViewDiff;

  /// No description provided for @chatDiff.
  ///
  /// In zh, this message translates to:
  /// **'Diff'**
  String get chatDiff;

  /// No description provided for @chatNoChanges.
  ///
  /// In zh, this message translates to:
  /// **'内容没有变化'**
  String get chatNoChanges;

  /// No description provided for @chatEmptyFile.
  ///
  /// In zh, this message translates to:
  /// **'空文件'**
  String get chatEmptyFile;

  /// No description provided for @chatFileCreated.
  ///
  /// In zh, this message translates to:
  /// **'新建文件'**
  String get chatFileCreated;

  /// No description provided for @chatToolFileStats.
  ///
  /// In zh, this message translates to:
  /// **'{lines} 行 · {size}'**
  String chatToolFileStats(int lines, String size);

  /// No description provided for @chatToolTimeout.
  ///
  /// In zh, this message translates to:
  /// **'超时 {seconds} 秒'**
  String chatToolTimeout(String seconds);

  /// No description provided for @chatWrittenContent.
  ///
  /// In zh, this message translates to:
  /// **'写入内容'**
  String get chatWrittenContent;

  /// No description provided for @chatNoBaseline.
  ///
  /// In zh, this message translates to:
  /// **'没有旧内容，仅展示本次写入，无法对比。'**
  String get chatNoBaseline;

  /// No description provided for @chatDiffUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'Pi 没有返回这次编辑的 Diff。'**
  String get chatDiffUnavailable;

  /// No description provided for @chatLatest.
  ///
  /// In zh, this message translates to:
  /// **'回到最新消息'**
  String get chatLatest;

  /// No description provided for @chatLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取对话。请检查 Pi 连接，然后刷新。'**
  String get chatLoadFailed;

  /// No description provided for @chatSendFailed.
  ///
  /// In zh, this message translates to:
  /// **'Pi 未接受这条消息，草稿已保留。请检查模型配置后重试。'**
  String get chatSendFailed;

  /// No description provided for @chatImageProcessingFailed.
  ///
  /// In zh, this message translates to:
  /// **'图片未能处理，消息尚未发送，草稿已保留。请重试，或减少图片数量、换用较小的图片。'**
  String get chatImageProcessingFailed;

  /// No description provided for @chatReplyFailed.
  ///
  /// In zh, this message translates to:
  /// **'这次回复未完成。请检查模型服务与额度，再发送消息继续。'**
  String get chatReplyFailed;

  /// No description provided for @chatUncertain.
  ///
  /// In zh, this message translates to:
  /// **'尚未收到 Pi 的确认，暂时禁止再次发送，避免重复执行。请等待确认或刷新查看状态。'**
  String get chatUncertain;

  /// No description provided for @chatStopFailed.
  ///
  /// In zh, this message translates to:
  /// **'Pi 尚未确认停止，请稍后重试停止。'**
  String get chatStopFailed;

  /// No description provided for @chatSessionCancelled.
  ///
  /// In zh, this message translates to:
  /// **'Pi 扩展取消了会话切换，原对话已保留。'**
  String get chatSessionCancelled;

  /// No description provided for @chatInvalidEvent.
  ///
  /// In zh, this message translates to:
  /// **'Pi 发来了一条无法显示的事件，其余对话仍会继续。任务结束后可刷新同步。'**
  String get chatInvalidEvent;

  /// No description provided for @chatAborted.
  ///
  /// In zh, this message translates to:
  /// **'回复已停止'**
  String get chatAborted;

  /// No description provided for @chatLengthLimit.
  ///
  /// In zh, this message translates to:
  /// **'回复达到模型输出上限，可以发送消息让 Pi 继续。'**
  String get chatLengthLimit;

  /// No description provided for @chatImageUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'图片无法显示，文件可能已移动、损坏或过大。'**
  String get chatImageUnavailable;

  /// No description provided for @chatUnsupportedContent.
  ///
  /// In zh, this message translates to:
  /// **'暂不支持显示此内容块'**
  String get chatUnsupportedContent;

  /// No description provided for @chatOpenLinkFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法打开链接。请检查文件是否存在、是否有默认打开程序；不支持可执行文件、网络共享和特殊协议。'**
  String get chatOpenLinkFailed;

  /// No description provided for @chatRemoteImage.
  ///
  /// In zh, this message translates to:
  /// **'图片未自动加载'**
  String get chatRemoteImage;

  /// No description provided for @chatQueued.
  ///
  /// In zh, this message translates to:
  /// **'等待中的消息'**
  String get chatQueued;

  /// No description provided for @chatQueuedCount.
  ///
  /// In zh, this message translates to:
  /// **'等待中的消息（{count}）'**
  String chatQueuedCount(int count);

  /// No description provided for @chatQueueSteering.
  ///
  /// In zh, this message translates to:
  /// **'本轮补充'**
  String get chatQueueSteering;

  /// No description provided for @chatQueueFollowUp.
  ///
  /// In zh, this message translates to:
  /// **'完成后处理'**
  String get chatQueueFollowUp;

  /// No description provided for @chatQueueEntry.
  ///
  /// In zh, this message translates to:
  /// **'{kind}：{message}'**
  String chatQueueEntry(String kind, String message);

  /// No description provided for @chatQueueSteerAction.
  ///
  /// In zh, this message translates to:
  /// **'本轮补充 · Enter'**
  String get chatQueueSteerAction;

  /// No description provided for @chatQueueFollowUpAction.
  ///
  /// In zh, this message translates to:
  /// **'完成后处理 · Alt+Enter'**
  String get chatQueueFollowUpAction;

  /// No description provided for @chatQueueSendOptions.
  ///
  /// In zh, this message translates to:
  /// **'选择消息处理时机'**
  String get chatQueueSendOptions;

  /// No description provided for @chatQueuePlaceholder.
  ///
  /// In zh, this message translates to:
  /// **'继续补充… Enter 本轮处理，Alt+Enter 完成后处理'**
  String get chatQueuePlaceholder;

  /// No description provided for @chatQueueRestore.
  ///
  /// In zh, this message translates to:
  /// **'取回排队文字 · Alt+↑\n不停止当前任务。图片需重新添加。'**
  String get chatQueueRestore;

  /// No description provided for @chatQueueStop.
  ///
  /// In zh, this message translates to:
  /// **'停止并取回排队文字 · Esc\n图片需重新添加。'**
  String get chatQueueStop;

  /// No description provided for @chatQueueFailed.
  ///
  /// In zh, this message translates to:
  /// **'未能取回排队文字，请稍后重试。'**
  String get chatQueueFailed;

  /// No description provided for @chatRefresh.
  ///
  /// In zh, this message translates to:
  /// **'同步对话'**
  String get chatRefresh;

  /// No description provided for @chatSessionHistoryHint.
  ///
  /// In zh, this message translates to:
  /// **'当前工作目录的 Pi 历史对话，按最近更新排序。'**
  String get chatSessionHistoryHint;

  /// No description provided for @chatRead.
  ///
  /// In zh, this message translates to:
  /// **'读取'**
  String get chatRead;

  /// No description provided for @chatEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get chatEdit;

  /// No description provided for @chatWrite.
  ///
  /// In zh, this message translates to:
  /// **'写入'**
  String get chatWrite;

  /// No description provided for @chatBash.
  ///
  /// In zh, this message translates to:
  /// **'终端'**
  String get chatBash;

  /// No description provided for @chatFileCount.
  ///
  /// In zh, this message translates to:
  /// **'文件改动（{count}）'**
  String chatFileCount(int count);

  /// No description provided for @chatEditCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 次编辑'**
  String chatEditCount(int count);

  /// No description provided for @chatEditNumber.
  ///
  /// In zh, this message translates to:
  /// **'第 {count} 次编辑'**
  String chatEditNumber(int count);

  /// No description provided for @workspaceChoose.
  ///
  /// In zh, this message translates to:
  /// **'选择工作区'**
  String get workspaceChoose;

  /// No description provided for @workspaceOpen.
  ///
  /// In zh, this message translates to:
  /// **'打开文件夹'**
  String get workspaceOpen;

  /// No description provided for @workspaceCreate.
  ///
  /// In zh, this message translates to:
  /// **'新建工作区'**
  String get workspaceCreate;

  /// No description provided for @workspaceName.
  ///
  /// In zh, this message translates to:
  /// **'文件夹名称'**
  String get workspaceName;

  /// No description provided for @workspaceParent.
  ///
  /// In zh, this message translates to:
  /// **'选择存放位置'**
  String get workspaceParent;

  /// No description provided for @workspaceCreateHint.
  ///
  /// In zh, this message translates to:
  /// **'在所选位置创建一个空文件夹，不自动初始化 Git。'**
  String get workspaceCreateHint;

  /// No description provided for @workspaceRecent.
  ///
  /// In zh, this message translates to:
  /// **'最近使用'**
  String get workspaceRecent;

  /// No description provided for @workspaceLoading.
  ///
  /// In zh, this message translates to:
  /// **'正在读取工作区…'**
  String get workspaceLoading;

  /// No description provided for @workspaceRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新工作区与历史'**
  String get workspaceRefresh;

  /// No description provided for @workspaceBusy.
  ///
  /// In zh, this message translates to:
  /// **'请先等待当前操作完成，或停止正在运行的任务。'**
  String get workspaceBusy;

  /// No description provided for @workspaceLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取工作区。请确认 Node.js 和 npm 安装的 Pi 可用，然后刷新重试。'**
  String get workspaceLoadFailed;

  /// No description provided for @workspacePathFailed.
  ///
  /// In zh, this message translates to:
  /// **'文件夹无法访问，可能已移动或删除。请重新选择。'**
  String get workspacePathFailed;

  /// No description provided for @workspaceNameInvalid.
  ///
  /// In zh, this message translates to:
  /// **'名称无效，请使用普通文件夹名称，不要包含路径分隔符。'**
  String get workspaceNameInvalid;

  /// No description provided for @workspacePathExists.
  ///
  /// In zh, this message translates to:
  /// **'目标文件夹已存在。请换一个名称，或直接打开它。'**
  String get workspacePathExists;

  /// No description provided for @workspaceCreateFailed.
  ///
  /// In zh, this message translates to:
  /// **'创建失败，请检查存放位置的写入权限。'**
  String get workspaceCreateFailed;

  /// No description provided for @workspaceSwitchFailed.
  ///
  /// In zh, this message translates to:
  /// **'未能在目标目录启动 Pi，已尝试恢复原工作区。请检查目录与 Pi 配置后重试。'**
  String get workspaceSwitchFailed;

  /// No description provided for @workspaceUnknown.
  ///
  /// In zh, this message translates to:
  /// **'尚未收到后端确认，请勿重复创建或切换。等待确认后刷新列表。'**
  String get workspaceUnknown;

  /// No description provided for @workspaceCreatedKept.
  ///
  /// In zh, this message translates to:
  /// **'目录已创建并保留，但切换未完成。可从最近使用中重新打开：'**
  String get workspaceCreatedKept;

  /// No description provided for @workspacePersistenceFailed.
  ///
  /// In zh, this message translates to:
  /// **'最近使用列表未能保存，下次启动可能需要重新选择工作区。'**
  String get workspacePersistenceFailed;

  /// No description provided for @sessionSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索历史对话…'**
  String get sessionSearch;

  /// No description provided for @sessionNoMatch.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的历史对话'**
  String get sessionNoMatch;

  /// No description provided for @sessionHistoryFailed.
  ///
  /// In zh, this message translates to:
  /// **'历史对话读取失败，请刷新重试。'**
  String get sessionHistoryFailed;

  /// No description provided for @sessionHistoryLoading.
  ///
  /// In zh, this message translates to:
  /// **'正在读取历史对话…'**
  String get sessionHistoryLoading;

  /// No description provided for @worktreeManage.
  ///
  /// In zh, this message translates to:
  /// **'选择 Worktree'**
  String get worktreeManage;

  /// No description provided for @worktreeCreate.
  ///
  /// In zh, this message translates to:
  /// **'新建 Worktree'**
  String get worktreeCreate;

  /// No description provided for @worktreeBranch.
  ///
  /// In zh, this message translates to:
  /// **'新分支名称'**
  String get worktreeBranch;

  /// No description provided for @worktreeBase.
  ///
  /// In zh, this message translates to:
  /// **'起点（分支或完整 Commit SHA）'**
  String get worktreeBase;

  /// No description provided for @worktreeHead.
  ///
  /// In zh, this message translates to:
  /// **'当前提交（HEAD）'**
  String get worktreeHead;

  /// No description provided for @worktreeDetached.
  ///
  /// In zh, this message translates to:
  /// **'游离 HEAD'**
  String get worktreeDetached;

  /// No description provided for @worktreeLocked.
  ///
  /// In zh, this message translates to:
  /// **'已锁定'**
  String get worktreeLocked;

  /// No description provided for @worktreeUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'目录已失效'**
  String get worktreeUnavailable;

  /// No description provided for @worktreeNotGit.
  ///
  /// In zh, this message translates to:
  /// **'当前目录不是 Git 仓库，仍可正常聊天。'**
  String get worktreeNotGit;

  /// No description provided for @worktreeNoCommit.
  ///
  /// In zh, this message translates to:
  /// **'仓库还没有提交，首次提交后才能创建 Worktree。'**
  String get worktreeNoCommit;

  /// No description provided for @worktreeDirty.
  ///
  /// In zh, this message translates to:
  /// **'当前目录有未提交改动，不会复制到新 Worktree。'**
  String get worktreeDirty;

  /// No description provided for @worktreeCreateHint.
  ///
  /// In zh, this message translates to:
  /// **'从所选提交创建独立目录和新分支，不改动原目录，不复制未提交或忽略的文件。创建成功后切换到新目录。'**
  String get worktreeCreateHint;

  /// No description provided for @worktreeLocation.
  ///
  /// In zh, this message translates to:
  /// **'新目录将放在'**
  String get worktreeLocation;

  /// No description provided for @worktreeGitFailed.
  ///
  /// In zh, this message translates to:
  /// **'Git 操作失败，请确认已安装 Git、目录可写，并刷新后重试。'**
  String get worktreeGitFailed;

  /// No description provided for @worktreeBranchInvalid.
  ///
  /// In zh, this message translates to:
  /// **'分支名称无效，请换一个名称。'**
  String get worktreeBranchInvalid;

  /// No description provided for @worktreeBranchExists.
  ///
  /// In zh, this message translates to:
  /// **'分支已存在，请为新 Worktree 使用新的分支名称。'**
  String get worktreeBranchExists;

  /// No description provided for @worktreeBaseInvalid.
  ///
  /// In zh, this message translates to:
  /// **'起始分支已变化或不可用，请刷新后重新选择。'**
  String get worktreeBaseInvalid;

  /// No description provided for @workspaceOpenSelected.
  ///
  /// In zh, this message translates to:
  /// **'打开工作区'**
  String get workspaceOpenSelected;

  /// No description provided for @sessionMessageCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 条消息'**
  String sessionMessageCount(int count);

  /// No description provided for @worktreeRemove.
  ///
  /// In zh, this message translates to:
  /// **'移除 Worktree'**
  String get worktreeRemove;

  /// No description provided for @worktreeRemoveConfirm.
  ///
  /// In zh, this message translates to:
  /// **'仅移除下面的工作目录，保留 Git 分支和 Pi 会话。存在未提交、未跟踪或忽略的文件时不会移除。'**
  String get worktreeRemoveConfirm;

  /// No description provided for @worktreeInUse.
  ///
  /// In zh, this message translates to:
  /// **'不能移除主工作区或当前正在使用的 Worktree，请先切换到其他目录。'**
  String get worktreeInUse;

  /// No description provided for @worktreeDirtyBlocked.
  ///
  /// In zh, this message translates to:
  /// **'此 Worktree 有未提交、未跟踪或忽略的文件，未移除。请先自行保存或清理。'**
  String get worktreeDirtyBlocked;

  /// No description provided for @worktreeLockedBlocked.
  ///
  /// In zh, this message translates to:
  /// **'此 Worktree 已锁定，未移除。请先在 Git 中确认并解除锁定。'**
  String get worktreeLockedBlocked;

  /// No description provided for @workspaceCreateOpen.
  ///
  /// In zh, this message translates to:
  /// **'创建并打开'**
  String get workspaceCreateOpen;

  /// No description provided for @chatImage.
  ///
  /// In zh, this message translates to:
  /// **'图片'**
  String get chatImage;

  /// No description provided for @chatAddImages.
  ///
  /// In zh, this message translates to:
  /// **'添加图片'**
  String get chatAddImages;

  /// No description provided for @chatRemoveImage.
  ///
  /// In zh, this message translates to:
  /// **'移除图片'**
  String get chatRemoveImage;

  /// No description provided for @chatPreviewImage.
  ///
  /// In zh, this message translates to:
  /// **'点击放大图片'**
  String get chatPreviewImage;

  /// No description provided for @chatImageLoading.
  ///
  /// In zh, this message translates to:
  /// **'正在读取图片…'**
  String get chatImageLoading;

  /// No description provided for @chatOpenFile.
  ///
  /// In zh, this message translates to:
  /// **'用系统默认程序打开'**
  String get chatOpenFile;

  /// No description provided for @chatLoadRemoteImage.
  ///
  /// In zh, this message translates to:
  /// **'点击加载网络图片'**
  String get chatLoadRemoteImage;

  /// No description provided for @chatImagePickFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取图片，请检查文件后重新选择。'**
  String get chatImagePickFailed;

  /// No description provided for @chatImageFormat.
  ///
  /// In zh, this message translates to:
  /// **'请选择 PNG、JPEG、GIF 或 WebP 图片。'**
  String get chatImageFormat;

  /// No description provided for @chatImageTooLarge.
  ///
  /// In zh, this message translates to:
  /// **'图片过大。单张最多 10 MB，总共最多 20 MB，分辨率不超过 4000 万像素。'**
  String get chatImageTooLarge;

  /// No description provided for @chatImageTooMany.
  ///
  /// In zh, this message translates to:
  /// **'每条消息最多添加 8 张图片。'**
  String get chatImageTooMany;

  /// No description provided for @chatImageModel.
  ///
  /// In zh, this message translates to:
  /// **'当前模型不支持图片，请切换模型或移除图片。'**
  String get chatImageModel;

  /// No description provided for @chatAddAttachment.
  ///
  /// In zh, this message translates to:
  /// **'添加附件'**
  String get chatAddAttachment;

  /// No description provided for @chatAddFiles.
  ///
  /// In zh, this message translates to:
  /// **'添加文件'**
  String get chatAddFiles;

  /// No description provided for @chatRemoveAttachment.
  ///
  /// In zh, this message translates to:
  /// **'移除附件'**
  String get chatRemoveAttachment;

  /// No description provided for @chatPasteImage.
  ///
  /// In zh, this message translates to:
  /// **'粘贴的图片'**
  String get chatPasteImage;

  /// No description provided for @chatPasteFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取剪贴板附件。请重新复制，或使用加号添加；更新应用后请重新打开窗口。'**
  String get chatPasteFailed;

  /// No description provided for @chatFilePickFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法添加文件，请检查文件是否仍存在、是否可读取。不支持文件夹和网络共享。'**
  String get chatFilePickFailed;

  /// No description provided for @chatFileTooLarge.
  ///
  /// In zh, this message translates to:
  /// **'文件过大。每个文件最多 20 MB，文件附件合计最多 50 MB。'**
  String get chatFileTooLarge;

  /// No description provided for @chatFileTooMany.
  ///
  /// In zh, this message translates to:
  /// **'每条消息最多添加 8 个文件。'**
  String get chatFileTooMany;

  /// No description provided for @chatFileAttachmentHint.
  ///
  /// In zh, this message translates to:
  /// **'发送缓存副本，由 Pi 按需读取。PDF、Office 等文档需要后端有相应读取工具。'**
  String get chatFileAttachmentHint;

  /// No description provided for @chatAttachmentSize.
  ///
  /// In zh, this message translates to:
  /// **'{size} MB'**
  String chatAttachmentSize(String size);

  /// No description provided for @chatLightboxClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭大图（Esc）'**
  String get chatLightboxClose;

  /// No description provided for @chatLightboxHint.
  ///
  /// In zh, this message translates to:
  /// **'滚轮缩放，拖动平移；双击放大或复位。'**
  String get chatLightboxHint;

  /// No description provided for @settingsBack.
  ///
  /// In zh, this message translates to:
  /// **'返回应用'**
  String get settingsBack;

  /// No description provided for @settingsSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索设置…'**
  String get settingsSearch;

  /// No description provided for @settingsNoResults.
  ///
  /// In zh, this message translates to:
  /// **'没有找到匹配的设置'**
  String get settingsNoResults;

  /// No description provided for @piPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'pi'**
  String get piPageTitle;

  /// No description provided for @piPageSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'查看 Pi 后端的版本，在线检查更新并浏览更新日志。'**
  String get piPageSubtitle;

  /// No description provided for @piUpdates.
  ///
  /// In zh, this message translates to:
  /// **'更新检查'**
  String get piUpdates;

  /// No description provided for @piCurrentVersion.
  ///
  /// In zh, this message translates to:
  /// **'当前版本'**
  String get piCurrentVersion;

  /// No description provided for @piLatestVersion.
  ///
  /// In zh, this message translates to:
  /// **'最新版本'**
  String get piLatestVersion;

  /// No description provided for @piCheckUpdate.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get piCheckUpdate;

  /// No description provided for @piCheckHint.
  ///
  /// In zh, this message translates to:
  /// **'从 npm 查询 Pi 已发布的最新版本。'**
  String get piCheckHint;

  /// No description provided for @piChecking.
  ///
  /// In zh, this message translates to:
  /// **'正在检查更新…'**
  String get piChecking;

  /// No description provided for @piUpToDate.
  ///
  /// In zh, this message translates to:
  /// **'已是最新版本。'**
  String get piUpToDate;

  /// No description provided for @piUpdateAvailable.
  ///
  /// In zh, this message translates to:
  /// **'发现新版本 {version}。'**
  String piUpdateAvailable(String version);

  /// No description provided for @piUpdateHint.
  ///
  /// In zh, this message translates to:
  /// **'更新会直接在本页运行 pi update --self，完成后无需重启本应用：正在运行的会话继续使用当前版本，之后新开的会话自动使用新版本。'**
  String get piUpdateHint;

  /// No description provided for @piUpdateNow.
  ///
  /// In zh, this message translates to:
  /// **'立即更新'**
  String get piUpdateNow;

  /// No description provided for @piUpdateRunning.
  ///
  /// In zh, this message translates to:
  /// **'正在更新…'**
  String get piUpdateRunning;

  /// No description provided for @piUpdateFailedHint.
  ///
  /// In zh, this message translates to:
  /// **'更新失败了。可以看看下方输出找原因，或复制手动命令到终端执行。'**
  String get piUpdateFailedHint;

  /// No description provided for @piUpdateOutput.
  ///
  /// In zh, this message translates to:
  /// **'更新输出'**
  String get piUpdateOutput;

  /// No description provided for @piUpdateManualCommand.
  ///
  /// In zh, this message translates to:
  /// **'手动更新命令'**
  String get piUpdateManualCommand;

  /// No description provided for @piCheckFailed.
  ///
  /// In zh, this message translates to:
  /// **'检查更新失败，请检查网络后重试。'**
  String get piCheckFailed;

  /// No description provided for @piLoading.
  ///
  /// In zh, this message translates to:
  /// **'正在读取 Pi 的安装信息…'**
  String get piLoading;

  /// No description provided for @piLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取 Pi 的安装信息。请确认 Pi 是用 npm 全局安装的，然后重试。'**
  String get piLoadFailed;

  /// No description provided for @piRegistryPage.
  ///
  /// In zh, this message translates to:
  /// **'npm 页面'**
  String get piRegistryPage;

  /// No description provided for @piRegistryPageHint.
  ///
  /// In zh, this message translates to:
  /// **'在浏览器中打开这个包的 npm 介绍页。'**
  String get piRegistryPageHint;

  /// No description provided for @piOpenRegistry.
  ///
  /// In zh, this message translates to:
  /// **'打开 npm 页面'**
  String get piOpenRegistry;

  /// No description provided for @piChangelog.
  ///
  /// In zh, this message translates to:
  /// **'更新日志'**
  String get piChangelog;

  /// No description provided for @piChangelogEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的版本。'**
  String get piChangelogEmpty;

  /// No description provided for @piShowMore.
  ///
  /// In zh, this message translates to:
  /// **'显示更多版本'**
  String get piShowMore;

  /// No description provided for @piCurrentTag.
  ///
  /// In zh, this message translates to:
  /// **'当前'**
  String get piCurrentTag;

  /// No description provided for @pluginsPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'插件'**
  String get pluginsPageTitle;

  /// No description provided for @pluginsPageSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'安装和管理 Pi 的扩展、技能、提示词与主题包。'**
  String get pluginsPageSubtitle;

  /// No description provided for @pluginsTabGallery.
  ///
  /// In zh, this message translates to:
  /// **'市场'**
  String get pluginsTabGallery;

  /// No description provided for @pluginsTabManage.
  ///
  /// In zh, this message translates to:
  /// **'管理'**
  String get pluginsTabManage;

  /// No description provided for @pluginsGalleryHint.
  ///
  /// In zh, this message translates to:
  /// **'列表来自 npm 上带 pi-package 关键词的公开包，与 pi.dev/packages 同源。'**
  String get pluginsGalleryHint;

  /// No description provided for @pluginsSearchGalleryHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索插件市场…'**
  String get pluginsSearchGalleryHint;

  /// No description provided for @pluginsSearchManageHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索已安装的插件和资源…'**
  String get pluginsSearchManageHint;

  /// No description provided for @pluginsGalleryEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有找到匹配的插件。'**
  String get pluginsGalleryEmpty;

  /// No description provided for @pluginsGalleryFailed.
  ///
  /// In zh, this message translates to:
  /// **'插件市场查询失败，请检查网络后重试。'**
  String get pluginsGalleryFailed;

  /// No description provided for @pluginsGalleryFailedDetail.
  ///
  /// In zh, this message translates to:
  /// **'插件市场查询失败：{error}'**
  String pluginsGalleryFailedDetail(Object error);

  /// No description provided for @pluginsShowMore.
  ///
  /// In zh, this message translates to:
  /// **'显示更多'**
  String get pluginsShowMore;

  /// No description provided for @pluginsSortLabel.
  ///
  /// In zh, this message translates to:
  /// **'排序方式'**
  String get pluginsSortLabel;

  /// No description provided for @pluginsSortRelevance.
  ///
  /// In zh, this message translates to:
  /// **'相关性'**
  String get pluginsSortRelevance;

  /// No description provided for @pluginsSortDownloads.
  ///
  /// In zh, this message translates to:
  /// **'下载量'**
  String get pluginsSortDownloads;

  /// No description provided for @pluginsSortUpdated.
  ///
  /// In zh, this message translates to:
  /// **'最近更新'**
  String get pluginsSortUpdated;

  /// No description provided for @pluginsSortName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get pluginsSortName;

  /// No description provided for @pluginsInstall.
  ///
  /// In zh, this message translates to:
  /// **'安装'**
  String get pluginsInstall;

  /// No description provided for @pluginsInstalling.
  ///
  /// In zh, this message translates to:
  /// **'正在安装…'**
  String get pluginsInstalling;

  /// No description provided for @pluginsInstalled.
  ///
  /// In zh, this message translates to:
  /// **'已安装'**
  String get pluginsInstalled;

  /// No description provided for @pluginsMonthlyDownloads.
  ///
  /// In zh, this message translates to:
  /// **'{count} 次下载/月'**
  String pluginsMonthlyDownloads(int count);

  /// No description provided for @pluginsOpenRepo.
  ///
  /// In zh, this message translates to:
  /// **'打开仓库'**
  String get pluginsOpenRepo;

  /// No description provided for @pluginsOpenNpm.
  ///
  /// In zh, this message translates to:
  /// **'打开 npm 页面'**
  String get pluginsOpenNpm;

  /// No description provided for @pluginsLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取插件列表。'**
  String get pluginsLoadFailed;

  /// No description provided for @pluginsLoadFailedDetail.
  ///
  /// In zh, this message translates to:
  /// **'无法读取插件列表：{error}'**
  String pluginsLoadFailedDetail(Object error);

  /// No description provided for @pluginsBusyHint.
  ///
  /// In zh, this message translates to:
  /// **'有操作正在进行，请稍候。'**
  String get pluginsBusyHint;

  /// No description provided for @pluginsActionFailed.
  ///
  /// In zh, this message translates to:
  /// **'操作失败：{error}'**
  String pluginsActionFailed(Object error);

  /// No description provided for @pluginsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'还没有安装任何插件，去市场页安装一个吧。'**
  String get pluginsEmpty;

  /// No description provided for @pluginsScopeUser.
  ///
  /// In zh, this message translates to:
  /// **'全局'**
  String get pluginsScopeUser;

  /// No description provided for @pluginsScopeProject.
  ///
  /// In zh, this message translates to:
  /// **'项目'**
  String get pluginsScopeProject;

  /// No description provided for @pluginsFiltered.
  ///
  /// In zh, this message translates to:
  /// **'已筛选'**
  String get pluginsFiltered;

  /// No description provided for @pluginsNotInstalled.
  ///
  /// In zh, this message translates to:
  /// **'未安装'**
  String get pluginsNotInstalled;

  /// No description provided for @pluginsRemove.
  ///
  /// In zh, this message translates to:
  /// **'移除'**
  String get pluginsRemove;

  /// No description provided for @pluginsRemoveConfirmTitle.
  ///
  /// In zh, this message translates to:
  /// **'移除插件'**
  String get pluginsRemoveConfirmTitle;

  /// No description provided for @pluginsRemoveConfirmMessage.
  ///
  /// In zh, this message translates to:
  /// **'会从全局设置里移除 {source}，并删除它的安装目录。确定要移除吗？'**
  String pluginsRemoveConfirmMessage(Object source);

  /// No description provided for @pluginsUpdate.
  ///
  /// In zh, this message translates to:
  /// **'更新'**
  String get pluginsUpdate;

  /// No description provided for @pluginsUpdateAll.
  ///
  /// In zh, this message translates to:
  /// **'全部更新'**
  String get pluginsUpdateAll;

  /// No description provided for @pluginsCheckUpdates.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get pluginsCheckUpdates;

  /// No description provided for @pluginsChecking.
  ///
  /// In zh, this message translates to:
  /// **'正在检查…'**
  String get pluginsChecking;

  /// No description provided for @pluginsUpdatesAvailable.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个插件有新版本'**
  String pluginsUpdatesAvailable(int count);

  /// No description provided for @pluginsUpToDate.
  ///
  /// In zh, this message translates to:
  /// **'所有插件都是最新版本。'**
  String get pluginsUpToDate;

  /// No description provided for @pluginsOperationLog.
  ///
  /// In zh, this message translates to:
  /// **'操作输出'**
  String get pluginsOperationLog;

  /// No description provided for @pluginsTopLevelGroup.
  ///
  /// In zh, this message translates to:
  /// **'本机插件'**
  String get pluginsTopLevelGroup;

  /// No description provided for @pluginsResourcesExtensions.
  ///
  /// In zh, this message translates to:
  /// **'扩展'**
  String get pluginsResourcesExtensions;

  /// No description provided for @pluginsResourcesSkills.
  ///
  /// In zh, this message translates to:
  /// **'技能'**
  String get pluginsResourcesSkills;

  /// No description provided for @pluginsResourcesPrompts.
  ///
  /// In zh, this message translates to:
  /// **'提示词'**
  String get pluginsResourcesPrompts;

  /// No description provided for @pluginsResourcesThemes.
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get pluginsResourcesThemes;

  /// No description provided for @pluginsToggleOn.
  ///
  /// In zh, this message translates to:
  /// **'启用'**
  String get pluginsToggleOn;

  /// No description provided for @pluginsToggleOff.
  ///
  /// In zh, this message translates to:
  /// **'停用'**
  String get pluginsToggleOff;

  /// No description provided for @pluginsProjectScopeHint.
  ///
  /// In zh, this message translates to:
  /// **'项目级插件请在对应项目目录用 pi config -l 管理。'**
  String get pluginsProjectScopeHint;

  /// No description provided for @pluginsNoChannel.
  ///
  /// In zh, this message translates to:
  /// **'插件管理需要连接 Pi 后端，请回到主界面后重试。'**
  String get pluginsNoChannel;

  /// No description provided for @appearanceTitle.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get appearanceTitle;

  /// No description provided for @appearanceSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'调整配色、毛玻璃、文字大小和界面比例。修改后立即生效，自动保存。'**
  String get appearanceSubtitle;

  /// No description provided for @appearanceTheme.
  ///
  /// In zh, this message translates to:
  /// **'主题与配色'**
  String get appearanceTheme;

  /// No description provided for @appearanceMode.
  ///
  /// In zh, this message translates to:
  /// **'显示模式'**
  String get appearanceMode;

  /// No description provided for @appearanceModeHint.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统，或始终使用浅色、深色。'**
  String get appearanceModeHint;

  /// No description provided for @appearanceSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get appearanceSystem;

  /// No description provided for @appearanceLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get appearanceLight;

  /// No description provided for @appearanceDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get appearanceDark;

  /// No description provided for @appearanceSource.
  ///
  /// In zh, this message translates to:
  /// **'配色来源'**
  String get appearanceSource;

  /// No description provided for @appearanceSourceHint.
  ///
  /// In zh, this message translates to:
  /// **'Material 3 会用种子色生成相互搭配的背景、文字和强调色。'**
  String get appearanceSourceHint;

  /// No description provided for @appearanceOriginal.
  ///
  /// In zh, this message translates to:
  /// **'默认配色'**
  String get appearanceOriginal;

  /// No description provided for @appearanceWindows.
  ///
  /// In zh, this message translates to:
  /// **'Windows 强调色'**
  String get appearanceWindows;

  /// No description provided for @appearanceCustomSeed.
  ///
  /// In zh, this message translates to:
  /// **'自选种子色'**
  String get appearanceCustomSeed;

  /// No description provided for @appearanceSeed.
  ///
  /// In zh, this message translates to:
  /// **'种子色'**
  String get appearanceSeed;

  /// No description provided for @appearanceSeedHint.
  ///
  /// In zh, this message translates to:
  /// **'生成整套配色，不是把所有部位涂成同一种颜色。'**
  String get appearanceSeedHint;

  /// No description provided for @appearanceSystemHint.
  ///
  /// In zh, this message translates to:
  /// **'读取 Windows 强调色，切回应用时自动更新。Windows 开启“从背景自动选取强调色”后可随壁纸变化。'**
  String get appearanceSystemHint;

  /// No description provided for @appearanceSystemUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'暂时无法读取系统强调色，正在使用默认种子色。更新应用后请重新打开，或点击重试。'**
  String get appearanceSystemUnavailable;

  /// No description provided for @appearanceRefresh.
  ///
  /// In zh, this message translates to:
  /// **'重新读取'**
  String get appearanceRefresh;

  /// No description provided for @appearancePerformance.
  ///
  /// In zh, this message translates to:
  /// **'帧率与性能'**
  String get appearancePerformance;

  /// No description provided for @appearanceFrameRate.
  ///
  /// In zh, this message translates to:
  /// **'全局帧率上限'**
  String get appearanceFrameRate;

  /// No description provided for @appearanceFrameRateHint.
  ///
  /// In zh, this message translates to:
  /// **'限制整个界面，包括滚动、拖拽和文字更新。默认 120 FPS；实际帧率不会超过屏幕刷新率。'**
  String get appearanceFrameRateHint;

  /// No description provided for @appearanceAnimationFrameRate.
  ///
  /// In zh, this message translates to:
  /// **'持续动画帧率'**
  String get appearanceAnimationFrameRate;

  /// No description provided for @appearanceAnimationFrameRateHint.
  ///
  /// In zh, this message translates to:
  /// **'只控制微光和加载转圈，默认 30 FPS；同时受全局上限限制，不降低其他交互的帧率。'**
  String get appearanceAnimationFrameRateHint;

  /// No description provided for @appearanceFrameRateDisplay.
  ///
  /// In zh, this message translates to:
  /// **'跟随屏幕'**
  String get appearanceFrameRateDisplay;

  /// No description provided for @appearanceFrameRateValue.
  ///
  /// In zh, this message translates to:
  /// **'{fps} FPS'**
  String appearanceFrameRateValue(int fps);

  /// No description provided for @appearanceSizing.
  ///
  /// In zh, this message translates to:
  /// **'文字与界面大小'**
  String get appearanceSizing;

  /// No description provided for @appearanceFont.
  ///
  /// In zh, this message translates to:
  /// **'基准字号'**
  String get appearanceFont;

  /// No description provided for @appearanceFontHint.
  ///
  /// In zh, this message translates to:
  /// **'只调整文字大小，标题与代码字号按比例变化；保留系统文字缩放。默认 13。'**
  String get appearanceFontHint;

  /// No description provided for @appearanceScale.
  ///
  /// In zh, this message translates to:
  /// **'UI 比例'**
  String get appearanceScale;

  /// No description provided for @appearanceScaleHint.
  ///
  /// In zh, this message translates to:
  /// **'整体缩放文字、按钮、图标和间距，叠加在系统显示缩放之上。默认 100%。'**
  String get appearanceScaleHint;

  /// No description provided for @appearanceToolDisplay.
  ///
  /// In zh, this message translates to:
  /// **'工具显示'**
  String get appearanceToolDisplay;

  /// No description provided for @appearanceToolDisplayHint.
  ///
  /// In zh, this message translates to:
  /// **'设置聊天里 agent 工具卡片默认显示多详细，想看细节时点开单个卡片即可。'**
  String get appearanceToolDisplayHint;

  /// No description provided for @appearanceToolDensity.
  ///
  /// In zh, this message translates to:
  /// **'工具卡片'**
  String get appearanceToolDensity;

  /// No description provided for @appearanceToolCollapsed.
  ///
  /// In zh, this message translates to:
  /// **'收起'**
  String get appearanceToolCollapsed;

  /// No description provided for @appearanceToolCompact.
  ///
  /// In zh, this message translates to:
  /// **'简略'**
  String get appearanceToolCompact;

  /// No description provided for @appearanceToolExpanded.
  ///
  /// In zh, this message translates to:
  /// **'展开'**
  String get appearanceToolExpanded;

  /// No description provided for @appearanceToolCollapsedHint.
  ///
  /// In zh, this message translates to:
  /// **'只显示一行工具标题，最省空间。'**
  String get appearanceToolCollapsedHint;

  /// No description provided for @appearanceToolCompactHint.
  ///
  /// In zh, this message translates to:
  /// **'标题加几行预览：输出 6 行、失败 3 行、文件改动 8 行。默认样式。'**
  String get appearanceToolCompactHint;

  /// No description provided for @appearanceToolExpandedHint.
  ///
  /// In zh, this message translates to:
  /// **'直接显示完整命令、输出与文件改动，最直观但占空间。'**
  String get appearanceToolExpandedHint;

  /// No description provided for @appearanceHibernate.
  ///
  /// In zh, this message translates to:
  /// **'闲置会话休眠'**
  String get appearanceHibernate;

  /// No description provided for @appearanceHibernateHint.
  ///
  /// In zh, this message translates to:
  /// **'长时间未使用的会话会结束其后台 Pi 进程以释放内存，历史照常保存在磁盘。唤醒时重新打开同一会话，不会重发消息；正在运行、有草稿或结果未确认的会话绝不休眠。'**
  String get appearanceHibernateHint;

  /// No description provided for @hibernateNever.
  ///
  /// In zh, this message translates to:
  /// **'从不'**
  String get hibernateNever;

  /// No description provided for @hibernate15Minutes.
  ///
  /// In zh, this message translates to:
  /// **'15 分钟'**
  String get hibernate15Minutes;

  /// No description provided for @hibernate60Minutes.
  ///
  /// In zh, this message translates to:
  /// **'1 小时'**
  String get hibernate60Minutes;

  /// No description provided for @appearanceOn.
  ///
  /// In zh, this message translates to:
  /// **'开'**
  String get appearanceOn;

  /// No description provided for @appearanceOff.
  ///
  /// In zh, this message translates to:
  /// **'关'**
  String get appearanceOff;

  /// No description provided for @appearanceExtensionSlots.
  ///
  /// In zh, this message translates to:
  /// **'扩展显示位置'**
  String get appearanceExtensionSlots;

  /// No description provided for @appearanceExtensionSlotsHint.
  ///
  /// In zh, this message translates to:
  /// **'Pi 扩展想在界面上展示内容时，允许它出现在哪些位置。扩展弹窗提问始终显示，不受这些开关影响。'**
  String get appearanceExtensionSlotsHint;

  /// No description provided for @appearanceSlotAboveEditor.
  ///
  /// In zh, this message translates to:
  /// **'输入框上方'**
  String get appearanceSlotAboveEditor;

  /// No description provided for @appearanceSlotAboveEditorHint.
  ///
  /// In zh, this message translates to:
  /// **'任务进度、待办卡片等扩展卡片。'**
  String get appearanceSlotAboveEditorHint;

  /// No description provided for @appearanceSlotBelowEditor.
  ///
  /// In zh, this message translates to:
  /// **'输入框下方'**
  String get appearanceSlotBelowEditor;

  /// No description provided for @appearanceSlotBelowEditorHint.
  ///
  /// In zh, this message translates to:
  /// **'快捷建议、辅助提示等文字扩展。'**
  String get appearanceSlotBelowEditorHint;

  /// No description provided for @appearanceSlotStatusBar.
  ///
  /// In zh, this message translates to:
  /// **'状态栏徽章'**
  String get appearanceSlotStatusBar;

  /// No description provided for @appearanceSlotStatusBarHint.
  ///
  /// In zh, this message translates to:
  /// **'分支、Token 用量等扩展状态徽章。'**
  String get appearanceSlotStatusBarHint;

  /// No description provided for @appearanceSlotSidebarPanel.
  ///
  /// In zh, this message translates to:
  /// **'侧边栏扩展面板'**
  String get appearanceSlotSidebarPanel;

  /// No description provided for @appearanceSlotSidebarPanelHint.
  ///
  /// In zh, this message translates to:
  /// **'侧边栏底部的扩展内容（如插件面板）。'**
  String get appearanceSlotSidebarPanelHint;

  /// No description provided for @appearanceSlotNotificationToast.
  ///
  /// In zh, this message translates to:
  /// **'通知浮层'**
  String get appearanceSlotNotificationToast;

  /// No description provided for @appearanceSlotNotificationToastHint.
  ///
  /// In zh, this message translates to:
  /// **'右上角的扩展通知气泡。'**
  String get appearanceSlotNotificationToastHint;

  /// No description provided for @appearanceColors.
  ///
  /// In zh, this message translates to:
  /// **'分区颜色'**
  String get appearanceColors;

  /// No description provided for @appearanceColorsHint.
  ///
  /// In zh, this message translates to:
  /// **'覆盖当前显示模式的配色；浅色与深色分别保存。切换配色来源不会清除覆盖值。'**
  String get appearanceColorsHint;

  /// No description provided for @appearanceEditingLight.
  ///
  /// In zh, this message translates to:
  /// **'正在编辑浅色配色'**
  String get appearanceEditingLight;

  /// No description provided for @appearanceEditingDark.
  ///
  /// In zh, this message translates to:
  /// **'正在编辑深色配色'**
  String get appearanceEditingDark;

  /// No description provided for @appearanceAdvanced.
  ///
  /// In zh, this message translates to:
  /// **'高级颜色'**
  String get appearanceAdvanced;

  /// No description provided for @appearanceAdvancedHint.
  ///
  /// In zh, this message translates to:
  /// **'文字、边框与状态色'**
  String get appearanceAdvancedHint;

  /// No description provided for @appearancePrimary.
  ///
  /// In zh, this message translates to:
  /// **'强调色'**
  String get appearancePrimary;

  /// No description provided for @appearanceCanvas.
  ///
  /// In zh, this message translates to:
  /// **'主背景'**
  String get appearanceCanvas;

  /// No description provided for @appearanceSidebar.
  ///
  /// In zh, this message translates to:
  /// **'顶部与侧边栏'**
  String get appearanceSidebar;

  /// No description provided for @appearanceComposer.
  ///
  /// In zh, this message translates to:
  /// **'输入框'**
  String get appearanceComposer;

  /// No description provided for @appearanceCard.
  ///
  /// In zh, this message translates to:
  /// **'卡片'**
  String get appearanceCard;

  /// No description provided for @appearanceCode.
  ///
  /// In zh, this message translates to:
  /// **'代码区'**
  String get appearanceCode;

  /// No description provided for @appearanceUserMessage.
  ///
  /// In zh, this message translates to:
  /// **'用户消息'**
  String get appearanceUserMessage;

  /// No description provided for @appearanceElevated.
  ///
  /// In zh, this message translates to:
  /// **'浮层与菜单'**
  String get appearanceElevated;

  /// No description provided for @appearanceTextPrimary.
  ///
  /// In zh, this message translates to:
  /// **'主要文字'**
  String get appearanceTextPrimary;

  /// No description provided for @appearanceTextSecondary.
  ///
  /// In zh, this message translates to:
  /// **'次要文字'**
  String get appearanceTextSecondary;

  /// No description provided for @appearanceTextMuted.
  ///
  /// In zh, this message translates to:
  /// **'辅助文字'**
  String get appearanceTextMuted;

  /// No description provided for @appearanceBorder.
  ///
  /// In zh, this message translates to:
  /// **'边框'**
  String get appearanceBorder;

  /// No description provided for @appearanceSuccess.
  ///
  /// In zh, this message translates to:
  /// **'成功 / Diff 新增'**
  String get appearanceSuccess;

  /// No description provided for @appearanceWarning.
  ///
  /// In zh, this message translates to:
  /// **'警告'**
  String get appearanceWarning;

  /// No description provided for @appearanceError.
  ///
  /// In zh, this message translates to:
  /// **'错误 / Diff 删除'**
  String get appearanceError;

  /// No description provided for @appearanceAutomatic.
  ///
  /// In zh, this message translates to:
  /// **'自动'**
  String get appearanceAutomatic;

  /// No description provided for @appearanceOverridden.
  ///
  /// In zh, this message translates to:
  /// **'已自定义'**
  String get appearanceOverridden;

  /// No description provided for @appearanceResetColor.
  ///
  /// In zh, this message translates to:
  /// **'恢复自动配色'**
  String get appearanceResetColor;

  /// No description provided for @appearanceResetColors.
  ///
  /// In zh, this message translates to:
  /// **'重置此模式的颜色'**
  String get appearanceResetColors;

  /// No description provided for @appearanceResetColorsHint.
  ///
  /// In zh, this message translates to:
  /// **'仅清除当前浅色或深色模式的颜色覆盖，不改变字号、比例和另一种模式。'**
  String get appearanceResetColorsHint;

  /// No description provided for @appearanceResetAll.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认外观'**
  String get appearanceResetAll;

  /// No description provided for @appearanceResetAllHint.
  ///
  /// In zh, this message translates to:
  /// **'恢复默认配色、13 基准字号和 100% UI 比例，关闭全部毛玻璃并重置其不透明度，清除浅色、深色的自定义颜色。'**
  String get appearanceResetAllHint;

  /// No description provided for @appearanceSaving.
  ///
  /// In zh, this message translates to:
  /// **'正在保存…'**
  String get appearanceSaving;

  /// No description provided for @appearanceSaveFailed.
  ///
  /// In zh, this message translates to:
  /// **'本次修改已生效，但未能保存到本机。请重试，或检查应用数据目录的写入权限。'**
  String get appearanceSaveFailed;

  /// No description provided for @appearanceLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取已保存的外观，暂时使用默认值。重新打开应用可重试；修改设置会保存新值。'**
  String get appearanceLoadFailed;

  /// No description provided for @appearanceRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试保存'**
  String get appearanceRetry;

  /// No description provided for @appearancePreview.
  ///
  /// In zh, this message translates to:
  /// **'预览'**
  String get appearancePreview;

  /// No description provided for @appearancePreviewText.
  ///
  /// In zh, this message translates to:
  /// **'文字、卡片和代码会随你的设置一起变化。'**
  String get appearancePreviewText;

  /// No description provided for @appearancePreviewCode.
  ///
  /// In zh, this message translates to:
  /// **'const greeting = \"Hello, Pi\";'**
  String get appearancePreviewCode;

  /// No description provided for @appearanceChooseColor.
  ///
  /// In zh, this message translates to:
  /// **'选择颜色'**
  String get appearanceChooseColor;

  /// No description provided for @appearanceHex.
  ///
  /// In zh, this message translates to:
  /// **'#RRGGBB'**
  String get appearanceHex;

  /// No description provided for @appearanceHexInvalid.
  ///
  /// In zh, this message translates to:
  /// **'请输入 6 位十六进制颜色，例如 #0075DE。'**
  String get appearanceHexInvalid;

  /// No description provided for @appearanceApply.
  ///
  /// In zh, this message translates to:
  /// **'应用颜色'**
  String get appearanceApply;

  /// No description provided for @appearanceHue.
  ///
  /// In zh, this message translates to:
  /// **'色相'**
  String get appearanceHue;

  /// No description provided for @appearanceSaturation.
  ///
  /// In zh, this message translates to:
  /// **'饱和度'**
  String get appearanceSaturation;

  /// No description provided for @appearanceValue.
  ///
  /// In zh, this message translates to:
  /// **'明度'**
  String get appearanceValue;

  /// No description provided for @appearanceContrastWarning.
  ///
  /// In zh, this message translates to:
  /// **'这个颜色与当前文字或背景的对比度较低，可能不易看清。'**
  String get appearanceContrastWarning;

  /// No description provided for @appearancePercent.
  ///
  /// In zh, this message translates to:
  /// **'{value}%'**
  String appearancePercent(int value);

  /// No description provided for @appearanceFontValue.
  ///
  /// In zh, this message translates to:
  /// **'{value}'**
  String appearanceFontValue(int value);

  /// No description provided for @appearanceGlass.
  ///
  /// In zh, this message translates to:
  /// **'桌面毛玻璃'**
  String get appearanceGlass;

  /// No description provided for @appearanceGlassHint.
  ///
  /// In zh, this message translates to:
  /// **'顶部与侧栏、主界面和卡片分别设置。桌面模糊由 Windows 控制，卡片模糊应用内背景，文字保持清晰。明暗模式共用设置，需要 Windows 11 22H2 或更新版本。'**
  String get appearanceGlassHint;

  /// No description provided for @appearanceGlassSidebar.
  ///
  /// In zh, this message translates to:
  /// **'顶部与侧边栏毛玻璃'**
  String get appearanceGlassSidebar;

  /// No description provided for @appearanceGlassSidebarHint.
  ///
  /// In zh, this message translates to:
  /// **'标题栏、左右侧栏和拖拽区一起变化。'**
  String get appearanceGlassSidebarHint;

  /// No description provided for @appearanceGlassCanvas.
  ///
  /// In zh, this message translates to:
  /// **'主界面毛玻璃'**
  String get appearanceGlassCanvas;

  /// No description provided for @appearanceGlassCanvasHint.
  ///
  /// In zh, this message translates to:
  /// **'用于聊天与设置页的主背景；输入框和其他卡片由下方的卡片毛玻璃单独控制。'**
  String get appearanceGlassCanvasHint;

  /// No description provided for @appearanceGlassSidebarOpacity.
  ///
  /// In zh, this message translates to:
  /// **'顶部与侧边栏底色不透明度'**
  String get appearanceGlassSidebarOpacity;

  /// No description provided for @appearanceGlassCanvasOpacity.
  ///
  /// In zh, this message translates to:
  /// **'主界面底色不透明度'**
  String get appearanceGlassCanvasOpacity;

  /// No description provided for @appearanceGlassCards.
  ///
  /// In zh, this message translates to:
  /// **'卡片毛玻璃'**
  String get appearanceGlassCards;

  /// No description provided for @appearanceGlassCardsHint.
  ///
  /// In zh, this message translates to:
  /// **'用于输入卡片、设置卡片和弹窗等有底色的卡片，不改变透明工具行。要透出桌面，请同时开启主界面毛玻璃；纯色背景上的模糊不明显。'**
  String get appearanceGlassCardsHint;

  /// No description provided for @appearanceGlassCardsOpacity.
  ///
  /// In zh, this message translates to:
  /// **'卡片毛玻璃底色不透明度'**
  String get appearanceGlassCardsOpacity;

  /// No description provided for @appearanceGlassOpacityHint.
  ///
  /// In zh, this message translates to:
  /// **'越低越透，100% 为纯色。看不清文字时请调高；底色仍可在“分区颜色”中修改。'**
  String get appearanceGlassOpacityHint;

  /// No description provided for @appearanceGlassOn.
  ///
  /// In zh, this message translates to:
  /// **'开启'**
  String get appearanceGlassOn;

  /// No description provided for @appearanceGlassOff.
  ///
  /// In zh, this message translates to:
  /// **'关闭'**
  String get appearanceGlassOff;

  /// No description provided for @appearanceGlassSystemDisabled.
  ///
  /// In zh, this message translates to:
  /// **'系统暂未允许透明效果，正在显示纯色。请检查 Windows 的“透明效果”、对比度主题和节电模式。'**
  String get appearanceGlassSystemDisabled;

  /// No description provided for @appearanceGlassUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'当前系统不支持此材质，正在显示纯色。需要 Windows 11 22H2 或更新版本。'**
  String get appearanceGlassUnsupported;

  /// No description provided for @appearanceGlassUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'原生毛玻璃暂不可用，正在显示纯色。更新并重新打开应用后可重试；热重载无法载入原生改动。'**
  String get appearanceGlassUnavailable;

  /// No description provided for @browserTitle.
  ///
  /// In zh, this message translates to:
  /// **'文件与 Git'**
  String get browserTitle;

  /// No description provided for @browserFiles.
  ///
  /// In zh, this message translates to:
  /// **'文件'**
  String get browserFiles;

  /// No description provided for @browserGraph.
  ///
  /// In zh, this message translates to:
  /// **'Git graph'**
  String get browserGraph;

  /// No description provided for @browserRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新文件与 Git'**
  String get browserRefresh;

  /// No description provided for @browserCollapse.
  ///
  /// In zh, this message translates to:
  /// **'折叠全部文件夹'**
  String get browserCollapse;

  /// No description provided for @browserLoading.
  ///
  /// In zh, this message translates to:
  /// **'正在读取…'**
  String get browserLoading;

  /// No description provided for @browserEmptyFolder.
  ///
  /// In zh, this message translates to:
  /// **'空文件夹'**
  String get browserEmptyFolder;

  /// No description provided for @browserNoGit.
  ///
  /// In zh, this message translates to:
  /// **'当前文件夹不在 Git 仓库中。'**
  String get browserNoGit;

  /// No description provided for @browserNoCommits.
  ///
  /// In zh, this message translates to:
  /// **'仓库还没有提交。'**
  String get browserNoCommits;

  /// No description provided for @browserGitMissing.
  ///
  /// In zh, this message translates to:
  /// **'找不到 Git。安装 Git 后刷新，仍可浏览文件。'**
  String get browserGitMissing;

  /// No description provided for @browserReadFailed.
  ///
  /// In zh, this message translates to:
  /// **'读取失败，请检查文件夹权限后重试。'**
  String get browserReadFailed;

  /// No description provided for @browserGitFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法读取 Git 状态，请检查仓库后刷新。'**
  String get browserGitFailed;

  /// No description provided for @browserOldBackend.
  ///
  /// In zh, this message translates to:
  /// **'此窗口的后端尚不支持文件浏览。下次正常启动更新后的应用即可使用，当前聊天不受影响。'**
  String get browserOldBackend;

  /// No description provided for @browserWorkspaceChanged.
  ///
  /// In zh, this message translates to:
  /// **'工作区已切换，请关闭后重新选择。'**
  String get browserWorkspaceChanged;

  /// No description provided for @browserRetry.
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get browserRetry;

  /// No description provided for @browserMore.
  ///
  /// In zh, this message translates to:
  /// **'加载更多'**
  String get browserMore;

  /// No description provided for @browserLimit.
  ///
  /// In zh, this message translates to:
  /// **'已达到预览上限，请在外部工具中查看其余内容。'**
  String get browserLimit;

  /// No description provided for @browserContent.
  ///
  /// In zh, this message translates to:
  /// **'文件内容'**
  String get browserContent;

  /// No description provided for @browserStaged.
  ///
  /// In zh, this message translates to:
  /// **'已暂存的改动'**
  String get browserStaged;

  /// No description provided for @browserUnstaged.
  ///
  /// In zh, this message translates to:
  /// **'未暂存的改动'**
  String get browserUnstaged;

  /// No description provided for @browserCommitDiff.
  ///
  /// In zh, this message translates to:
  /// **'与首个父提交比较（首次提交与空内容比较）'**
  String get browserCommitDiff;

  /// No description provided for @browserBinary.
  ///
  /// In zh, this message translates to:
  /// **'此文件是二进制或不是 UTF-8 文本，暂不预览。'**
  String get browserBinary;

  /// No description provided for @browserLargeFile.
  ///
  /// In zh, this message translates to:
  /// **'文件超过 256 KiB，暂不预览。'**
  String get browserLargeFile;

  /// No description provided for @browserMissingFile.
  ///
  /// In zh, this message translates to:
  /// **'文件已删除，可在 Diff 中查看改动。'**
  String get browserMissingFile;

  /// No description provided for @browserSymlink.
  ///
  /// In zh, this message translates to:
  /// **'符号链接不会展开或读取，以免离开当前工作区。'**
  String get browserSymlink;

  /// No description provided for @browserUnsupported.
  ///
  /// In zh, this message translates to:
  /// **'暂不支持预览此类文件。'**
  String get browserUnsupported;

  /// No description provided for @browserCommitDetails.
  ///
  /// In zh, this message translates to:
  /// **'提交详情'**
  String get browserCommitDetails;

  /// No description provided for @browserCommitFilesEmpty.
  ///
  /// In zh, this message translates to:
  /// **'此次提交没有当前工作区内的文件改动。'**
  String get browserCommitFilesEmpty;

  /// No description provided for @browserGraphScope.
  ///
  /// In zh, this message translates to:
  /// **'显示当前仓库的本地分支、远程跟踪分支和标签；不会联网拉取。'**
  String get browserGraphScope;

  /// No description provided for @browserFileScope.
  ///
  /// In zh, this message translates to:
  /// **'只读浏览当前工作区；包含隐藏和忽略文件，不显示 .git。状态标记可悬停查看说明。'**
  String get browserFileScope;

  /// No description provided for @browserClean.
  ///
  /// In zh, this message translates to:
  /// **'已提交 · 无改动'**
  String get browserClean;

  /// No description provided for @browserModified.
  ///
  /// In zh, this message translates to:
  /// **'已修改'**
  String get browserModified;

  /// No description provided for @browserStatusStaged.
  ///
  /// In zh, this message translates to:
  /// **'已暂存'**
  String get browserStatusStaged;

  /// No description provided for @browserAdded.
  ///
  /// In zh, this message translates to:
  /// **'新增'**
  String get browserAdded;

  /// No description provided for @browserDeleted.
  ///
  /// In zh, this message translates to:
  /// **'已删除'**
  String get browserDeleted;

  /// No description provided for @browserRenamed.
  ///
  /// In zh, this message translates to:
  /// **'已重命名'**
  String get browserRenamed;

  /// No description provided for @browserUntracked.
  ///
  /// In zh, this message translates to:
  /// **'未跟踪'**
  String get browserUntracked;

  /// No description provided for @browserIgnored.
  ///
  /// In zh, this message translates to:
  /// **'已忽略'**
  String get browserIgnored;

  /// No description provided for @browserConflict.
  ///
  /// In zh, this message translates to:
  /// **'存在冲突'**
  String get browserConflict;

  /// No description provided for @browserNoStatus.
  ///
  /// In zh, this message translates to:
  /// **'无 Git 状态'**
  String get browserNoStatus;

  /// No description provided for @browserIndexStatus.
  ///
  /// In zh, this message translates to:
  /// **'暂存区：{status}'**
  String browserIndexStatus(String status);

  /// No description provided for @browserWorktreeStatus.
  ///
  /// In zh, this message translates to:
  /// **'工作目录：{status}'**
  String browserWorktreeStatus(String status);

  /// No description provided for @browserUnchanged.
  ///
  /// In zh, this message translates to:
  /// **'无改动'**
  String get browserUnchanged;

  /// No description provided for @tabsChat.
  ///
  /// In zh, this message translates to:
  /// **'聊天'**
  String get tabsChat;

  /// No description provided for @tabsClose.
  ///
  /// In zh, this message translates to:
  /// **'关闭标签页（Ctrl+W）'**
  String get tabsClose;

  /// No description provided for @tabsAll.
  ///
  /// In zh, this message translates to:
  /// **'所有标签页'**
  String get tabsAll;

  /// No description provided for @tabsSplit.
  ///
  /// In zh, this message translates to:
  /// **'移到右侧新分组'**
  String get tabsSplit;

  /// No description provided for @tabsMerge.
  ///
  /// In zh, this message translates to:
  /// **'合并所有标签页'**
  String get tabsMerge;

  /// No description provided for @tabsActions.
  ///
  /// In zh, this message translates to:
  /// **'标签页操作'**
  String get tabsActions;

  /// No description provided for @tabsCloseOthers.
  ///
  /// In zh, this message translates to:
  /// **'关闭其他标签页'**
  String get tabsCloseOthers;

  /// No description provided for @tabsReadOnly.
  ///
  /// In zh, this message translates to:
  /// **'只读'**
  String get tabsReadOnly;

  /// No description provided for @tabsRefresh.
  ///
  /// In zh, this message translates to:
  /// **'重新读取此预览'**
  String get tabsRefresh;

  /// No description provided for @workbenchSharedDirectory.
  ///
  /// In zh, this message translates to:
  /// **'同一目录还有其他会话正在运行，可能修改同一份文件。需要隔离时请新建 Worktree。'**
  String get workbenchSharedDirectory;

  /// No description provided for @workbenchSearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索项目、Worktree 和会话…'**
  String get workbenchSearch;

  /// No description provided for @workbenchAddProject.
  ///
  /// In zh, this message translates to:
  /// **'添加项目'**
  String get workbenchAddProject;

  /// No description provided for @workbenchMain.
  ///
  /// In zh, this message translates to:
  /// **'主目录'**
  String get workbenchMain;

  /// No description provided for @workbenchWaiting.
  ///
  /// In zh, this message translates to:
  /// **'等待回答'**
  String get workbenchWaiting;

  /// No description provided for @workbenchRunning.
  ///
  /// In zh, this message translates to:
  /// **'运行中'**
  String get workbenchRunning;

  /// No description provided for @workbenchUnread.
  ///
  /// In zh, this message translates to:
  /// **'有新消息'**
  String get workbenchUnread;

  /// No description provided for @workbenchHistory.
  ///
  /// In zh, this message translates to:
  /// **'历史会话'**
  String get workbenchHistory;

  /// No description provided for @workbenchCloseSession.
  ///
  /// In zh, this message translates to:
  /// **'关闭会话'**
  String get workbenchCloseSession;

  /// No description provided for @workbenchStopClose.
  ///
  /// In zh, this message translates to:
  /// **'停止并关闭'**
  String get workbenchStopClose;

  /// No description provided for @workbenchCloseRunning.
  ///
  /// In zh, this message translates to:
  /// **'此会话仍在运行或等待回答。停止并关闭会结束其 Pi 进程，已保存的历史仍会保留。'**
  String get workbenchCloseRunning;

  /// No description provided for @workbenchCloseDraft.
  ///
  /// In zh, this message translates to:
  /// **'此会话还有未发送的文字或附件。关闭后草稿不会保留，已保存的历史不受影响。'**
  String get workbenchCloseDraft;

  /// No description provided for @workbenchForgetProject.
  ///
  /// In zh, this message translates to:
  /// **'从列表移除项目'**
  String get workbenchForgetProject;

  /// No description provided for @workbenchForgetHint.
  ///
  /// In zh, this message translates to:
  /// **'仅从列表移除，不删除目录、分支或历史。请先关闭此项目下的所有会话。'**
  String get workbenchForgetHint;

  /// No description provided for @workbenchName.
  ///
  /// In zh, this message translates to:
  /// **'Worktree 名称'**
  String get workbenchName;

  /// No description provided for @workbenchCreateHint.
  ///
  /// In zh, this message translates to:
  /// **'在后台创建独立目录和新分支，不复制未提交或忽略文件，也不自动安装依赖。其他会话可以继续运行。'**
  String get workbenchCreateHint;

  /// No description provided for @workbenchCreateBackground.
  ///
  /// In zh, this message translates to:
  /// **'后台创建'**
  String get workbenchCreateBackground;

  /// No description provided for @workbenchCreating.
  ///
  /// In zh, this message translates to:
  /// **'正在创建…'**
  String get workbenchCreating;

  /// No description provided for @workbenchFailed.
  ///
  /// In zh, this message translates to:
  /// **'操作失败'**
  String get workbenchFailed;

  /// No description provided for @workbenchNoMatch.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的项目或会话'**
  String get workbenchNoMatch;

  /// No description provided for @workbenchEmpty.
  ///
  /// In zh, this message translates to:
  /// **'添加项目，或在左侧选择目录开始对话。'**
  String get workbenchEmpty;

  /// No description provided for @workbenchOperationUnknown.
  ///
  /// In zh, this message translates to:
  /// **'正在等待后端确认，请勿重复操作。稍后刷新列表查看结果。'**
  String get workbenchOperationUnknown;

  /// No description provided for @workbenchDisconnected.
  ///
  /// In zh, this message translates to:
  /// **'会话进程已退出，其他会话不受影响。可关闭此标签后从历史重新打开；不会自动重发消息。'**
  String get workbenchDisconnected;

  /// No description provided for @workbenchSessionCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 个会话'**
  String workbenchSessionCount(int count);

  /// No description provided for @workbenchCloseWindow.
  ///
  /// In zh, this message translates to:
  /// **'还有会话正在运行或有未发送的草稿。关闭窗口会停止所有会话，并丢弃未发送的草稿。'**
  String get workbenchCloseWindow;

  /// No description provided for @workbenchRemoveInUse.
  ///
  /// In zh, this message translates to:
  /// **'请先关闭此目录下的所有会话，再移除 Worktree。主目录不能移除。'**
  String get workbenchRemoveInUse;

  /// No description provided for @workbenchWaitBeforeClose.
  ///
  /// In zh, this message translates to:
  /// **'工作区操作尚未结束，请等待创建或移除完成后再关闭窗口，以免留下未完成的 Git 目录。'**
  String get workbenchWaitBeforeClose;

  /// No description provided for @quotaPageTitle.
  ///
  /// In zh, this message translates to:
  /// **'账号额度'**
  String get quotaPageTitle;

  /// No description provided for @quotaPageSubtitle.
  ///
  /// In zh, this message translates to:
  /// **'读取 Pi 保存的 Codex OAuth 登录，查询 ChatGPT 套餐的实时用量窗口。'**
  String get quotaPageSubtitle;

  /// No description provided for @quotaRefresh.
  ///
  /// In zh, this message translates to:
  /// **'刷新'**
  String get quotaRefresh;

  /// No description provided for @quotaRefreshing.
  ///
  /// In zh, this message translates to:
  /// **'正在刷新…'**
  String get quotaRefreshing;

  /// No description provided for @quotaLoading.
  ///
  /// In zh, this message translates to:
  /// **'正在读取登录信息并查询额度…'**
  String get quotaLoading;

  /// No description provided for @quotaLimitReached.
  ///
  /// In zh, this message translates to:
  /// **'已达到当前套餐的用量上限，请等待窗口重置。'**
  String get quotaLimitReached;

  /// No description provided for @quotaAccountGroup.
  ///
  /// In zh, this message translates to:
  /// **'账号'**
  String get quotaAccountGroup;

  /// No description provided for @quotaProvider.
  ///
  /// In zh, this message translates to:
  /// **'服务'**
  String get quotaProvider;

  /// No description provided for @quotaProviderDescription.
  ///
  /// In zh, this message translates to:
  /// **'登录信息来自 Pi 的 auth.json，本页只做只读查询。'**
  String get quotaProviderDescription;

  /// No description provided for @quotaEmail.
  ///
  /// In zh, this message translates to:
  /// **'邮箱'**
  String get quotaEmail;

  /// No description provided for @quotaPlan.
  ///
  /// In zh, this message translates to:
  /// **'套餐'**
  String get quotaPlan;

  /// No description provided for @quotaTokenExpiry.
  ///
  /// In zh, this message translates to:
  /// **'令牌有效期'**
  String get quotaTokenExpiry;

  /// No description provided for @quotaTokenExpiredHint.
  ///
  /// In zh, this message translates to:
  /// **'令牌已过期。请运行 pi auth check --provider openai-codex 刷新，或在 Pi 中重新登录。'**
  String get quotaTokenExpiredHint;

  /// No description provided for @quotaUsageGroup.
  ///
  /// In zh, this message translates to:
  /// **'用量窗口'**
  String get quotaUsageGroup;

  /// No description provided for @quotaUsageGroupDescription.
  ///
  /// In zh, this message translates to:
  /// **'用量按滑动窗口统计，查询额度本身不消耗用量。'**
  String get quotaUsageGroupDescription;

  /// No description provided for @quotaPrimaryWindow.
  ///
  /// In zh, this message translates to:
  /// **'近 5 小时'**
  String get quotaPrimaryWindow;

  /// No description provided for @quotaSecondaryWindow.
  ///
  /// In zh, this message translates to:
  /// **'近 7 天'**
  String get quotaSecondaryWindow;

  /// No description provided for @quotaWindowResets.
  ///
  /// In zh, this message translates to:
  /// **'重置于 {time}'**
  String quotaWindowResets(String time);

  /// No description provided for @quotaRemaining.
  ///
  /// In zh, this message translates to:
  /// **'剩余 {percent}%'**
  String quotaRemaining(int percent);

  /// No description provided for @quotaCreditsGroup.
  ///
  /// In zh, this message translates to:
  /// **'积分余额'**
  String get quotaCreditsGroup;

  /// No description provided for @quotaCreditsBalance.
  ///
  /// In zh, this message translates to:
  /// **'余额'**
  String get quotaCreditsBalance;

  /// No description provided for @quotaCreditsDescription.
  ///
  /// In zh, this message translates to:
  /// **'按需付费积分，仅在账号开通时显示实际数字。'**
  String get quotaCreditsDescription;

  /// No description provided for @quotaNoCredits.
  ///
  /// In zh, this message translates to:
  /// **'无积分'**
  String get quotaNoCredits;

  /// No description provided for @quotaMissingTitle.
  ///
  /// In zh, this message translates to:
  /// **'未找到 Codex 登录信息'**
  String get quotaMissingTitle;

  /// No description provided for @quotaMissingHint.
  ///
  /// In zh, this message translates to:
  /// **'Pi 的 auth.json 中没有 openai-codex 的 OAuth 登录。请先在 Pi 中完成 Codex 登录后，回到本页刷新。'**
  String get quotaMissingHint;

  /// No description provided for @quotaFailedTitle.
  ///
  /// In zh, this message translates to:
  /// **'查询额度失败'**
  String get quotaFailedTitle;

  /// No description provided for @quotaUnauthorizedHint.
  ///
  /// In zh, this message translates to:
  /// **'令牌已过期或失效。请运行 pi auth check --provider openai-codex 刷新令牌，或在 Pi 中重新登录后重试。'**
  String get quotaUnauthorizedHint;

  /// No description provided for @quotaNetworkHint.
  ///
  /// In zh, this message translates to:
  /// **'无法连接 ChatGPT 服务，请检查网络后重试。'**
  String get quotaNetworkHint;

  /// No description provided for @quotaParseHint.
  ///
  /// In zh, this message translates to:
  /// **'服务返回了无法识别的内容，可能是接口格式发生了变化。'**
  String get quotaParseHint;

  /// No description provided for @quotaOpenDetails.
  ///
  /// In zh, this message translates to:
  /// **'点击查看详情'**
  String get quotaOpenDetails;

  /// No description provided for @historyTitle.
  ///
  /// In zh, this message translates to:
  /// **'历史回溯'**
  String get historyTitle;

  /// No description provided for @historyHint.
  ///
  /// In zh, this message translates to:
  /// **'浏览不会切换会话。回溯保留旧分支；GUI 不回滚代码文件，已安装扩展的回溯行为仍会执行。'**
  String get historyHint;

  /// No description provided for @historySearch.
  ///
  /// In zh, this message translates to:
  /// **'搜索历史消息、标签或节点 ID…'**
  String get historySearch;

  /// No description provided for @historyFilter.
  ///
  /// In zh, this message translates to:
  /// **'显示内容'**
  String get historyFilter;

  /// No description provided for @historyDefault.
  ///
  /// In zh, this message translates to:
  /// **'默认'**
  String get historyDefault;

  /// No description provided for @historyNoTools.
  ///
  /// In zh, this message translates to:
  /// **'隐藏工具结果'**
  String get historyNoTools;

  /// No description provided for @historyUserOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅我的消息'**
  String get historyUserOnly;

  /// No description provided for @historyLabeledOnly.
  ///
  /// In zh, this message translates to:
  /// **'仅有标签'**
  String get historyLabeledOnly;

  /// No description provided for @historyAll.
  ///
  /// In zh, this message translates to:
  /// **'全部'**
  String get historyAll;

  /// No description provided for @historyEmpty.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的历史节点。试试更换过滤方式。'**
  String get historyEmpty;

  /// No description provided for @historySelect.
  ///
  /// In zh, this message translates to:
  /// **'选择一个节点预览，再决定从哪里继续。'**
  String get historySelect;

  /// No description provided for @historyCurrent.
  ///
  /// In zh, this message translates to:
  /// **'定位当前位置'**
  String get historyCurrent;

  /// No description provided for @historyActive.
  ///
  /// In zh, this message translates to:
  /// **'当前位置'**
  String get historyActive;

  /// No description provided for @historyActivePath.
  ///
  /// In zh, this message translates to:
  /// **'当前分支'**
  String get historyActivePath;

  /// No description provided for @historyExpand.
  ///
  /// In zh, this message translates to:
  /// **'展开所有分支'**
  String get historyExpand;

  /// No description provided for @historyCollapse.
  ///
  /// In zh, this message translates to:
  /// **'折叠或展开此分支'**
  String get historyCollapse;

  /// No description provided for @historyTimestamps.
  ///
  /// In zh, this message translates to:
  /// **'切换标签时间'**
  String get historyTimestamps;

  /// No description provided for @historyLabel.
  ///
  /// In zh, this message translates to:
  /// **'编辑标签'**
  String get historyLabel;

  /// No description provided for @historyLabelHint.
  ///
  /// In zh, this message translates to:
  /// **'输入标签，留空则清除'**
  String get historyLabelHint;

  /// No description provided for @historyNavigate.
  ///
  /// In zh, this message translates to:
  /// **'从这里继续'**
  String get historyNavigate;

  /// No description provided for @historyEdit.
  ///
  /// In zh, this message translates to:
  /// **'回到这里修改'**
  String get historyEdit;

  /// No description provided for @historyFork.
  ///
  /// In zh, this message translates to:
  /// **'从这里新建会话'**
  String get historyFork;

  /// No description provided for @historyClone.
  ///
  /// In zh, this message translates to:
  /// **'复制当前分支'**
  String get historyClone;

  /// No description provided for @historyForkHint.
  ///
  /// In zh, this message translates to:
  /// **'从所选用户消息之前创建独立会话，原会话和其他分支保留。'**
  String get historyForkHint;

  /// No description provided for @historySummary.
  ///
  /// In zh, this message translates to:
  /// **'离开分支时的摘要'**
  String get historySummary;

  /// No description provided for @historySummaryNone.
  ///
  /// In zh, this message translates to:
  /// **'不生成摘要'**
  String get historySummaryNone;

  /// No description provided for @historySummaryDefault.
  ///
  /// In zh, this message translates to:
  /// **'生成默认摘要'**
  String get historySummaryDefault;

  /// No description provided for @historySummaryCustom.
  ///
  /// In zh, this message translates to:
  /// **'自定义摘要说明'**
  String get historySummaryCustom;

  /// No description provided for @historyInstructions.
  ///
  /// In zh, this message translates to:
  /// **'希望摘要保留哪些信息？会调用当前模型。'**
  String get historyInstructions;

  /// No description provided for @historyInstructionsMode.
  ///
  /// In zh, this message translates to:
  /// **'摘要说明用法'**
  String get historyInstructionsMode;

  /// No description provided for @historyAppendInstructions.
  ///
  /// In zh, this message translates to:
  /// **'补充默认说明'**
  String get historyAppendInstructions;

  /// No description provided for @historyReplaceInstructions.
  ///
  /// In zh, this message translates to:
  /// **'替换默认说明'**
  String get historyReplaceInstructions;

  /// No description provided for @historySummaryCost.
  ///
  /// In zh, this message translates to:
  /// **'生成摘要会调用当前模型并产生用量；失败或取消时不会主动重试回溯。'**
  String get historySummaryCost;

  /// No description provided for @historyConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确认回溯'**
  String get historyConfirm;

  /// No description provided for @historyConfirmHint.
  ///
  /// In zh, this message translates to:
  /// **'将切换模型接下来看到的历史。旧分支保留，不会自动发送提问，也不会由 GUI 回滚文件。'**
  String get historyConfirmHint;

  /// No description provided for @historyDraftWarning.
  ///
  /// In zh, this message translates to:
  /// **'输入框已有未发送文字或附件。继续会替换这份草稿：回到用户消息会载入原提问，其他节点会清空输入。'**
  String get historyDraftWarning;

  /// No description provided for @historyBusy.
  ///
  /// In zh, this message translates to:
  /// **'请等当前任务、模型切换或扩展问答结束后再回溯。'**
  String get historyBusy;

  /// No description provided for @historyWorking.
  ///
  /// In zh, this message translates to:
  /// **'正在等待 Pi 完成回溯…'**
  String get historyWorking;

  /// No description provided for @historyStop.
  ///
  /// In zh, this message translates to:
  /// **'取消回溯'**
  String get historyStop;

  /// No description provided for @historyFailed.
  ///
  /// In zh, this message translates to:
  /// **'操作未完成。请刷新历史后重试；若选择了摘要，请检查模型是否可用。'**
  String get historyFailed;

  /// No description provided for @historyStale.
  ///
  /// In zh, this message translates to:
  /// **'历史位置已变化，请刷新后重新选择。'**
  String get historyStale;

  /// No description provided for @historyUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'历史桥接未加载。请正常重启更新后的 GUI，再试一次。'**
  String get historyUnavailable;

  /// No description provided for @historyCancelled.
  ///
  /// In zh, this message translates to:
  /// **'Pi 或扩展已取消操作，未继续回溯。'**
  String get historyCancelled;

  /// No description provided for @historyUncertain.
  ///
  /// In zh, this message translates to:
  /// **'还没收到最终确认。请等待或取消，不要重复回溯。'**
  String get historyUncertain;

  /// No description provided for @historyRefreshFailed.
  ///
  /// In zh, this message translates to:
  /// **'Pi 已确认操作，但界面刷新失败。请刷新会话，不要重复回溯。'**
  String get historyRefreshFailed;

  /// No description provided for @historyPendingDraft.
  ///
  /// In zh, this message translates to:
  /// **'历史提问已保留，尚未覆盖你正在编辑的草稿。'**
  String get historyPendingDraft;

  /// No description provided for @historyRestoreDraft.
  ///
  /// In zh, this message translates to:
  /// **'载入历史提问'**
  String get historyRestoreDraft;

  /// No description provided for @historyCompaction.
  ///
  /// In zh, this message translates to:
  /// **'上下文压缩'**
  String get historyCompaction;

  /// No description provided for @historyBranchSummary.
  ///
  /// In zh, this message translates to:
  /// **'分支摘要'**
  String get historyBranchSummary;

  /// No description provided for @historySystem.
  ///
  /// In zh, this message translates to:
  /// **'系统消息'**
  String get historySystem;

  /// No description provided for @historySettingsEntry.
  ///
  /// In zh, this message translates to:
  /// **'设置记录'**
  String get historySettingsEntry;

  /// No description provided for @historyExtensionEntry.
  ///
  /// In zh, this message translates to:
  /// **'扩展记录'**
  String get historyExtensionEntry;

  /// No description provided for @historyImageOnly.
  ///
  /// In zh, this message translates to:
  /// **'图片消息'**
  String get historyImageOnly;

  /// No description provided for @historyPreviewFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法加载此节点的预览，请重试。'**
  String get historyPreviewFailed;
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
    'that was used.',
  );
}
