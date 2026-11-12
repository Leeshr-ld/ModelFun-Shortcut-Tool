function ConvertTo-ShortcutKeyName([string]$KeyName) {
    if ([string]::IsNullOrWhiteSpace($KeyName)) {
        return ''
    }
    if ($KeyName -ieq 'Backspace') {
        return 'Back'
    }
    if ($KeyName -ieq 'Esc') {
        return 'Escape'
    }
    if ($KeyName -match '^[0-9]$') {
        return 'D' + $KeyName
    }
    return $KeyName
}

function Get-ShortcutSignature($Binding) {
    if ($null -eq $Binding) {
        return ''
    }

    $mouseButton = [string]$Binding.mouseButton
    if ([string]::IsNullOrWhiteSpace([string]$Binding.key) -and -not [string]::IsNullOrWhiteSpace($mouseButton)) {
        return 'Mouse:' + $mouseButton
    }

    $parts = New-Object System.Collections.Generic.List[string]
    if ($Binding.ctrl -eq $true) { $parts.Add('Ctrl') }
    if ($Binding.alt -eq $true) { $parts.Add('Alt') }
    if ($Binding.shift -eq $true) { $parts.Add('Shift') }
    $parts.Add((ConvertTo-ShortcutKeyName ([string]$Binding.key)))
    return ($parts -join '+')
}

function Get-ShortcutDisplay($Binding) {
    if ($null -eq $Binding) {
        return '未绑定'
    }
    if ([string]::IsNullOrWhiteSpace([string]$Binding.key) -and -not [string]::IsNullOrWhiteSpace([string]$Binding.mouseButton)) {
        switch ([string]$Binding.mouseButton) {
            'XButton1' { return '鼠标侧键1' }
            'XButton2' { return '鼠标侧键2' }
            default { return [string]$Binding.mouseButton }
        }
    }

    $parts = New-Object System.Collections.Generic.List[string]
    if ($Binding.ctrl -eq $true) { $parts.Add('Ctrl') }
    if ($Binding.alt -eq $true) { $parts.Add('Alt') }
    if ($Binding.shift -eq $true) { $parts.Add('Shift') }
    $keyName = [string]$Binding.key
    if ($keyName -match '^D[0-9]$') {
        $keyName = $keyName.Substring(1)
    }
    elseif ($keyName -ieq 'Back') {
        $keyName = 'Backspace'
    }
    $parts.Add($keyName)
    return ($parts -join '+')
}

function Test-ShortcutBindingOverlap($Candidate, $Existing) {
    if ($null -eq $Candidate -or $null -eq $Existing) {
        return $false
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$Candidate.key) -and
        -not [string]::IsNullOrWhiteSpace([string]$Existing.key)) {
        $candidateKeyboard = $Candidate.PSObject.Copy()
        $candidateKeyboard.mouseButton = ''
        $existingKeyboard = $Existing.PSObject.Copy()
        $existingKeyboard.mouseButton = ''
        if ((Get-ShortcutSignature $candidateKeyboard) -eq (Get-ShortcutSignature $existingKeyboard)) {
            return $true
        }
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$Candidate.mouseButton) -and
        -not [string]::IsNullOrWhiteSpace([string]$Existing.mouseButton) -and
        [string]$Candidate.mouseButton -eq [string]$Existing.mouseButton) {
        return $true
    }

    return $false
}

function Find-ShortcutConflict {
    param(
        [string]$ActionName,
        $Candidate,
        $Bindings,
        $ModelConflicts
    )

    $signature = Get-ShortcutSignature $Candidate
    if ([string]::IsNullOrWhiteSpace($signature)) {
        return $null
    }

    if ($null -ne $Bindings) {
        foreach ($property in $Bindings.PSObject.Properties) {
            if ($property.Name -eq $ActionName) {
                continue
            }
            if (Test-ShortcutBindingOverlap -Candidate $Candidate -Existing $property.Value) {
                return [pscustomobject]@{
                    Kind = 'Internal'
                    ActionName = [string]$property.Name
                    Shortcut = $signature
                    Message = "与助手动作「$($property.Name)」的快捷键重复。"
                }
            }
        }
    }

    foreach ($conflict in @($ModelConflicts)) {
        if ($null -ne $conflict -and [string]$conflict.signature -eq $signature) {
            $display = [string]$conflict.display
            if ([string]::IsNullOrWhiteSpace($display)) {
                $display = $signature
            }
            return [pscustomobject]@{
                Kind = 'Model'
                ActionName = [string]$conflict.action
                Shortcut = $signature
                Message = "与模方原版快捷键「$display」冲突：$($conflict.action)。"
            }
        }
    }

    return $null
}

