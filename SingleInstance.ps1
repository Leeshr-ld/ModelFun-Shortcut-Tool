function New-SingleInstanceGuard([string]$Name) {
    if ([string]::IsNullOrWhiteSpace($Name)) {
        throw '单实例名称不能为空。'
    }
    $createdNew = $false
    $mutex = New-Object System.Threading.Mutex($true, $Name, [ref]$createdNew)
    return [pscustomobject]@{
        Name = $Name
        Created = [bool]$createdNew
        Mutex = $mutex
    }
}

function Close-SingleInstanceGuard($Guard) {
    if ($null -eq $Guard -or $null -eq $Guard.Mutex) {
        return
    }
    if ($Guard.Created) {
        try {
            $Guard.Mutex.ReleaseMutex()
        }
        catch {
        }
    }
    $Guard.Mutex.Dispose()
}
