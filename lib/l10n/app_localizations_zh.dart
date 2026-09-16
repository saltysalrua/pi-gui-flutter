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
  String get worktreeBase => '起始分支';

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
  String get settingsNoResults => '没有找到匹配的设置';

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
  String get appearanceGlassSidebarHint => '标题栏、左侧导航和拖拽区一起变化。';

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
}
