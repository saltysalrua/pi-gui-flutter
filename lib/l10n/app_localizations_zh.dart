// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'Pi';

  @override
  String get newConversation => '新对话';

  @override
  String get projects => '项目列表';

  @override
  String get settings => '设置';

  @override
  String get noSessions => '暂无历史对话';

  @override
  String get inputPlaceholder => '给 Pi 输入需求，或指派代码任务...';

  @override
  String get selectModel => '切换模型';

  @override
  String contextUsageDetails(String percent, String used, String total) {
    return '上下文已用 $percent%\n$used / $total Token（估算）';
  }

  @override
  String contextUsagePending(String total) {
    return '上下文用量暂未确定\n模型上限 $total Token，等待 Pi 更新';
  }

  @override
  String get contextUsageUnavailable => '上下文用量暂不可用，等待 Pi 返回数据';

  @override
  String get sendMessage => '发送';

  @override
  String get environmentLocal => 'Local RPC (已连接)';

  @override
  String get agentMain => 'Main Agent';

  @override
  String get windowMinimize => '最小化';

  @override
  String get windowMaximize => '最大化';

  @override
  String get windowRestore => '还原';

  @override
  String get windowClose => '关闭';

  @override
  String get currentWorkspace => '当前项目';

  @override
  String get thinkingIntensity => '思考强度';

  @override
  String get thinkingNone => '关闭';

  @override
  String get thinkingLow => '低';

  @override
  String get thinkingMedium => '中';

  @override
  String get thinkingHigh => '高';

  @override
  String get thinkingXHigh => '超高';

  @override
  String get thinkingMax => '最高';

  @override
  String get defaultGroup => '默认';

  @override
  String get recommendedModels => '推荐模型集';

  @override
  String get reset => '重置';

  @override
  String get back => '返回';

  @override
  String get thinkingMinimal => '极低';

  @override
  String get modelSearchHint => '搜索模型…';

  @override
  String get clearSearch => '清空搜索';

  @override
  String get modelsLoading => '正在从 Pi 读取模型…';

  @override
  String get modelsEmpty => 'Pi 没有可用模型。请在 Pi 中配置提供商后刷新。';

  @override
  String get modelSearchEmpty => '没有找到匹配的模型';

  @override
  String get modelLoadFailed => '无法读取模型。请确认已安装 Pi，且 PATH 中可以找到 pi，然后重试。';

  @override
  String get modelChangeFailed => 'Pi 未能确认模型切换结果。请刷新后重试。';

  @override
  String get modelThinkingFailed => 'Pi 未能确认思考等级。请刷新后重试。';

  @override
  String get piDisconnected => '已与 Pi 断开连接，请刷新重连。';

  @override
  String get piNotConnected => 'Pi 未连接';

  @override
  String get modelNoSelection => '请选择模型';

  @override
  String get modelRefresh => '从 Pi 刷新';

  @override
  String get modelUpdating => '正在等待 Pi 确认…';

  @override
  String get thinkingUnavailable => 'Pi 未返回思考等级，请更新 Pi 后刷新。';

  @override
  String get thinkingNotSupported => '此模型不支持思考。';

  @override
  String get modelPickerDismiss => '关闭模型选择器';

  @override
  String modelAndThinking(String model, String level) {
    return '$model · $level';
  }

  @override
  String availableModelCount(int count) {
    return '可用模型（$count）';
  }

  @override
  String get extensionUnsupported => '暂不支持这类 Pi 扩展界面请求。';

  @override
  String get confirm => '确认';

  @override
  String get cancel => '取消';

  @override
  String get close => '关闭';

  @override
  String get piExtensionInvalidRequest => 'Pi 扩展发来了一条无法显示的请求，连接未中断。';

  @override
  String get piReconnecting => '正在重新连接 Pi…';

  @override
  String get chatYou => '你';

  @override
  String chatAssistantNumber(int number) {
    return '#$number';
  }

  @override
  String get chatReady => '就绪';

  @override
  String get chatWorking => '正在处理…';

  @override
  String get chatRetrying => '服务暂时不可用，Pi 正在重试…';

  @override
  String get chatCompacting => '正在整理上下文…';

  @override
  String get chatStopping => '正在停止…';

  @override
  String get chatStop => '停止';

  @override
  String get chatLoading => '正在读取对话…';

  @override
  String get chatWelcome => '从一个问题开始';

  @override
  String get chatWelcomeHint => '询问代码、分析问题，或让 Pi 修改当前项目。';

  @override
  String get chatInputHint => 'Enter 发送 · Shift+Enter 换行';

  @override
  String get chatBusyHint => '可以先写下一条，当前任务结束后再发送。';

  @override
  String get chatThinking => '思考过程';

  @override
  String get chatCopy => '复制';

  @override
  String get chatCopied => '已复制';

  @override
  String get chatCopyFailed => '复制失败，请重试。';

  @override
  String get chatCode => '代码';

  @override
  String get chatOutput => '输出';

  @override
  String get chatArguments => '参数';

  @override
  String get chatPreviewLimited => '内容较长，仅显示预览；复制可获得完整内容。';

  @override
  String get chatShowMore => '展开内容';

  @override
  String get chatShowLess => '收起内容';

  @override
  String get chatOutputEvicted => '完整输出已从内存释放以节省内存，不影响已保存的会话历史。';

  @override
  String get chatReloadOutput => '重新读取';

  @override
  String get chatHibernated => '此会话已休眠以释放内存；历史已保存，唤醒后会继续。';

  @override
  String get chatWake => '唤醒';

  @override
  String get chatWaking => '正在唤醒…';

  @override
  String get chatToolPreparing => '准备执行';

  @override
  String get chatToolRunning => '执行中';

  @override
  String get chatToolDone => '已完成';

  @override
  String get chatToolFailed => '执行失败';

  @override
  String get chatToolInterrupted => '已中断';

  @override
  String get chatNoOutput => '此工具没有返回文字输出。';

  @override
  String get chatChanges => '文件改动';

  @override
  String get chatChangesEmpty => '本会话还没有文件改动。';

  @override
  String get chatChangesScope =>
      '按文件汇总本会话的成功编辑记录，不是 Git 净改动。终端命令产生的改动不会自动列在这里。';

  @override
  String get chatSelectChange => '选择文件查看编辑记录';

  @override
  String get chatViewDiff => '查看改动';

  @override
  String get chatDiff => 'Diff';

  @override
  String get chatNoChanges => '内容没有变化';

  @override
  String get chatEmptyFile => '空文件';

  @override
  String get chatFileCreated => '新建文件';

  @override
  String chatToolFileStats(int lines, String size) {
    return '$lines 行 · $size';
  }

  @override
  String chatToolTimeout(String seconds) {
    return '超时 $seconds 秒';
  }

  @override
  String get chatWrittenContent => '写入内容';

  @override
  String get chatNoBaseline => '没有旧内容，仅展示本次写入，无法对比。';

  @override
  String get chatDiffUnavailable => 'Pi 没有返回这次编辑的 Diff。';

  @override
  String get chatLatest => '回到最新消息';

  @override
  String get chatLoadFailed => '无法读取对话。请检查 Pi 连接，然后刷新。';

  @override
  String get chatSendFailed => 'Pi 未接受这条消息，草稿已保留。请检查模型配置后重试。';

  @override
  String get chatImageProcessingFailed =>
      '图片未能处理，消息尚未发送，草稿已保留。请重试，或减少图片数量、换用较小的图片。';

  @override
  String get chatReplyFailed => '这次回复未完成。请检查模型服务与额度，再发送消息继续。';

  @override
  String get chatUncertain => '尚未收到 Pi 的确认，暂时禁止再次发送，避免重复执行。请等待确认或刷新查看状态。';

  @override
  String get chatStopFailed => 'Pi 尚未确认停止，请稍后重试停止。';

  @override
  String get chatSessionCancelled => 'Pi 扩展取消了会话切换，原对话已保留。';

  @override
  String get chatInvalidEvent => 'Pi 发来了一条无法显示的事件，其余对话仍会继续。任务结束后可刷新同步。';

  @override
  String get chatAborted => '回复已停止';

  @override
  String get chatLengthLimit => '回复达到模型输出上限，可以发送消息让 Pi 继续。';

  @override
  String get chatImageUnavailable => '图片无法显示，文件可能已移动、损坏或过大。';

  @override
  String get chatUnsupportedContent => '暂不支持显示此内容块';

  @override
  String get chatOpenLinkFailed =>
      '无法打开链接。请检查文件是否存在、是否有默认打开程序；不支持可执行文件、网络共享和特殊协议。';

  @override
  String get chatRemoteImage => '图片未自动加载';

  @override
  String get chatQueued => '等待中的消息';

  @override
  String chatQueuedCount(int count) {
    return '等待中的消息（$count）';
  }

  @override
  String get chatQueueSteering => '本轮补充';

  @override
  String get chatQueueFollowUp => '完成后处理';

  @override
  String chatQueueEntry(String kind, String message) {
    return '$kind：$message';
  }

  @override
  String get chatQueueSteerAction => '本轮补充 · Enter';

  @override
  String get chatQueueFollowUpAction => '完成后处理 · Alt+Enter';

  @override
  String get chatQueueSendOptions => '选择消息处理时机';

  @override
  String get chatQueuePlaceholder => '继续补充… Enter 本轮处理，Alt+Enter 完成后处理';

  @override
  String get chatQueueRestore => '取回排队文字 · Alt+↑\n不停止当前任务。图片需重新添加。';

  @override
  String get chatQueueStop => '停止并取回排队文字 · Esc\n图片需重新添加。';

  @override
  String get chatQueueFailed => '未能取回排队文字，请稍后重试。';

  @override
  String get chatRefresh => '同步对话';

  @override
  String get chatSessionHistoryHint => '当前工作目录的 Pi 历史对话，按最近更新排序。';

  @override
  String get chatRead => '读取';

  @override
  String get chatEdit => '编辑';

  @override
  String get chatWrite => '写入';

  @override
  String get chatBash => '终端';

  @override
  String chatFileCount(int count) {
    return '文件改动（$count）';
  }

  @override
  String chatEditCount(int count) {
    return '$count 次编辑';
  }

  @override
  String chatEditNumber(int count) {
    return '第 $count 次编辑';
  }

  @override
  String get workspaceChoose => '选择工作区';

  @override
  String get workspaceOpen => '打开文件夹';

  @override
  String get workspaceCreate => '新建工作区';

  @override
  String get workspaceName => '文件夹名称';

  @override
  String get workspaceParent => '选择存放位置';

  @override
  String get workspaceCreateHint => '在所选位置创建一个空文件夹，不自动初始化 Git。';

  @override
  String get workspaceRecent => '最近使用';

  @override
  String get workspaceLoading => '正在读取工作区…';

  @override
  String get workspaceRefresh => '刷新工作区与历史';

  @override
  String get workspaceBusy => '请先等待当前操作完成，或停止正在运行的任务。';

  @override
  String get workspaceLoadFailed =>
      '无法读取工作区。请确认 Node.js 和 npm 安装的 Pi 可用，然后刷新重试。';

  @override
  String get workspacePathFailed => '文件夹无法访问，可能已移动或删除。请重新选择。';

  @override
  String get workspaceNameInvalid => '名称无效，请使用普通文件夹名称，不要包含路径分隔符。';

  @override
  String get workspacePathExists => '目标文件夹已存在。请换一个名称，或直接打开它。';

  @override
  String get workspaceCreateFailed => '创建失败，请检查存放位置的写入权限。';

  @override
  String get workspaceSwitchFailed => '未能在目标目录启动 Pi，已尝试恢复原工作区。请检查目录与 Pi 配置后重试。';

  @override
  String get workspaceUnknown => '尚未收到后端确认，请勿重复创建或切换。等待确认后刷新列表。';

  @override
  String get workspaceCreatedKept => '目录已创建并保留，但切换未完成。可从最近使用中重新打开：';

  @override
  String get workspacePersistenceFailed => '最近使用列表未能保存，下次启动可能需要重新选择工作区。';

  @override
  String get sessionSearch => '搜索历史对话…';

  @override
  String get sessionNoMatch => '没有匹配的历史对话';

  @override
  String get sessionHistoryFailed => '历史对话读取失败，请刷新重试。';

  @override
  String get sessionHistoryLoading => '正在读取历史对话…';

  @override
  String get worktreeManage => '选择 Worktree';

  @override
  String get worktreeCreate => '新建 Worktree';

  @override
  String get worktreeBranch => '新分支名称';

  @override
  String get worktreeBase => '起点（分支或完整 Commit SHA）';

  @override
  String get worktreeHead => '当前提交（HEAD）';

  @override
  String get worktreeDetached => '游离 HEAD';

  @override
  String get worktreeLocked => '已锁定';

  @override
  String get worktreeUnavailable => '目录已失效';

  @override
  String get worktreeNotGit => '当前目录不是 Git 仓库，仍可正常聊天。';

  @override
  String get worktreeNoCommit => '仓库还没有提交，首次提交后才能创建 Worktree。';

  @override
  String get worktreeDirty => '当前目录有未提交改动，不会复制到新 Worktree。';

  @override
  String get worktreeCreateHint =>
      '从所选提交创建独立目录和新分支，不改动原目录，不复制未提交或忽略的文件。创建成功后切换到新目录。';

  @override
  String get worktreeLocation => '新目录将放在';

  @override
  String get worktreeGitFailed => 'Git 操作失败，请确认已安装 Git、目录可写，并刷新后重试。';

  @override
  String get worktreeBranchInvalid => '分支名称无效，请换一个名称。';

  @override
  String get worktreeBranchExists => '分支已存在，请为新 Worktree 使用新的分支名称。';

  @override
  String get worktreeBaseInvalid => '起始分支已变化或不可用，请刷新后重新选择。';

  @override
  String get workspaceOpenSelected => '打开工作区';

  @override
  String sessionMessageCount(int count) {
    return '$count 条消息';
  }

  @override
  String get worktreeRemove => '移除 Worktree';

  @override
  String get worktreeRemoveConfirm =>
      '仅移除下面的工作目录，保留 Git 分支和 Pi 会话。存在未提交、未跟踪或忽略的文件时不会移除。';

  @override
  String get worktreeInUse => '不能移除主工作区或当前正在使用的 Worktree，请先切换到其他目录。';

  @override
  String get worktreeDirtyBlocked => '此 Worktree 有未提交、未跟踪或忽略的文件，未移除。请先自行保存或清理。';

  @override
  String get worktreeLockedBlocked => '此 Worktree 已锁定，未移除。请先在 Git 中确认并解除锁定。';

  @override
  String get workspaceCreateOpen => '创建并打开';

  @override
  String get chatImage => '图片';

  @override
  String get chatAddImages => '添加图片';

  @override
  String get chatRemoveImage => '移除图片';

  @override
  String get chatPreviewImage => '点击放大图片';

  @override
  String get chatImageLoading => '正在读取图片…';

  @override
  String get chatOpenFile => '用系统默认程序打开';

  @override
  String get chatLoadRemoteImage => '点击加载网络图片';

  @override
  String get chatImagePickFailed => '无法读取图片，请检查文件后重新选择。';

  @override
  String get chatImageFormat => '请选择 PNG、JPEG、GIF 或 WebP 图片。';

  @override
  String get chatImageTooLarge => '图片过大。单张最多 10 MB，总共最多 20 MB，分辨率不超过 4000 万像素。';

  @override
  String get chatImageTooMany => '每条消息最多添加 8 张图片。';

  @override
  String get chatImageModel => '当前模型不支持图片，请切换模型或移除图片。';

  @override
  String get chatAddAttachment => '添加附件';

  @override
  String get chatAddFiles => '添加文件';

  @override
  String get chatRemoveAttachment => '移除附件';

  @override
  String get chatPasteImage => '粘贴的图片';

  @override
  String get chatPasteFailed => '无法读取剪贴板附件。请重新复制，或使用加号添加；更新应用后请重新打开窗口。';

  @override
  String get chatFilePickFailed => '无法添加文件，请检查文件是否仍存在、是否可读取。不支持文件夹和网络共享。';

  @override
  String get chatFileTooLarge => '文件过大。每个文件最多 20 MB，文件附件合计最多 50 MB。';

  @override
  String get chatFileTooMany => '每条消息最多添加 8 个文件。';

  @override
  String get chatFileAttachmentHint =>
      '发送缓存副本，由 Pi 按需读取。PDF、Office 等文档需要后端有相应读取工具。';

  @override
  String chatAttachmentSize(String size) {
    return '$size MB';
  }

  @override
  String get chatLightboxClose => '关闭大图（Esc）';

  @override
  String get chatLightboxHint => '滚轮缩放，拖动平移；双击放大或复位。';

  @override
  String get settingsBack => '返回应用';

  @override
  String get settingsSearch => '搜索设置…';

  @override
  String get settingsRefresh => '刷新';

  @override
  String get settingsNoResults => '没有找到匹配的设置';

  @override
  String get piPageTitle => 'pi';

  @override
  String get piPageSubtitle => '查看 Pi 后端的版本，在线检查更新并浏览更新日志。';

  @override
  String get piUpdates => '更新检查';

  @override
  String get piCurrentVersion => '当前版本';

  @override
  String get piLatestVersion => '最新版本';

  @override
  String get piCheckUpdate => '检查更新';

  @override
  String get piCheckHint => '从 npm 查询 Pi 已发布的最新版本。';

  @override
  String get piChecking => '正在检查更新…';

  @override
  String get piUpToDate => '已是最新版本。';

  @override
  String piUpdateAvailable(String version) {
    return '发现新版本 $version。';
  }

  @override
  String get piUpdateHint =>
      '更新会直接在本页运行 pi update --self，完成后无需重启本应用：正在运行的会话继续使用当前版本，之后新开的会话自动使用新版本。';

  @override
  String get piUpdateNow => '立即更新';

  @override
  String get piUpdateRunning => '正在更新…';

  @override
  String get piUpdateFailedHint => '更新失败了。可以看看下方输出找原因，或复制手动命令到终端执行。';

  @override
  String get piUpdateOutput => '更新输出';

  @override
  String get piUpdateManualCommand => '手动更新命令';

  @override
  String get piCheckFailed => '检查更新失败，请检查网络后重试。';

  @override
  String get piRefresh => '刷新数据';

  @override
  String get piRefreshHint => '重新读取本地版本与更新日志，并联网检查最新版本。后台也会定期自动刷新。';

  @override
  String get piUpcomingNotes => '新版本更新说明';

  @override
  String get piUpcomingLoading => '正在获取新版本更新说明…';

  @override
  String get piUpcomingFailed => '没能获取新版本更新说明，可以点上方“npm 页面”在线查看。';

  @override
  String get piLoading => '正在读取 Pi 的安装信息…';

  @override
  String get piLoadFailed => '无法读取 Pi 的安装信息。请确认 Pi 是用 npm 全局安装的，然后重试。';

  @override
  String get piRegistryPage => 'npm 页面';

  @override
  String get piRegistryPageHint => '在浏览器中打开这个包的 npm 介绍页。';

  @override
  String get piOpenRegistry => '打开 npm 页面';

  @override
  String get piChangelog => '更新日志';

  @override
  String get piChangelogEmpty => '没有匹配的版本。';

  @override
  String get piShowMore => '显示更多版本';

  @override
  String get piCurrentTag => '当前';

  @override
  String get pluginsPageTitle => '插件';

  @override
  String get pluginsPageSubtitle => '安装和管理 Pi 的扩展、技能、提示词与主题包。';

  @override
  String get pluginsTabGallery => '市场';

  @override
  String get pluginsTabManage => '管理';

  @override
  String get pluginsGalleryHint =>
      '列表来自 npm 上带 pi-package 关键词的公开包，与 pi.dev/packages 同源。';

  @override
  String get pluginsSearchGalleryHint => '搜索插件市场…';

  @override
  String get pluginsSearchManageHint => '搜索已安装的插件和资源…';

  @override
  String get pluginsGalleryEmpty => '没有找到匹配的插件。';

  @override
  String get pluginsGalleryFailed => '插件市场查询失败，请检查网络后重试。';

  @override
  String pluginsGalleryFailedDetail(Object error) {
    return '插件市场查询失败：$error';
  }

  @override
  String get pluginsShowMore => '显示更多';

  @override
  String get pluginsSortLabel => '排序方式';

  @override
  String get pluginsSortRelevance => '相关性';

  @override
  String get pluginsSortDownloads => '下载量';

  @override
  String get pluginsSortUpdated => '最近更新';

  @override
  String get pluginsSortName => '名称';

  @override
  String get pluginsInstall => '安装';

  @override
  String get pluginsInstalling => '正在安装…';

  @override
  String get pluginsInstalled => '已安装';

  @override
  String pluginsMonthlyDownloads(int count) {
    return '$count 次下载/月';
  }

  @override
  String get pluginsOpenRepo => '打开仓库';

  @override
  String get pluginsOpenNpm => '打开 npm 页面';

  @override
  String get pluginsLoadFailed => '无法读取插件列表。';

  @override
  String pluginsLoadFailedDetail(Object error) {
    return '无法读取插件列表：$error';
  }

  @override
  String get pluginsBusyHint => '有操作正在进行，请稍候。';

  @override
  String pluginsActionFailed(Object error) {
    return '操作失败：$error';
  }

  @override
  String get pluginsEmpty => '还没有安装任何插件，去市场页安装一个吧。';

  @override
  String get pluginsScopeUser => '全局';

  @override
  String get pluginsScopeProject => '项目';

  @override
  String get pluginsFiltered => '已筛选';

  @override
  String get pluginsNotInstalled => '未安装';

  @override
  String get pluginsRemove => '移除';

  @override
  String get pluginsRemoveConfirmTitle => '移除插件';

  @override
  String pluginsRemoveConfirmMessage(Object source) {
    return '会从全局设置里移除 $source，并删除它的安装目录。确定要移除吗？';
  }

  @override
  String get pluginsUpdate => '更新';

  @override
  String get pluginsUpdateAll => '全部更新';

  @override
  String get pluginsCheckUpdates => '检查更新';

  @override
  String get pluginsChecking => '正在检查…';

  @override
  String pluginsUpdatesAvailable(int count) {
    return '$count 个插件有新版本';
  }

  @override
  String get pluginsUpToDate => '所有插件都是最新版本。';

  @override
  String get pluginsOperationLog => '操作输出';

  @override
  String get pluginsTopLevelGroup => '本机插件';

  @override
  String get pluginsResourcesExtensions => '扩展';

  @override
  String get pluginsResourcesSkills => '技能';

  @override
  String get pluginsResourcesPrompts => '提示词';

  @override
  String get pluginsResourcesThemes => '主题';

  @override
  String get pluginsToggleOn => '启用';

  @override
  String get pluginsToggleOff => '停用';

  @override
  String get pluginsProjectScopeHint => '项目级插件请在对应项目目录用 pi config -l 管理。';

  @override
  String get pluginsNoChannel => '插件管理需要连接 Pi 后端，请回到主界面后重试。';

  @override
  String get appearanceTitle => '外观';

  @override
  String get appearanceSubtitle => '调整配色、毛玻璃、文字大小和界面比例。修改后立即生效，自动保存。';

  @override
  String get appearanceTheme => '主题与配色';

  @override
  String get appearanceMode => '显示模式';

  @override
  String get appearanceModeHint => '跟随系统，或始终使用浅色、深色。';

  @override
  String get appearanceSystem => '跟随系统';

  @override
  String get appearanceLight => '浅色';

  @override
  String get appearanceDark => '深色';

  @override
  String get appearanceSource => '配色来源';

  @override
  String get appearanceSourceHint => 'Material 3 会用种子色生成相互搭配的背景、文字和强调色。';

  @override
  String get appearanceOriginal => '默认配色';

  @override
  String get appearanceWindows => 'Windows 强调色';

  @override
  String get appearanceCustomSeed => '自选种子色';

  @override
  String get appearanceSeed => '种子色';

  @override
  String get appearanceSeedHint => '生成整套配色，不是把所有部位涂成同一种颜色。';

  @override
  String get appearanceSystemHint =>
      '读取 Windows 强调色，切回应用时自动更新。Windows 开启“从背景自动选取强调色”后可随壁纸变化。';

  @override
  String get appearanceSystemUnavailable =>
      '暂时无法读取系统强调色，正在使用默认种子色。更新应用后请重新打开，或点击重试。';

  @override
  String get appearanceRefresh => '重新读取';

  @override
  String get appearancePerformance => '帧率与性能';

  @override
  String get appearanceFrameRate => '全局帧率上限';

  @override
  String get appearanceFrameRateHint =>
      '限制整个界面，包括滚动、拖拽和文字更新。默认 120 FPS；实际帧率不会超过屏幕刷新率。';

  @override
  String get appearanceAnimationFrameRate => '持续动画帧率';

  @override
  String get appearanceAnimationFrameRateHint =>
      '只控制微光和加载转圈，默认 30 FPS；同时受全局上限限制，不降低其他交互的帧率。';

  @override
  String get appearanceFrameRateDisplay => '跟随屏幕';

  @override
  String appearanceFrameRateValue(int fps) {
    return '$fps FPS';
  }

  @override
  String get appearanceSizing => '文字与界面大小';

  @override
  String get appearanceFont => '基准字号';

  @override
  String get appearanceFontHint => '只调整文字大小，标题与代码字号按比例变化；保留系统文字缩放。默认 13。';

  @override
  String get appearanceScale => 'UI 比例';

  @override
  String get appearanceScaleHint => '整体缩放文字、按钮、图标和间距，叠加在系统显示缩放之上。默认 100%。';

  @override
  String get appearanceToolDisplay => '工具显示';

  @override
  String get appearanceToolDisplayHint =>
      '设置聊天里 agent 工具卡片默认显示多详细，想看细节时点开单个卡片即可。';

  @override
  String get appearanceToolDensity => '工具卡片';

  @override
  String get appearanceToolCollapsed => '收起';

  @override
  String get appearanceToolCompact => '简略';

  @override
  String get appearanceToolExpanded => '展开';

  @override
  String get appearanceToolCollapsedHint => '只显示一行工具标题，最省空间。';

  @override
  String get appearanceToolCompactHint =>
      '标题加几行预览：输出 6 行、失败 3 行、文件改动 8 行。默认样式。';

  @override
  String get appearanceToolExpandedHint => '直接显示完整命令、输出与文件改动，最直观但占空间。';

  @override
  String get appearanceHibernate => '闲置会话休眠';

  @override
  String get appearanceHibernateHint =>
      '长时间未使用的会话会结束其后台 Pi 进程以释放内存，历史照常保存在磁盘。唤醒时重新打开同一会话，不会重发消息；正在运行、有草稿或结果未确认的会话绝不休眠。';

  @override
  String get hibernateNever => '从不';

  @override
  String get hibernate15Minutes => '15 分钟';

  @override
  String get hibernate60Minutes => '1 小时';

  @override
  String get appearanceOn => '开';

  @override
  String get appearanceOff => '关';

  @override
  String get appearanceExtensionSlots => '扩展显示位置';

  @override
  String get appearanceExtensionSlotsHint =>
      'Pi 扩展想在界面上展示内容时，允许它出现在哪些位置。扩展弹窗提问始终显示，不受这些开关影响。';

  @override
  String get appearanceSlotAboveEditor => '输入框上方';

  @override
  String get appearanceSlotAboveEditorHint => '任务进度、待办卡片等扩展卡片。';

  @override
  String get appearanceSlotBelowEditor => '输入框下方';

  @override
  String get appearanceSlotBelowEditorHint => '快捷建议、辅助提示等文字扩展。';

  @override
  String get appearanceSlotStatusBar => '状态栏徽章';

  @override
  String get appearanceSlotStatusBarHint => '分支、Token 用量等扩展状态徽章。';

  @override
  String get appearanceSlotSidebarPanel => '侧边栏扩展面板';

  @override
  String get appearanceSlotSidebarPanelHint => '侧边栏底部的扩展内容（如插件面板）。';

  @override
  String get appearanceSlotNotificationToast => '通知浮层';

  @override
  String get appearanceSlotNotificationToastHint => '右上角的扩展通知气泡。';

  @override
  String get appearanceColors => '分区颜色';

  @override
  String get appearanceColorsHint => '覆盖当前显示模式的配色；浅色与深色分别保存。切换配色来源不会清除覆盖值。';

  @override
  String get appearanceEditingLight => '正在编辑浅色配色';

  @override
  String get appearanceEditingDark => '正在编辑深色配色';

  @override
  String get appearanceAdvanced => '高级颜色';

  @override
  String get appearanceAdvancedHint => '文字、边框与状态色';

  @override
  String get appearancePrimary => '强调色';

  @override
  String get appearanceCanvas => '主背景';

  @override
  String get appearanceSidebar => '顶部与侧边栏';

  @override
  String get appearanceComposer => '输入框';

  @override
  String get appearanceCard => '卡片';

  @override
  String get appearanceCode => '代码区';

  @override
  String get appearanceUserMessage => '用户消息';

  @override
  String get appearanceElevated => '浮层与菜单';

  @override
  String get appearanceTextPrimary => '主要文字';

  @override
  String get appearanceTextSecondary => '次要文字';

  @override
  String get appearanceTextMuted => '辅助文字';

  @override
  String get appearanceBorder => '边框';

  @override
  String get appearanceSuccess => '成功 / Diff 新增';

  @override
  String get appearanceWarning => '警告';

  @override
  String get appearanceError => '错误 / Diff 删除';

  @override
  String get appearanceAutomatic => '自动';

  @override
  String get appearanceOverridden => '已自定义';

  @override
  String get appearanceResetColor => '恢复自动配色';

  @override
  String get appearanceResetColors => '重置此模式的颜色';

  @override
  String get appearanceResetColorsHint => '仅清除当前浅色或深色模式的颜色覆盖，不改变字号、比例和另一种模式。';

  @override
  String get appearanceResetAll => '恢复默认外观';

  @override
  String get appearanceResetAllHint =>
      '恢复默认配色、13 基准字号和 100% UI 比例，关闭全部毛玻璃并重置其不透明度，清除浅色、深色的自定义颜色。';

  @override
  String get appearanceSaving => '正在保存…';

  @override
  String get appearanceSaveFailed => '本次修改已生效，但未能保存到本机。请重试，或检查应用数据目录的写入权限。';

  @override
  String get appearanceLoadFailed => '无法读取已保存的外观，暂时使用默认值。重新打开应用可重试；修改设置会保存新值。';

  @override
  String get appearanceRetry => '重试保存';

  @override
  String get appearancePreview => '预览';

  @override
  String get appearancePreviewText => '文字、卡片和代码会随你的设置一起变化。';

  @override
  String get appearancePreviewCode => 'const greeting = \"Hello, Pi\";';

  @override
  String get appearanceChooseColor => '选择颜色';

  @override
  String get appearanceHex => '#RRGGBB';

  @override
  String get appearanceHexInvalid => '请输入 6 位十六进制颜色，例如 #0075DE。';

  @override
  String get appearanceApply => '应用颜色';

  @override
  String get appearanceHue => '色相';

  @override
  String get appearanceSaturation => '饱和度';

  @override
  String get appearanceValue => '明度';

  @override
  String get appearanceContrastWarning => '这个颜色与当前文字或背景的对比度较低，可能不易看清。';

  @override
  String appearancePercent(int value) {
    return '$value%';
  }

  @override
  String appearanceFontValue(int value) {
    return '$value';
  }

  @override
  String get appearanceGlass => '桌面毛玻璃';

  @override
  String get appearanceGlassHint =>
      '顶部与侧栏、主界面和卡片分别设置。桌面模糊由 Windows 控制，卡片模糊应用内背景，文字保持清晰。明暗模式共用设置，需要 Windows 11 22H2 或更新版本。';

  @override
  String get appearanceGlassSidebar => '顶部与侧边栏毛玻璃';

  @override
  String get appearanceGlassSidebarHint => '标题栏、左右侧栏和拖拽区一起变化。';

  @override
  String get appearanceGlassCanvas => '主界面毛玻璃';

  @override
  String get appearanceGlassCanvasHint => '用于聊天与设置页的主背景；输入框和其他卡片由下方的卡片毛玻璃单独控制。';

  @override
  String get appearanceGlassSidebarOpacity => '顶部与侧边栏底色不透明度';

  @override
  String get appearanceGlassCanvasOpacity => '主界面底色不透明度';

  @override
  String get appearanceGlassCards => '卡片毛玻璃';

  @override
  String get appearanceGlassCardsHint =>
      '用于输入卡片、设置卡片和弹窗等有底色的卡片，不改变透明工具行。要透出桌面，请同时开启主界面毛玻璃；纯色背景上的模糊不明显。';

  @override
  String get appearanceGlassCardsOpacity => '卡片毛玻璃底色不透明度';

  @override
  String get appearanceGlassOpacityHint =>
      '越低越透，100% 为纯色。看不清文字时请调高；底色仍可在“分区颜色”中修改。';

  @override
  String get appearanceGlassOn => '开启';

  @override
  String get appearanceGlassOff => '关闭';

  @override
  String get appearanceGlassSystemDisabled =>
      '系统暂未允许透明效果，正在显示纯色。请检查 Windows 的“透明效果”、对比度主题和节电模式。';

  @override
  String get appearanceGlassUnsupported =>
      '当前系统不支持此材质，正在显示纯色。需要 Windows 11 22H2 或更新版本。';

  @override
  String get appearanceGlassUnavailable =>
      '原生毛玻璃暂不可用，正在显示纯色。更新并重新打开应用后可重试；热重载无法载入原生改动。';

  @override
  String get browserTitle => '文件与 Git';

  @override
  String get browserFiles => '文件';

  @override
  String get browserGraph => 'Git graph';

  @override
  String get browserRefresh => '刷新文件与 Git';

  @override
  String get browserCollapse => '折叠全部文件夹';

  @override
  String get browserLoading => '正在读取…';

  @override
  String get browserEmptyFolder => '空文件夹';

  @override
  String get browserNoGit => '当前文件夹不在 Git 仓库中。';

  @override
  String get browserNoCommits => '仓库还没有提交。';

  @override
  String get browserGitMissing => '找不到 Git。安装 Git 后刷新，仍可浏览文件。';

  @override
  String get browserReadFailed => '读取失败，请检查文件夹权限后重试。';

  @override
  String get browserGitFailed => '无法读取 Git 状态，请检查仓库后刷新。';

  @override
  String get browserOldBackend => '此窗口的后端尚不支持文件浏览。下次正常启动更新后的应用即可使用，当前聊天不受影响。';

  @override
  String get browserWorkspaceChanged => '工作区已切换，请关闭后重新选择。';

  @override
  String get browserRetry => '重试';

  @override
  String get browserMore => '加载更多';

  @override
  String get browserLimit => '已达到预览上限，请在外部工具中查看其余内容。';

  @override
  String get browserContent => '文件内容';

  @override
  String get browserStaged => '已暂存的改动';

  @override
  String get browserUnstaged => '未暂存的改动';

  @override
  String get browserCommitDiff => '与首个父提交比较（首次提交与空内容比较）';

  @override
  String get browserBinary => '此文件是二进制或不是 UTF-8 文本，暂不预览。';

  @override
  String get browserLargeFile => '文件超过 256 KiB，暂不预览。';

  @override
  String get browserMissingFile => '文件已删除，可在 Diff 中查看改动。';

  @override
  String get browserSymlink => '符号链接不会展开或读取，以免离开当前工作区。';

  @override
  String get browserUnsupported => '暂不支持预览此类文件。';

  @override
  String get browserCommitDetails => '提交详情';

  @override
  String get browserCommitFilesEmpty => '此次提交没有当前工作区内的文件改动。';

  @override
  String get browserGraphScope => '显示当前仓库的本地分支、远程跟踪分支和标签；不会联网拉取。';

  @override
  String get browserFileScope => '只读浏览当前工作区；包含隐藏和忽略文件，不显示 .git。状态标记可悬停查看说明。';

  @override
  String get browserClean => '已提交 · 无改动';

  @override
  String get browserModified => '已修改';

  @override
  String get browserStatusStaged => '已暂存';

  @override
  String get browserAdded => '新增';

  @override
  String get browserDeleted => '已删除';

  @override
  String get browserRenamed => '已重命名';

  @override
  String get browserUntracked => '未跟踪';

  @override
  String get browserIgnored => '已忽略';

  @override
  String get browserConflict => '存在冲突';

  @override
  String get browserNoStatus => '无 Git 状态';

  @override
  String browserIndexStatus(String status) {
    return '暂存区：$status';
  }

  @override
  String browserWorktreeStatus(String status) {
    return '工作目录：$status';
  }

  @override
  String get browserUnchanged => '无改动';

  @override
  String get tabsChat => '聊天';

  @override
  String get tabsClose => '关闭标签页（Ctrl+W）';

  @override
  String get tabsAll => '所有标签页';

  @override
  String get tabsSplit => '移到右侧新分组';

  @override
  String get tabsMerge => '合并所有标签页';

  @override
  String get tabsActions => '标签页操作';

  @override
  String get tabsCloseOthers => '关闭其他标签页';

  @override
  String get tabsReadOnly => '只读';

  @override
  String get tabsRefresh => '重新读取此预览';

  @override
  String get workbenchSharedDirectory =>
      '同一目录还有其他会话正在运行，可能修改同一份文件。需要隔离时请新建 Worktree。';

  @override
  String get workbenchSearch => '搜索项目、Worktree 和会话…';

  @override
  String get workbenchAddProject => '添加项目';

  @override
  String get workbenchMain => '主目录';

  @override
  String get workbenchWaiting => '等待回答';

  @override
  String get workbenchRunning => '运行中';

  @override
  String get workbenchUnread => '有新消息';

  @override
  String get workbenchHistory => '历史会话';

  @override
  String get workbenchCloseSession => '关闭会话';

  @override
  String get workbenchStopClose => '停止并关闭';

  @override
  String get workbenchCloseRunning =>
      '此会话仍在运行或等待回答。停止并关闭会结束其 Pi 进程，已保存的历史仍会保留。';

  @override
  String get workbenchCloseDraft => '此会话还有未发送的文字或附件。关闭后草稿不会保留，已保存的历史不受影响。';

  @override
  String get workbenchForgetProject => '从列表移除项目';

  @override
  String get workbenchForgetHint => '仅从列表移除，不删除目录、分支或历史。请先关闭此项目下的所有会话。';

  @override
  String get workbenchName => 'Worktree 名称';

  @override
  String get workbenchCreateHint =>
      '在后台创建独立目录和新分支，不复制未提交或忽略文件，也不自动安装依赖。其他会话可以继续运行。';

  @override
  String get workbenchCreateBackground => '后台创建';

  @override
  String get workbenchCreating => '正在创建…';

  @override
  String get workbenchFailed => '操作失败';

  @override
  String get workbenchNoMatch => '没有匹配的项目或会话';

  @override
  String get workbenchEmpty => '添加项目，或在左侧选择目录开始对话。';

  @override
  String get workbenchOperationUnknown => '正在等待后端确认，请勿重复操作。稍后刷新列表查看结果。';

  @override
  String get workbenchDisconnected =>
      '会话进程已退出，其他会话不受影响。可关闭此标签后从历史重新打开；不会自动重发消息。';

  @override
  String workbenchSessionCount(int count) {
    return '$count 个会话';
  }

  @override
  String get workbenchCloseWindow => '还有会话正在运行或有未发送的草稿。关闭窗口会停止所有会话，并丢弃未发送的草稿。';

  @override
  String get workbenchRemoveInUse => '请先关闭此目录下的所有会话，再移除 Worktree。主目录不能移除。';

  @override
  String get workbenchWaitBeforeClose =>
      '工作区操作尚未结束，请等待创建或移除完成后再关闭窗口，以免留下未完成的 Git 目录。';

  @override
  String get quotaPageTitle => '账号额度';

  @override
  String get quotaPageSubtitle =>
      '读取 Pi 保存的 Codex OAuth 登录，查询 ChatGPT 套餐的实时用量窗口。';

  @override
  String get quotaRefresh => '刷新';

  @override
  String get quotaRefreshing => '正在刷新…';

  @override
  String get quotaLoading => '正在读取登录信息并查询额度…';

  @override
  String get quotaLimitReached => '已达到当前套餐的用量上限，请等待窗口重置。';

  @override
  String get quotaAccountGroup => '账号';

  @override
  String get quotaProvider => '服务';

  @override
  String get quotaProviderDescription => '登录信息来自 Pi 的 auth.json，本页只做只读查询。';

  @override
  String get quotaEmail => '邮箱';

  @override
  String get quotaPlan => '套餐';

  @override
  String get quotaTokenExpiry => '令牌有效期';

  @override
  String get quotaTokenExpiredHint =>
      '令牌已过期。请运行 pi auth check --provider openai-codex 刷新，或在 Pi 中重新登录。';

  @override
  String get quotaUsageGroup => '用量窗口';

  @override
  String get quotaUsageGroupDescription => '用量按滑动窗口统计，查询额度本身不消耗用量。';

  @override
  String get quotaPrimaryWindow => '近 5 小时';

  @override
  String get quotaSecondaryWindow => '近 7 天';

  @override
  String quotaWindowResets(String time) {
    return '重置于 $time';
  }

  @override
  String quotaRemaining(int percent) {
    return '剩余 $percent%';
  }

  @override
  String get quotaCreditsGroup => '积分余额';

  @override
  String get quotaCreditsBalance => '余额';

  @override
  String get quotaCreditsDescription => '按需付费积分，仅在账号开通时显示实际数字。';

  @override
  String get quotaNoCredits => '无积分';

  @override
  String get quotaMissingTitle => '未找到 Codex 登录信息';

  @override
  String get quotaMissingHint =>
      'Pi 的 auth.json 中没有 openai-codex 的 OAuth 登录。请先在 Pi 中完成 Codex 登录后，回到本页刷新。';

  @override
  String get quotaFailedTitle => '查询额度失败';

  @override
  String get quotaUnauthorizedHint =>
      '令牌已过期或失效。请运行 pi auth check --provider openai-codex 刷新令牌，或在 Pi 中重新登录后重试。';

  @override
  String get quotaNetworkHint => '无法连接 ChatGPT 服务，请检查网络后重试。';

  @override
  String get quotaParseHint => '服务返回了无法识别的内容，可能是接口格式发生了变化。';

  @override
  String get quotaOpenDetails => '点击查看详情';

  @override
  String get historyTitle => '历史回溯';

  @override
  String get historyHint => '浏览不会切换会话。回溯保留旧分支；GUI 不回滚代码文件，已安装扩展的回溯行为仍会执行。';

  @override
  String get historySearch => '搜索历史消息、标签或节点 ID…';

  @override
  String get historyFilter => '显示内容';

  @override
  String get historyDefault => '默认';

  @override
  String get historyNoTools => '隐藏工具结果';

  @override
  String get historyUserOnly => '仅我的消息';

  @override
  String get historyLabeledOnly => '仅有标签';

  @override
  String get historyAll => '全部';

  @override
  String get historyEmpty => '没有匹配的历史节点。试试更换过滤方式。';

  @override
  String get historySelect => '选择一个节点预览，再决定从哪里继续。';

  @override
  String get historyCurrent => '定位当前位置';

  @override
  String get historyActive => '当前位置';

  @override
  String get historyActivePath => '当前分支';

  @override
  String get historyExpand => '展开所有分支';

  @override
  String get historyCollapse => '折叠或展开此分支';

  @override
  String get historyTimestamps => '切换标签时间';

  @override
  String get historyLabel => '编辑标签';

  @override
  String get historyLabelHint => '输入标签，留空则清除';

  @override
  String get historyNavigate => '从这里继续';

  @override
  String get historyEdit => '回到这里修改';

  @override
  String get historyFork => '从这里新建会话';

  @override
  String get historyClone => '复制当前分支';

  @override
  String get historyForkHint => '从所选用户消息之前创建独立会话，原会话和其他分支保留。';

  @override
  String get historySummary => '离开分支时的摘要';

  @override
  String get historySummaryNone => '不生成摘要';

  @override
  String get historySummaryDefault => '生成默认摘要';

  @override
  String get historySummaryCustom => '自定义摘要说明';

  @override
  String get historyInstructions => '希望摘要保留哪些信息？会调用当前模型。';

  @override
  String get historyInstructionsMode => '摘要说明用法';

  @override
  String get historyAppendInstructions => '补充默认说明';

  @override
  String get historyReplaceInstructions => '替换默认说明';

  @override
  String get historySummaryCost => '生成摘要会调用当前模型并产生用量；失败或取消时不会主动重试回溯。';

  @override
  String get historyConfirm => '确认回溯';

  @override
  String get historyConfirmHint =>
      '将切换模型接下来看到的历史。旧分支保留，不会自动发送提问，也不会由 GUI 回滚文件。';

  @override
  String get historyDraftWarning =>
      '输入框已有未发送文字或附件。继续会替换这份草稿：回到用户消息会载入原提问，其他节点会清空输入。';

  @override
  String get historyBusy => '请等当前任务、模型切换或扩展问答结束后再回溯。';

  @override
  String get historyWorking => '正在等待 Pi 完成回溯…';

  @override
  String get historyStop => '取消回溯';

  @override
  String get historyFailed => '操作未完成。请刷新历史后重试；若选择了摘要，请检查模型是否可用。';

  @override
  String get historyStale => '历史位置已变化，请刷新后重新选择。';

  @override
  String get historyUnavailable => '历史桥接未加载。请正常重启更新后的 GUI，再试一次。';

  @override
  String get historyCancelled => 'Pi 或扩展已取消操作，未继续回溯。';

  @override
  String get historyUncertain => '还没收到最终确认。请等待或取消，不要重复回溯。';

  @override
  String get historyRefreshFailed => 'Pi 已确认操作，但界面刷新失败。请刷新会话，不要重复回溯。';

  @override
  String get historyPendingDraft => '历史提问已保留，尚未覆盖你正在编辑的草稿。';

  @override
  String get historyRestoreDraft => '载入历史提问';

  @override
  String get historyCompaction => '上下文压缩';

  @override
  String get historyBranchSummary => '分支摘要';

  @override
  String get historySystem => '系统消息';

  @override
  String get historySettingsEntry => '设置记录';

  @override
  String get historyExtensionEntry => '扩展记录';

  @override
  String get historyImageOnly => '图片消息';

  @override
  String get historyPreviewFailed => '无法加载此节点的预览，请重试。';

  @override
  String get providerTitle => 'Provider 配置';

  @override
  String get providerNotInstalled => '还没安装 Provider 插件。装好后模型才会出现在模型选择器里。';

  @override
  String get providerDisabled => '插件已安装，但目前是停用状态。启用后，新会话会加载它。';

  @override
  String get providerInstallTitle => '安装 Provider 插件';

  @override
  String get providerInstallWarning =>
      '此操作会把随应用提供的 pi-provider-switch 安装到 Pi 的全局配置。扩展拥有与 Pi 相同的系统权限，之后启动的会话会加载它，并用配置里的 Key 获取模型列表。配置可能包含 API Key，请优先使用环境变量。确定安装吗？';

  @override
  String get providerAdd => '添加配置';

  @override
  String get providerSave => '保存';

  @override
  String providerModelCount(int count) {
    return '$count 个模型';
  }

  @override
  String providerRemoveWarning(String name) {
    return '删除配置“$name”？这不会卸载插件，且无法撤销。';
  }

  @override
  String get providerName => '例如 my-api';

  @override
  String get providerBaseUrl => 'https://api.example.com/v1';

  @override
  String get providerApi => '接口类型';

  @override
  String get providerKey => 'sk-… 或 \$ENV_VAR';

  @override
  String get providerKeepKey => '已保存 Key，留空则不修改';

  @override
  String get providerEnable => '启用插件';

  @override
  String get providerNameLabel => '配置名称';

  @override
  String get providerBaseUrlLabel => 'API 地址';

  @override
  String get providerKeyLabel => 'API Key';

  @override
  String get providerFetchModels => '获取模型列表';

  @override
  String providerFetchedModels(int count) {
    return '已获取 $count 个模型';
  }

  @override
  String get providerErrorInvalid =>
      '有内容没填对，请检查 API 地址（需以 http:// 或 https:// 开头）和模型。';

  @override
  String get providerErrorName =>
      '名称可用中文、字母、数字、点、横线或下划线（1–64 个字），以文字或数字开头，不能用保留名称。';

  @override
  String get providerErrorFile =>
      'provider-profiles.json 内容损坏，读取不了。请先手动修好这个文件。';

  @override
  String get providerErrorNotFound => '这个配置已经不存在了，可能在别处被删了。请刷新后再试。';

  @override
  String get providerErrorUnreachable => '连不上这个 API 地址，请检查地址和网络。';

  @override
  String get providerErrorUnauthorized => 'API Key 不对，或者没有权限获取模型列表。';

  @override
  String get providerErrorHttp => '服务器拒绝了获取模型列表的请求，请确认地址是否正确。';

  @override
  String get providerErrorNotJson => '这个地址没有返回模型列表，请确认地址是否正确（通常以 /v1 结尾）。';

  @override
  String get providerErrorEmpty => '服务器没有返回任何模型，请手动填写模型 ID。';

  @override
  String get providerErrorKeyEnv => '找不到 Key 里引用的环境变量。请确认它已设置，或者直接填 Key。';

  @override
  String get providerErrorKeyCommand => '运行 Key 命令失败，请检查 ! 后面的命令。';

  @override
  String providerErrorGeneric(String detail) {
    return '操作没有完成：$detail';
  }

  @override
  String get providerErrorExists => '这个名称已经有配置了，请换个名称，或返回列表编辑原配置。';

  @override
  String get providerErrorKeyEndpoint =>
      'API 地址或接口类型已更改。为避免把旧 Key 发给其他服务，请重新填写 Key，或选择「移除已存 Key」。';

  @override
  String get providerErrorUnknownOutcome => '暂未确认操作结果，请先刷新配置确认，不要重复提交。';

  @override
  String get providerErrorBackend => '当前运行的后端还不支持此功能。请结束任务后重新启动应用，再试一次。';

  @override
  String get providerErrorFallback => '操作未完成，请检查连接后重试；仍失败时请查看 Pi 日志。';

  @override
  String get providerNoMatches => '没有匹配的配置，试试其他关键词。';

  @override
  String get providerShowKey => '显示本次输入的 Key';

  @override
  String get providerHideKey => '隐藏 Key';

  @override
  String get providerSavedKey => '已存 Key';

  @override
  String get providerRetainKey => '保留（输入新 Key 可替换）';

  @override
  String get providerClearKey => '移除已存 Key';

  @override
  String providerOutdated(String version, String latest) {
    return '已安装的 Provider 插件是旧版（$version）。旧版会在每次打开会话时把模型换成“默认配置”的模型，更新到 $latest 后就不会了。';
  }

  @override
  String get providerUpgradeTitle => '更新 Provider 插件';

  @override
  String providerUpgradeWarning(String latest) {
    return '会用随应用提供的 $latest 版替换旧版插件登记。已经打开的会话继续用旧版，新打开的会话才会加载新版。确定更新吗？';
  }

  @override
  String get providerDiscard => '放弃更改';

  @override
  String get providerRemove => '删除配置';

  @override
  String get providerNewTitle => '新配置';

  @override
  String get providerModelsTitle => '模型';

  @override
  String providerModelsSummary(int enabled, int total) {
    return '已显示 $enabled/$total 个模型';
  }

  @override
  String get providerSync => '自动同步模型列表';

  @override
  String providerSyncedAt(String time) {
    return '上次获取：$time';
  }

  @override
  String get providerNeverSynced => '还没获取过模型列表';

  @override
  String get providerFilterModels => '筛选模型';

  @override
  String get providerEnableAll => '全部显示';

  @override
  String get providerDisableAll => '全部隐藏';

  @override
  String get providerShowModel => '在模型选择器中显示';

  @override
  String get providerHideModel => '在模型选择器中隐藏';

  @override
  String get providerAddModelHint => '手动添加模型 ID';

  @override
  String get providerAddModel => '添加';

  @override
  String get providerRemoveModel => '移除这个手动模型';

  @override
  String get providerManualBadge => '手动';

  @override
  String get providerCustomBadge => '自定义';

  @override
  String get providerReasoningBadge => '推理';

  @override
  String get providerImageBadge => '图片';

  @override
  String providerContextK(String count) {
    return '${count}K';
  }

  @override
  String providerContextM(String count) {
    return '${count}M';
  }

  @override
  String get providerNoModels => '还没有模型';

  @override
  String get providerNoModelMatches => '没有匹配的模型。';

  @override
  String get providerSaved => '已保存';

  @override
  String get providerDiscardTitle => '放弃未保存的修改？';

  @override
  String get providerDiscardBody => '这个配置还有没保存的修改，离开后会丢失。';

  @override
  String get providerErrorNoModels => '至少要保留一个在模型选择器中显示的模型。';
}
