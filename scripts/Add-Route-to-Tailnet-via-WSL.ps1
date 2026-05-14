Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RouteNetwork = '100.64.0.0'
$RouteMask    = '255.192.0.0'
$RoutePrefix  = '100.64.0.0/10'
$LxssRoot     = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss'

function Write-Log {
    param(
        [Parameter(Mandatory)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host "[$timestamp] [$Level] $Message"
}

function Fail {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Log -Level ERROR -Message $Message
    exit 1
}

function Test-IsAdministrator {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Convert-ToLf {
    param(
        [Parameter(Mandatory)]
        [string]$Text
    )

    return (($Text -replace "`r`n", "`n") -replace "`r", "`n").Trim() + "`n"
}

function Get-FirstTrimmedLine {
    param(
        [AllowNull()]
        [string]$Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ''
    }

    $line = $Text -split "\r?\n" |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Select-Object -First 1

    if ($null -eq $line) {
        return ''
    }

    return $line.Trim()
}

function Get-UbuntuWslDistroName {
    param(
        [Parameter(Mandatory)]
        [string]$RegistryRoot
    )

    if (-not (Test-Path -LiteralPath $RegistryRoot)) {
        throw "WSL registry root not found: $RegistryRoot"
    }

    Write-Log "Querying WSL distros from registry: $RegistryRoot"

    $distros = Get-ChildItem -LiteralPath $RegistryRoot -ErrorAction Stop |
        ForEach-Object {
            try {
                $props = Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction Stop

                if ($null -ne $props.DistributionName -and -not [string]::IsNullOrWhiteSpace([string]$props.DistributionName)) {
                    [pscustomobject]@{
                        DistributionName = [string]$props.DistributionName
                        State            = $props.State
                        Version          = $props.Version
                        BasePath         = $props.BasePath
                        RegistryKey      = $_.PSChildName
                    }
                }
            }
            catch {
                Write-Log "Skipping unreadable registry key: $($_.PSChildName)" 'WARN'
            }
        } |
        Where-Object { $_ -and $_.DistributionName -like '*Ubuntu*' } |
        Sort-Object DistributionName

    if (-not $distros) {
        return $null
    }

    Write-Log ("Ubuntu-like distro candidates found: " + (($distros | Select-Object -ExpandProperty DistributionName) -join ', '))

    $selected = $distros | Select-Object -First 1
    Write-Log "Selected distro from registry: $($selected.DistributionName)"

    return $selected.DistributionName
}

function Invoke-WslSh {
    param(
        [Parameter(Mandatory)]
        [string]$Distro,

        [Parameter(Mandatory)]
        [string]$Script
    )

    $normalizedScript = Convert-ToLf -Text $Script

    $stdinFile  = [System.IO.Path]::GetTempFileName()
    $stdoutFile = [System.IO.Path]::GetTempFileName()
    $stderrFile = [System.IO.Path]::GetTempFileName()

    try {
        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($stdinFile, $normalizedScript, $utf8NoBom)

        $proc = Start-Process `
            -FilePath 'wsl.exe' `
            -ArgumentList @('-d', $Distro, '--', 'sh') `
            -Wait `
            -PassThru `
            -NoNewWindow `
            -RedirectStandardInput $stdinFile `
            -RedirectStandardOutput $stdoutFile `
            -RedirectStandardError $stderrFile

        $stdout = ''
        $stderr = ''

        if (Test-Path -LiteralPath $stdoutFile) {
            $stdout = Get-Content -LiteralPath $stdoutFile -Raw -ErrorAction SilentlyContinue
        }

        if (Test-Path -LiteralPath $stderrFile) {
            $stderr = Get-Content -LiteralPath $stderrFile -Raw -ErrorAction SilentlyContinue
        }

        [pscustomobject]@{
            ExitCode = $proc.ExitCode
            StdOut   = [string]$stdout
            StdErr   = [string]$stderr
            Script   = $normalizedScript
        }
    }
    finally {
        Remove-Item -LiteralPath $stdinFile, $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-RouteReset {
    param(
        [Parameter(Mandatory)]
        [string]$Network,

        [Parameter(Mandatory)]
        [string]$Mask,

        [Parameter(Mandatory)]
        [string]$Gateway,

        [switch]$DeleteExisting
    )

    $deleteExistingLiteral = if ($DeleteExisting) { '$true' } else { '$false' }

    $routeScript = @"
`$ErrorActionPreference = 'Stop'
`$deleteExisting = $deleteExistingLiteral

function Invoke-RouteExe {
    param(
        [Parameter(Mandatory)]
        [string[]]`$Arguments
    )

    `$previousErrorActionPreference = `$ErrorActionPreference
    `$ErrorActionPreference = 'Continue'

    try {
        `$output = @(& route.exe @Arguments 2>&1)
        `$exitCode = `$LASTEXITCODE
    }
    finally {
        `$ErrorActionPreference = `$previousErrorActionPreference
    }

    [pscustomobject]@{
        ExitCode = `$exitCode
        Output   = ((`$output | ForEach-Object { [string]`$_ }) -join "`n").Trim()
    }
}

if (`$deleteExisting) {
    `$delete = Invoke-RouteExe -Arguments @('delete', '$Network', 'mask', '$Mask')
    if (`$delete.ExitCode -ne 0 -and `$delete.Output -notmatch 'Element not found') {
        `$deleteMessage = if ([string]::IsNullOrWhiteSpace(`$delete.Output)) { "exit code `$(`$delete.ExitCode)" } else { "`$(`$delete.Output) (exit code `$(`$delete.ExitCode))" }
        throw "route.exe delete failed: `$deleteMessage"
    }
}

`$add = Invoke-RouteExe -Arguments @('add', '$Network', 'mask', '$Mask', '$Gateway')
if (`$add.ExitCode -ne 0) {
    `$addMessage = if ([string]::IsNullOrWhiteSpace(`$add.Output)) { "exit code `$(`$add.ExitCode)" } else { "`$(`$add.Output) (exit code `$(`$add.ExitCode))" }
    throw "route.exe add failed: `$addMessage"
}
"@

    if (Test-IsAdministrator) {
        Write-Log "Current PowerShell session is already elevated; updating route directly."
        & ([scriptblock]::Create($routeScript))
        return
    }

    Write-Log "Elevation is required to modify the Windows route table."
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($routeScript))

    $proc = Start-Process `
        -FilePath 'powershell.exe' `
        -Verb RunAs `
        -ArgumentList '-NoProfile', '-EncodedCommand', $encoded `
        -Wait `
        -PassThru

    if ($proc.ExitCode -ne 0) {
        throw "Elevated route update failed with exit code $($proc.ExitCode)."
    }
}

Write-Log "Looking for a WSL distribution whose name contains 'Ubuntu'..."
$distro = Get-UbuntuWslDistroName -RegistryRoot $LxssRoot

if (-not $distro) {
    Fail "No WSL distribution with a name containing 'Ubuntu' was found in the registry."
}

Write-Log "Using WSL distribution: $distro"

Write-Log "Checking Tailscale inside WSL..."
$tailscaleResult = Invoke-WslSh -Distro $distro -Script @'
if ! command -v tailscale >/dev/null 2>&1; then
    exit 20
fi

if ! tailscale status >/dev/null 2>&1; then
    exit 21
fi

ts_ip=$(tailscale ip -4 2>/dev/null | head -n1)
[ -n "$ts_ip" ] || exit 22

echo "$ts_ip"
'@

$tailscaleExit = $tailscaleResult.ExitCode
$tailscaleIp   = Get-FirstTrimmedLine -Text $tailscaleResult.StdOut

switch ($tailscaleExit) {
    0 {
        if ([string]::IsNullOrWhiteSpace($tailscaleIp)) {
            if (-not [string]::IsNullOrWhiteSpace($tailscaleResult.StdErr)) {
                Write-Log "WSL stderr during Tailscale check: $($tailscaleResult.StdErr.Trim())" 'WARN'
            }

            Fail "Tailscale check returned success, but no IPv4 address was captured from stdout."
        }

        Write-Log "Tailscale is running in WSL and has IPv4 address $tailscaleIp"
    }
    20 {
        Fail "The 'tailscale' command is not installed in WSL distro '$distro'."
    }
    21 {
        if (-not [string]::IsNullOrWhiteSpace($tailscaleResult.StdErr)) {
            Write-Log "WSL stderr during Tailscale check: $($tailscaleResult.StdErr.Trim())" 'WARN'
        }

        Fail "Tailscale is not running or is not reachable in WSL distro '$distro'."
    }
    22 {
        Fail "Tailscale is running in WSL distro '$distro', but it does not currently have an IPv4 address."
    }
    default {
        if (-not [string]::IsNullOrWhiteSpace($tailscaleResult.StdErr)) {
            Write-Log "WSL stderr during Tailscale check: $($tailscaleResult.StdErr.Trim())" 'WARN'
        }

        Fail "Unexpected error while checking Tailscale in WSL (exit code $tailscaleExit)."
    }
}

Write-Log "Resolving the primary WSL IPv4 address..."
$wslIpResult = Invoke-WslSh -Distro $distro -Script @'
iface=$(ip -4 route show default 2>/dev/null | awk '{print $5; exit}')
[ -n "$iface" ] || exit 30

ip -4 -o addr show dev "$iface" 2>/dev/null | awk '{split($4,a,"/"); print a[1]; exit}'
'@

$wslIp = Get-FirstTrimmedLine -Text $wslIpResult.StdOut

if ($wslIpResult.ExitCode -ne 0 -or [string]::IsNullOrWhiteSpace($wslIp)) {
    if (-not [string]::IsNullOrWhiteSpace($wslIpResult.StdErr)) {
        Write-Log "WSL stderr during WSL IP lookup: $($wslIpResult.StdErr.Trim())" 'WARN'
    }

    Fail "Could not determine the primary WSL IPv4 address."
}

Write-Log "Primary WSL IPv4 address resolved to $wslIp"

Write-Log "Inspecting current Windows route state for $RoutePrefix..."
$exactRoutes = @(Get-NetRoute -DestinationPrefix $RoutePrefix -ErrorAction SilentlyContinue)
$nextHops    = @($exactRoutes | Select-Object -ExpandProperty NextHop -Unique)

if ($exactRoutes.Count -gt 0 -and $nextHops.Count -eq 1 -and $nextHops[0] -eq $wslIp) {
    Write-Log "Route is already correct. No change is needed."
    exit 0
}

if ($exactRoutes.Count -eq 0) {
    Write-Log "Route is missing and will be added."
}
else {
    $existingNextHops = $nextHops -join ', '
    Write-Log "Route exists but is not in the desired state. Current next hop(s): $existingNextHops" 'WARN'
    Write-Log "The route will be reset to use gateway $wslIp"
}

try {
    Invoke-RouteReset -Network $RouteNetwork -Mask $RouteMask -Gateway $wslIp -DeleteExisting:($exactRoutes.Count -gt 0)
    Write-Log "Route successfully updated: $RouteNetwork mask $RouteMask -> $wslIp"
}
catch {
    Fail $_.Exception.Message
}
