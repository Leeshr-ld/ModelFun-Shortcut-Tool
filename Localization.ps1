function Get-UiLanguageOptions {
    return @(
        [pscustomobject]@{ Code = 'zh-CN'; DisplayName = '中文' }
        [pscustomobject]@{ Code = 'en-US'; DisplayName = 'English' }
    )
}

function Resolve-UiLanguage([string]$Language) {
    switch ($Language) {
        'en-US' { return 'en-US' }
        default { return 'zh-CN' }
    }
}

function Get-UiTextMap([string]$Language) {
    $languageCode = Resolve-UiLanguage $Language
    if ($languageCode -eq 'en-US') {
        return @{
            'app.name' = 'ModelFun Shortcut Tool'
            'main.title' = 'ModelFun Shortcut Tool'
            'language.label' = 'Language'
            'language.chinese' = 'Chinese'
            'language.english' = 'English'
            'language.tooltip' = 'Switch the interface language and save the choice'
            'main.summary' = "Author: shijye | Auto-detects four leveling and hole-patching panels`r`nGPL-3.0 open source; redistributed versions must keep the source and author credit."
            'button.detect' = 'Detect'
            'button.editShortcut' = 'Edit'
            'button.resetDefaults' = 'Reset'
            'button.loadConfig' = 'Reload'
            'button.openConfig' = 'Open'
            'button.configManager' = 'Config'
            'button.userGuide' = 'Guide'
            'button.enableHotkeys' = 'Enable'
            'button.about' = 'About'
            'button.exit' = 'Exit'
            'button.exportConfig' = 'Export Config...'
            'button.importConfig' = 'Import Config...'
            'button.restoreBackup' = 'Restore Latest Backup'
            'button.save' = 'Save'
            'button.cancel' = 'Cancel'
            'button.ok' = 'OK'
            'column.action' = 'Action / Button'
            'column.keyboard' = 'Keyboard'
            'column.mouse' = 'Mouse'
            'column.status' = 'Status'
            'editor.title' = 'Edit Shortcut'
            'editor.heading' = 'Edit shortcut for "{label}"'
            'editor.keyboardLabel' = 'Keyboard shortcut (click the box and press the new key combination)'
            'editor.clearKeyboard' = 'Clear Keyboard'
            'editor.mouseLabel' = 'Mouse Shortcut'
            'editor.noConflict' = 'No conflict found.'
            'mouse.none' = 'None'
            'mouse.side1' = 'Side 1'
            'mouse.side2' = 'Side 2'
            'about.title' = 'About ModelFun Shortcut Tool'
            'about.heading' = 'About ModelFun Shortcut Tool {version}'
            'about.currentVersion' = 'Current version: {version}'
            'about.author' = 'Author: {author}'
            'about.versionHistory' = 'Version History'
            'status.paused' = 'Hotkeys paused.'
            'status.waitingModelFun' = 'Waiting for the ModelFun window.'
            'status.standby' = 'Hotkeys ready: switch to ModelFun to activate.'
            'status.waitingPanel' = 'Waiting for Road Leveling, Surface Leveling, Specified Leveling or Hole Patching to open.'
            'status.backupOnly' = 'Backup hotkey enabled; open a leveling panel to enable panel buttons.'
            'status.backupRegistrationFailed' = 'Backup hotkey registration failed. Check for a shortcut conflict.'
            'status.hotkeyRegistrationFailed' = 'Shortcut registration failed: {binding}'
            'status.backupNoModelWindow' = 'The ModelFun window was not found.'
            'status.backupNotForeground' = 'The ModelFun window is not active; backup was ignored.'
            'status.backupDiagnostic' = 'Diagnostic mode: ready to run the backup workflow.'
            'status.backupDialogTimeout' = 'The Backup and Restore window did not appear.'
            'status.backupComplete' = 'Backup workflow completed: Select All was clicked, then Backup Now.'
            'status.clickNoModelWindow' = 'The ModelFun window was not found.'
            'status.clickNotForeground' = 'The ModelFun window is not active; the click was ignored.'
            'status.panelNotRecognized' = 'No supported panel is active. Open Road Leveling, Surface Leveling, Specified Leveling or Hole Patching.'
            'status.actionUnavailable' = 'Panel "{panel}" has no action named "{action}".'
            'status.panelPointFailed' = 'Button position detection failed. Reopen the panel and try again.'
            'status.diagnosticClick' = 'Diagnostic mode: ready to click "{label}" at ({x},{y}).'
            'status.clicked' = 'Clicked "{panel}": {label}'
            'status.detected' = 'Detected "{panel}". Hotkeys enabled.'
            'status.detectedInfo' = 'Detected "{panel}" with {count} available buttons.'
            'status.detectionFailed' = 'Detected "{panel}", but hotkey registration failed. Check for a shortcut conflict.'
            'status.dpiLimited' = 'DPI limited: {message}'
            'status.selectRow' = 'Select a button in the table first.'
            'status.configReadFailed' = 'Failed to read config: {message}'
            'status.defaultsRestored' = 'Default shortcuts restored.'
            'status.languageChanged' = 'Interface language changed to English.'
            'status.configRecovered' = 'The damaged configuration was recovered from an automatic backup.'
            'status.dpiLayoutFailed' = 'DPI layout update failed: {message}'
            'status.hint' = 'Refreshes automatically after panel changes; backup: {backup}; double-click a row to edit.'
            'status.runtimeError' = 'Runtime error: {message}'
            'notice.noPanel' = 'Backup hotkey available; open a panel to show its buttons.'
            'notice.noConflict' = 'No internal duplicate or registered ModelFun conflicts; double-click a row to edit.'
            'notice.conflicts' = 'Shortcut notices: {count}. {first} Double-click a row to edit.'
            'row.normal' = 'OK'
            'row.modelConflict' = 'ModelFun conflict'
            'row.duplicate' = 'Duplicate'
            'conflict.internal' = 'Conflicts with assistant action "{action}".'
            'conflict.model' = 'Conflicts with the original ModelFun shortcut "{shortcut}" for {action}.'
            'conflict.backupPanel' = 'Conflicts with action "{action}" on the "{panel}" panel.'
            'format.unbound' = 'Unbound'
            'dialog.modelWindowMissingBody' = 'Open ModelFun and display the panel you want to use before starting calibration.'
            'dialog.modelWindowMissingTitle' = 'ModelFun Window Not Found'
            'dialog.panelMissingBody' = 'ModelFun is running, but no supported leveling or hole-patching panel was detected. Open one of those panels first.'
            'dialog.panelMissingTitle' = 'Panel Not Recognized'
            'config.exportTitle' = 'Export Shortcut Configuration'
            'config.importTitle' = 'Import Shortcut Configuration'
            'config.filter' = 'Shortcut Config (*.json)|*.json|All Files (*.*)|*.*'
            'config.exportSuccess' = 'Configuration exported.'
            'config.exportFailed' = 'Export failed: {message}'
            'config.importSuccess' = 'Configuration imported. Shortcuts and language were reloaded.'
            'config.importFailed' = 'Import failed: {message}'
            'config.restoreConfirm' = 'Restore the latest automatic configuration backup? The current configuration will be backed up first.'
            'config.restoreTitle' = 'Restore Configuration Backup'
            'config.restoreSuccess' = 'Configuration backup restored.'
            'config.restoreFailed' = 'Restore failed: {message}'
            'config.noBackup' = 'No automatic configuration backup is available.'
            'guide.notFoundTitle' = 'User Guide Not Found'
            'guide.notFoundBody' = '用户指南.html is missing. Extract the complete portable ZIP and try again.'
            'guide.openFailed' = 'The user guide could not be opened: {message}'
            'message.bindingRequired' = 'Bind at least one keyboard or mouse shortcut.'
            'message.cannotSave' = 'Cannot Save'
            'message.shortcutDuplicate' = 'Duplicate Shortcut'
            'message.modelConflictTitle' = 'ModelFun Shortcut Conflict'
            'message.modelConflictBody' = "{message}`r`n`r`nThe assistant blocks this combination while a panel is open. It may still trigger ModelFun when no panel is open. Save anyway?"
            'message.shortcutUnavailable' = 'This key combination cannot be registered. Windows or another application may already use it.'
            'message.unavailableTitle' = 'Shortcut Unavailable'
            'message.resetConfirm' = 'Reset all keyboard and mouse shortcuts to their original defaults?'
            'message.resetTitle' = 'Reset Default Shortcuts'
            'message.initializationFailed' = 'Initialization Failed'
            'message.initializationIncomplete' = 'The main window did not complete initialization.'
            'message.adminRequired' = 'ModelFun is running as administrator. Close this window, start RoadLevelHotkeys.exe, and choose Yes in the UAC prompt.'
            'message.adminRequiredTitle' = 'Administrator Permission Required'
            'message.calibrationFailedTitle' = 'Calibration Failed'
            'message.calibrationOrder' = 'The two calibration points are in the wrong order. Start again and select the Operation icon first, then Cancel.'
            'message.calibrationRatio' = 'The point ratio is abnormal (X scale {x}, Y scale {y}). Select the centers of Operation and Cancel.'
            'status.calibrationWaiting' = 'Calibration: waiting for the mouse position.'
            'status.calibrationComplete' = 'Calibration complete. Shortcuts are ready.'
            'status.calibrationCancelled' = 'Calibration cancelled.'
            'status.calibrationOutside' = 'The mouse is outside ModelFun. Move it to the center of the panel button and press F7.'
            'status.calibrationFirstPoint' = 'First point recorded. Waiting for the Cancel button position.'
            'calibration.step1' = 'Step 1: move the mouse to the center of the Operation icon, then press F7.'
            'calibration.step2' = 'Step 2: move the mouse to the center of the Cancel button, then press F7.'
            'calibration.hint' = 'Press Esc to cancel. Calibration only reads positions and does not click buttons.'
            'button.cancelCalibration' = 'Cancel Calibration'
        }
    }

    return @{
        'app.name' = '模方面板快捷键助手'
        'main.title' = '模方面板快捷键助手'
        'language.label' = '语言'
        'language.chinese' = '中文'
        'language.english' = 'English'
        'language.tooltip' = '切换界面语言并保存选择'
        'main.summary' = "作者：shijye｜自动识别四类置平/补洞面板`r`nGPL-3.0 完全开源；允许修改与再分发，衍生发行须保留源码和作者署名。"
        'button.detect' = '立即识别'
        'button.editShortcut' = '修改快捷键'
        'button.resetDefaults' = '恢复默认'
        'button.loadConfig' = '载入配置'
        'button.openConfig' = '打开配置'
        'button.configManager' = '配置管理'
        'button.userGuide' = '使用指南'
        'button.enableHotkeys' = '启用快捷键'
        'button.about' = '关于'
        'button.exit' = '退出'
        'button.exportConfig' = '导出配置…'
        'button.importConfig' = '导入配置…'
        'button.restoreBackup' = '恢复最近备份'
        'button.save' = '保存'
        'button.cancel' = '取消'
        'button.ok' = '确定'
        'column.action' = '动作 / 面板按钮'
        'column.keyboard' = '键盘快捷键'
        'column.mouse' = '鼠标快捷键'
        'column.status' = '提示'
        'editor.title' = '修改快捷键'
        'editor.heading' = '修改「{label}」的快捷键'
        'editor.keyboardLabel' = '键盘快捷键（点击框内，然后直接按新的组合键）'
        'editor.clearKeyboard' = '清除键盘'
        'editor.mouseLabel' = '鼠标快捷键'
        'editor.noConflict' = '未发现冲突。'
        'mouse.none' = '无'
        'mouse.side1' = '鼠标侧键1'
        'mouse.side2' = '鼠标侧键2'
        'about.title' = '关于 模方面板快捷键助手'
        'about.heading' = '关于 模方面板快捷键助手　{version}'
        'about.currentVersion' = '当前版本：{version}'
        'about.author' = '作者：{author}'
        'about.versionHistory' = '版本历史'
        'status.paused' = '快捷键已暂停。'
        'status.waitingModelFun' = '等待模方ModelFun窗口。'
        'status.standby' = '快捷键待命：切换到模方ModelFun后生效。'
        'status.waitingPanel' = '等待打开：道路置平、表面置平、指定置平或补洞。'
        'status.backupOnly' = '备份快捷键已启用；打开置平面板后会启用面板按钮。'
        'status.backupRegistrationFailed' = '备份快捷键注册失败，请检查按键冲突。'
        'status.hotkeyRegistrationFailed' = '快捷键注册失败：{binding}'
        'status.backupNoModelWindow' = '未找到模方ModelFun窗口。'
        'status.backupNotForeground' = '模方窗口不在前台，已忽略备份操作。'
        'status.backupDiagnostic' = '诊断模式：准备执行备份流程。'
        'status.backupDialogTimeout' = '没有等到“备份和恢复”窗口。'
        'status.backupComplete' = '备份流程已执行：已全选并点击立即备份。'
        'status.clickNoModelWindow' = '未找到模方ModelFun窗口。'
        'status.clickNotForeground' = '模方窗口不在前台，已忽略这次点击。'
        'status.panelNotRecognized' = '未识别到当前面板，请打开道路置平、表面置平、指定置平或补洞。'
        'status.actionUnavailable' = '当前「{panel}」面板没有「{action}」操作。'
        'status.panelPointFailed' = '按钮位置识别失败，请重新打开面板后再试。'
        'status.diagnosticClick' = '诊断模式：准备点击「{label}」({x},{y})'
        'status.clicked' = '已点击「{panel}」：{label}'
        'status.detected' = '已自动识别「{panel}」，快捷键已启用。'
        'status.detectedInfo' = '已自动识别「{panel}」，共 {count} 个可用按钮。'
        'status.detectionFailed' = '已识别「{panel}」，但快捷键注册失败，请检查按键冲突。'
        'status.dpiLimited' = 'DPI受限：{message}'
        'status.selectRow' = '请先在表中选择一个按钮。'
        'status.configReadFailed' = '配置读取失败：{message}'
        'status.defaultsRestored' = '已恢复默认快捷键。'
        'status.languageChanged' = '界面语言已切换为中文。'
        'status.configRecovered' = '损坏的配置文件已从自动备份恢复。'
        'status.dpiLayoutFailed' = 'DPI切换后布局失败：{message}'
        'status.hint' = '面板切换后自动刷新；通用备份：{backup}；双击表格行可修改快捷键。'
        'status.runtimeError' = '运行错误：{message}'
        'notice.noPanel' = '通用备份快捷键可用；打开面板后会显示该面板按钮。'
        'notice.noConflict' = '快捷键无内部重复或已登记的原版冲突；双击行可修改。'
        'notice.conflicts' = '检测到 {count} 个快捷键提示：{first} 双击行可修改。'
        'row.normal' = '正常'
        'row.modelConflict' = '原版冲突'
        'row.duplicate' = '重复绑定'
        'conflict.internal' = '与助手动作「{action}」的快捷键重复。'
        'conflict.model' = '与模方原版快捷键「{shortcut}」冲突：{action}。'
        'conflict.backupPanel' = '与「{panel}」面板动作「{action}」的快捷键重复。'
        'format.unbound' = '未绑定'
        'dialog.modelWindowMissingBody' = '请先打开并显示模方ModelFun窗口，再开始校准。'
        'dialog.modelWindowMissingTitle' = '未找到模方窗口'
        'dialog.panelMissingBody' = '模方已运行，但没有识别到支持的置平或补洞面板。请先打开其中一个面板。'
        'dialog.panelMissingTitle' = '未识别到面板'
        'config.exportTitle' = '导出快捷键配置'
        'config.importTitle' = '导入快捷键配置'
        'config.filter' = '快捷键配置 (*.json)|*.json|所有文件 (*.*)|*.*'
        'config.exportSuccess' = '配置已导出。'
        'config.exportFailed' = '导出失败：{message}'
        'config.importSuccess' = '配置已导入，快捷键和语言已重新载入。'
        'config.importFailed' = '导入失败：{message}'
        'config.restoreConfirm' = '恢复最近一次自动配置备份吗？当前配置会先自动备份。'
        'config.restoreTitle' = '恢复配置备份'
        'config.restoreSuccess' = '配置备份已恢复。'
        'config.restoreFailed' = '恢复失败：{message}'
        'config.noBackup' = '没有可用的自动配置备份。'
        'guide.notFoundTitle' = '未找到使用指南'
        'guide.notFoundBody' = '缺少“用户指南.html”。请重新解压完整便携包后再试。'
        'guide.openFailed' = '无法打开使用指南：{message}'
        'message.bindingRequired' = '键盘和鼠标至少需要绑定一个。'
        'message.cannotSave' = '无法保存'
        'message.shortcutDuplicate' = '快捷键重复'
        'message.modelConflictTitle' = '模方原版快捷键冲突'
        'message.modelConflictBody' = "{message}`r`n`r`n面板打开时助手会拦截此组合；面板未打开时仍可能触发模方原功能。是否继续保存？"
        'message.shortcutUnavailable' = '这个键盘组合无法注册，可能已被Windows或其他软件占用。'
        'message.unavailableTitle' = '快捷键不可用'
        'message.resetConfirm' = '确定把全部键盘和鼠标快捷键恢复为原始设置吗？'
        'message.resetTitle' = '恢复默认快捷键'
        'message.initializationFailed' = '初始化失败'
        'message.initializationIncomplete' = '主窗口未完成初始化'
        'message.adminRequired' = '模方正以管理员权限运行。请关闭本窗口，双击 RoadLevelHotkeys.exe 并在UAC提示中点击“是”。'
        'message.adminRequiredTitle' = '需要管理员权限'
        'message.calibrationFailedTitle' = '校准失败'
        'message.calibrationOrder' = '两个校准点的位置关系不正确。请重新开始，先点「操作图标」，再点「取消」。'
        'message.calibrationRatio' = '两个点的比例异常（X倍率 {x}，Y倍率 {y}）。请确认选的是「操作图标」和「取消」的中心。'
        'status.calibrationWaiting' = '校准中：等待鼠标位置。'
        'status.calibrationComplete' = '校准完成，可以开始使用快捷键。'
        'status.calibrationCancelled' = '已取消校准。'
        'status.calibrationOutside' = '鼠标不在模方窗口内，请移到面板按钮中心后再按 F7。'
        'status.calibrationFirstPoint' = '已记录第1个点，等待「取消」按钮位置。'
        'calibration.step1' = '第1步：把鼠标移到「操作图标」的正中心，然后按 F7。'
        'calibration.step2' = '第2步：把鼠标移到「取消」文字的正中心，然后按 F7。'
        'calibration.hint' = '按 Esc 取消。校准只读取位置，不会点击按钮。'
        'button.cancelCalibration' = '取消校准'
    }
}

