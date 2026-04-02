[CmdletBinding()]
param(
    [string]$Remote = "origin",
    [string[]]$ProtectedBranches = @("main", "master", "develop", "dev"),
    [switch]$DryRun,
    [switch]$NoFetch
)

$ErrorActionPreference = "Stop"

function Invoke-Git {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $stderrFile = [System.IO.Path]::GetTempFileName()

    try {
        $output = & git @Arguments 2> $stderrFile
        $stderr = Get-Content -Path $stderrFile -ErrorAction SilentlyContinue
    }
    finally {
        Remove-Item -Path $stderrFile -Force -ErrorAction SilentlyContinue
    }

    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        $joinedArgs = $Arguments -join " "
        $details = (@($output) + @($stderr) | Out-String).Trim()
        throw "git $joinedArgs failed. $details"
    }

    return @($output)
}

if (-not $NoFetch) {
    Invoke-Git -Arguments @("fetch", "--prune", $Remote) | Out-Null
}

$defaultRef = (& git symbolic-ref --quiet --short "refs/remotes/$Remote/HEAD" 2>$null)
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($defaultRef)) {
    throw "Cannot detect $Remote default branch (refs/remotes/$Remote/HEAD)."
}

$defaultRef = $defaultRef.Trim()
$prefix = "$Remote/"
$defaultBranch = if ($defaultRef.StartsWith($prefix)) {
    $defaultRef.Substring($prefix.Length)
} else {
    $defaultRef
}

$currentBranch = (Invoke-Git -Arguments @("rev-parse", "--abbrev-ref", "HEAD") | Select-Object -First 1).Trim()

$protected = @($ProtectedBranches + $defaultBranch + $currentBranch) |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
    Select-Object -Unique

Write-Host "Remote: $Remote"
Write-Host "Default branch: $defaultBranch"
Write-Host ("Protected branches: {0}" -f ($protected -join " "))

$mergedBranches = Invoke-Git -Arguments @("branch", "--format=%(refname:short)", "--merged", "$Remote/$defaultBranch") |
    ForEach-Object { $_.Trim() } |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

$branchesToDelete = $mergedBranches | Where-Object { $protected -notcontains $_ }

if ($DryRun) {
    Write-Host "Branches that would be deleted:"

    if (-not $branchesToDelete) {
        Write-Host " - (none)"
        exit 0
    }

    foreach ($branch in $branchesToDelete) {
        Write-Host " - $branch"
    }

    exit 0
}

foreach ($branch in $branchesToDelete) {
    Write-Host "Deleting local merged branch: $branch"
    Invoke-Git -Arguments @("branch", "-d", $branch) | Out-Null
}