function Get-BindingConflictList {
    param(
        [string]$ActionName,
        $Binding,
        $Bindings,
        $ModelConflicts
    )

    $conflicts = New-Object System.Collections.Generic.List[object]
    if (-not [string]::IsNullOrWhiteSpace([string]$Binding.key)) {
        $keyboardCandidate = $Binding.PSObject.Copy()
        $keyboardCandidate.mouseButton = ''
        $conflict = Find-ShortcutConflict -ActionName $ActionName -Candidate $keyboardCandidate -Bindings $Bindings -ModelConflicts $ModelConflicts
        if ($null -ne $conflict) {
            $conflicts.Add($conflict)
        }
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$Binding.mouseButton)) {
        $mouseCandidate = $Binding.PSObject.Copy()
        $mouseCandidate.key = ''
        $mouseCandidate.ctrl = $false
        $mouseCandidate.alt = $false
        $mouseCandidate.shift = $false
        $conflict = Find-ShortcutConflict -ActionName $ActionName -Candidate $mouseCandidate -Bindings $Bindings -ModelConflicts @()
        if ($null -ne $conflict) {
            $conflicts.Add($conflict)
        }
    }

    return $conflicts.ToArray()
}

function Get-DefaultBindings {
    return [pscustomobject]@{
        backup = [pscustomobject]@{ displayName = '备份当前工程瓦片'; key = 'B'; ctrl = $true; alt = $true; shift = $false; mouseButton = '' }
        slot1 = [pscustomobject]@{ displayName = '位置按钮1'; key = '1'; ctrl = $true; alt = $true; shift = $false; mouseButton = '' }
        slot2 = [pscustomobject]@{ displayName = '位置按钮2'; key = '2'; ctrl = $true; alt = $true; shift = $false; mouseButton = '' }
        slot3 = [pscustomobject]@{ displayName = '位置按钮3'; key = '3'; ctrl = $true; alt = $true; shift = $false; mouseButton = '' }
        slot4 = [pscustomobject]@{ displayName = '位置按钮4'; key = '4'; ctrl = $true; alt = $true; shift = $false; mouseButton = '' }
        slot5 = [pscustomobject]@{ displayName = '位置按钮5'; key = '5'; ctrl = $true; alt = $true; shift = $false; mouseButton = '' }
        slot6 = [pscustomobject]@{ displayName = '位置按钮6'; key = '6'; ctrl = $true; alt = $true; shift = $false; mouseButton = '' }
        slot7 = [pscustomobject]@{ displayName = '位置按钮7'; key = '7'; ctrl = $true; alt = $true; shift = $false; mouseButton = '' }
        slot8 = [pscustomobject]@{ displayName = '位置按钮8'; key = '8'; ctrl = $true; alt = $true; shift = $false; mouseButton = '' }
        toggle1 = [pscustomobject]@{ displayName = '选项切换1'; key = 'H'; ctrl = $true; alt = $true; shift = $false; mouseButton = '' }
        toggle2 = [pscustomobject]@{ displayName = '选项切换2'; key = 'O'; ctrl = $true; alt = $true; shift = $false; mouseButton = '' }
        undo = [pscustomobject]@{ displayName = '撤销'; key = 'Z'; ctrl = $true; alt = $true; shift = $false; mouseButton = 'XButton1' }
        redo = [pscustomobject]@{ displayName = '重做'; key = 'R'; ctrl = $true; alt = $true; shift = $false; mouseButton = 'XButton2' }
        confirm = [pscustomobject]@{ displayName = '确认'; key = 'Enter'; ctrl = $true; alt = $true; shift = $false; mouseButton = '' }
        cancel = [pscustomobject]@{ displayName = '取消'; key = 'X'; ctrl = $true; alt = $true; shift = $false; mouseButton = '' }
    }
}

function Reset-ShortcutBindings($Config) {
    $result = $Config.PSObject.Copy()
    $result.bindings = Get-DefaultBindings
    return $result
}
