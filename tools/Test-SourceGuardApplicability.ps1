<#
.SYNOPSIS
    Regression tests for issue #52: absent source is explicit, present violations still fail.
.DESCRIPTION
    Runs the real guard entry points in child processes, checking both status and diagnostic.
    Invoked by Test-IcelandicKeywordCounts.ps1 -SelfTest in the existing Source Guards job.
    Every fixture lives under a unique temporary directory and is removed in finally.
#>
param()
$ErrorActionPreference = 'Stop'
$root = Join-Path ([IO.Path]::GetTempPath()) ('source-guard-applicability-' + [guid]::NewGuid().ToString('N'))
$script:checks = 0

function Invoke-Guard([string]$Name, [string[]]$Arguments) {
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = (Join-Path $PSHOME $(if ($IsWindows) { 'pwsh.exe' } else { 'pwsh' }))
    $info.UseShellExecute = $false
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    foreach ($arg in @('-NoProfile', '-NonInteractive', '-File', (Join-Path $PSScriptRoot $Name)) + $Arguments) {
        $info.ArgumentList.Add($arg)
    }
    $child = [Diagnostics.Process]::Start($info)
    try {
        $stdout = $child.StandardOutput.ReadToEndAsync()
        $stderr = $child.StandardError.ReadToEndAsync()
        $child.WaitForExit()
        return [pscustomobject]@{ Code = $child.ExitCode; Text = $stdout.Result + $stderr.Result }
    }
    finally { $child.Dispose() }
}

function Assert-Guard([string]$Name, [string[]]$Arguments, [bool]$Success, [string]$Diagnostic) {
    $result = Invoke-Guard $Name $Arguments
    if (($result.Code -eq 0) -ne $Success -or $result.Text -notmatch $Diagnostic) {
        throw "Applicability test failed for $Name ($($Arguments -join ' ')): exit $($result.Code), expected success=$Success and '$Diagnostic'. $($result.Text)"
    }
    if (-not $Success -and $result.Text -match 'NOT_APPLICABLE:') {
        throw "$Name hid a violation behind NOT_APPLICABLE: $($result.Text)"
    }
    $script:checks++
}

function Write-Fixture([string]$Name, [hashtable]$Files) {
    $folder = Join-Path $root $Name
    New-Item -ItemType Directory -Path (Join-Path $folder 'src') -Force | Out-Null
    foreach ($file in $Files.Keys) {
        Set-Content -LiteralPath (Join-Path $folder "src/$file") -Value $Files[$file] -Encoding UTF8
    }
    return $folder
}