function Get-UiText {
    param(
        [string]$Key,
        [string]$Language = 'zh-CN',
        [hashtable]$Tokens = @{}
    )

    $map = Get-UiTextMap $Language
    $text = if ($map.ContainsKey($Key)) {
        [string]$map[$Key]
    }
    else {
        $fallback = Get-UiTextMap 'zh-CN'
        if ($fallback.ContainsKey($Key)) { [string]$fallback[$Key] } else { $Key }
    }

    foreach ($token in $Tokens.Keys) {
        $text = $text.Replace('{' + $token + '}', [string]$Tokens[$token])
    }
    return $text
}

function Get-LocalizedPanelTitle {
    param(
        [string]$PanelTitle,
        [string]$Language = 'zh-CN'
    )

    if ((Resolve-UiLanguage $Language) -ne 'en-US') {
        return $PanelTitle
    }
    switch ($PanelTitle) {
        '道路置平' { return 'Road Leveling' }
        '表面置平' { return 'Surface Leveling' }
        '指定置平' { return 'Specified Leveling' }
        '补洞' { return 'Hole Patching' }
        default { return $PanelTitle }
    }
}

function Get-LocalizedActionLabel {
    param(
        [string]$Label,
        [string]$Language = 'zh-CN'
    )

    if ((Resolve-UiLanguage $Language) -ne 'en-US') {
        return $Label
    }
    $englishLabels = @{
        '备份当前工程瓦片' = 'Backup Project Tiles'
        '操作图标' = 'Operation'
        '应用/勾选' = 'Apply / Check'
        '曲线/路径' = 'Curve / Path'
        '更多选项' = 'More Options'
        '隐藏平面' = 'Hide Plane'
        '优化切割线' = 'Optimize Cutting Line'
        '撤销' = 'Undo'
        '重做' = 'Redo'
        '确认' = 'Confirm'
        '确定' = 'OK'
        '取消' = 'Cancel'
        '填充方式1' = 'Fill Method 1'
        '填充方式2' = 'Fill Method 2'
        '填充方式3' = 'Fill Method 3'
        '填充方式4' = 'Fill Method 4'
        '编辑三角形1' = 'Edit Triangle 1'
        '编辑三角形2' = 'Edit Triangle 2'
        '位置按钮1' = 'Position Button 1'
        '位置按钮2' = 'Position Button 2'
        '位置按钮3' = 'Position Button 3'
        '位置按钮4' = 'Position Button 4'
        '位置按钮5' = 'Position Button 5'
        '位置按钮6' = 'Position Button 6'
        '位置按钮7' = 'Position Button 7'
        '位置按钮8' = 'Position Button 8'
        '选项切换1' = 'Option Toggle 1'
        '选项切换2' = 'Option Toggle 2'
    }
    if ($englishLabels.ContainsKey($Label)) {
        return [string]$englishLabels[$Label]
    }
    return $Label
}

function Get-LocalizedActionCodeLabel {
    param(
        [string]$ActionName,
        [string]$Language = 'zh-CN'
    )

    $labels = @{
        backup = '备份当前工程瓦片'
        slot1 = '位置按钮1'
        slot2 = '位置按钮2'
        slot3 = '位置按钮3'
        slot4 = '位置按钮4'
        slot5 = '位置按钮5'
        slot6 = '位置按钮6'
        slot7 = '位置按钮7'
        slot8 = '位置按钮8'
        toggle1 = '选项切换1'
        toggle2 = '选项切换2'
        undo = '撤销'
        redo = '重做'
        confirm = '确认'
        cancel = '取消'
    }
    $label = if ($labels.ContainsKey($ActionName)) { [string]$labels[$ActionName] } else { $ActionName }
    return Get-LocalizedActionLabel -Label $label -Language $Language
}