try {
    $absent = Join-Path $root 'absent source with spaces'
    New-Item -ItemType Directory -Path $absent -Force | Out-Null
    foreach ($name in @('Test-NoClientCallstack.ps1', 'Test-ValidatedTableView.ps1', 'Test-PermissionCoverage.ps1',
            'Test-ContractParameterKeys.ps1', 'Test-MixedLanguageLabels.ps1')) {
        Assert-Guard $name @('-AppFolder', $absent) $true 'NOT_APPLICABLE: app/src is absent'
    }
    Assert-Guard 'Test-IcelandicXlfInSync.ps1' @('-TranslationsFolder', (Join-Path $absent 'Translations')) $true 'NOT_APPLICABLE: app/src is absent'
    Assert-Guard 'Test-IcelandicKeywordCounts.ps1' @('-AppFolder', $absent) $true 'NOT_APPLICABLE: no message types registered'

    $callstack = Write-Fixture 'callstack' @{'Bad.al' = "codeunit 1 Bad`n{`n    procedure Run()`n    begin`n        Response.Add('callstack', 'private');`n    end;`n}"}
    Assert-Guard 'Test-NoClientCallstack.ps1' @('-AppFolder', $callstack) $false 'A call stack is returned'
    $view = Write-Fixture 'view' @{'Bad.al' = "codeunit 1 Bad`n{`n    procedure Run()`n    begin`n        Rec.SetView(ViewText);`n    end;`n}"}
    Assert-Guard 'Test-ValidatedTableView.ps1' @('-AppFolder', $view) $false 'A tableView is applied without'
    $permissions = Write-Fixture 'permissions' @{'Bad.al' = "page 1 Ungranted`n{`n}"}
    Assert-Guard 'Test-PermissionCoverage.ps1' @('-AppFolder', $permissions) $false 'not-granted: page'

    $contract = Write-Fixture 'contract' @{
        'Type.al' = @'
enum 1 "Message Type ori"
{
    value(1; "Demo.Thing.Get")
    {
        Implementation = "Msg Interface ori" = "Demo Impl ori", "Msg Contract ori" = "Demo Impl ori";
    }
}
'@
        'Bad.al' = @'
codeunit 2 "Demo Impl ori"
{
    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        RequestJson: JsonObject;
        Token: JsonToken;
    begin
        RequestJson := Argument.GetRequestJson();
        if RequestJson.Get('undocumented', Token) then;
    end;
    procedure GetParameters(var Parameters: JsonArray): Boolean
    var
        ContractMgt: Codeunit "Msg Contract Mgt ori";
    begin
        Parameters.Add(ContractMgt.Parameter('unread', 'string', true, 'Never read.'));
        exit(true);
    end;
}
'@
    }
    Assert-Guard 'Test-ContractParameterKeys.ps1' @('-AppFolder', $contract) $false 'declared-not-read\|unread'
    $mixed = Write-Fixture 'mixed' @{'Bad.al' = @'
codeunit 1 "Bad ori"
{
    procedure Run()
    var
        FailedErr: Label 'The request failed.', Locked = true;
        NextStepTxt: Label 'Send it again.', Comment = 'is-IS=Send again.';
    begin
        Error(FailedErr + NextStepTxt);
    end;
}
'@}
    Assert-Guard 'Test-MixedLanguageLabels.ps1' @('-AppFolder', $mixed) $false 'mixed-language'
    $keywords = Write-Fixture 'keywords' @{'Bad.al' = 'enumextension 1 Types extends "Message Type ori" { }'}
    Assert-Guard 'Test-IcelandicKeywordCounts.ps1' @('-AppFolder', $keywords) $false 'the guard checked nothing'
    Set-Content -LiteralPath (Join-Path $keywords 'src/Bad.al') -Value "KeywordsLbl: Label 'a, b', Comment = 'is-IS=x';"
    Assert-Guard 'Test-IcelandicKeywordCounts.ps1' @('-AppFolder', $keywords) $false 'Icelandic keyword list has 1 entries'
    $empty = Write-Fixture 'empty-source' @{}
    Assert-Guard 'Test-IcelandicXlfInSync.ps1' @('-TranslationsFolder', (Join-Path $empty 'Translations')) $false 'no-build:'

    # Existing translation input remains applicable even without source.
    $translations = Join-Path $absent 'Translations'
    New-Item -ItemType Directory -Path $translations | Out-Null
    Set-Content -LiteralPath (Join-Path $translations 'Demo.is-IS.xlf') -Value '<xliff />'
    Assert-Guard 'Test-IcelandicXlfInSync.ps1' @('-TranslationsFolder', $translations) $false 'no-build:'

    # HelpLinks must still reject bad manifest links without source and bad pages with source.
    $manifest = @{ help = 'https://invalid.example/'; privacyStatement = 'https://docs.bifrost.origo.is/privacy/'; EULA = 'https://docs.bifrost.origo.is/eula/'; contextSensitiveHelpUrl = 'https://docs.bifrost.origo.is/{0}/shopify/' }
    $manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $absent 'app.json')
    Assert-Guard 'Test-HelpLinks.ps1' @('-AppFolder', $absent) $false 'app.json help is'
    $manifest.help = 'https://docs.bifrost.origo.is/en-us/shopify/'
    $manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $absent 'app.json')
    Assert-Guard 'Test-HelpLinks.ps1' @('-AppFolder', $absent) $true 'Checked the app.json links and 0 page'
    $page = Write-Fixture 'help-page' @{'Bad.al' = 'page 1 "Bad ori" { }'}
    $manifest.contextSensitiveHelpUrl = 'https://docs.bifrost.origo.is/{0}/help/shopify/'
    $manifest | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $page 'app.json')
    $docs = Join-Path $root 'docs'
    foreach ($dir in 'help/shopify', 'i18n/is-IS/docusaurus-plugin-content-docs-help-shopify/current') {
        New-Item -ItemType Directory -Path (Join-Path $docs $dir) -Force | Out-Null
    }
    Assert-Guard 'Test-HelpLinks.ps1' @('-AppFolder', $page, '-DocsPath', $docs) $false 'has no ContextSensitiveHelpPage'
    Write-Host "Source guard applicability: $script:checks passed, 0 failed, 0 skipped."
}
finally {
    if (Test-Path -LiteralPath $root) { Remove-Item -LiteralPath $root -Recurse -Force }
}
