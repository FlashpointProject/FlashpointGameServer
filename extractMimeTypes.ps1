# Script to extract MIME types and suffixes from "About Plugins.htm"
# generated from Flashpoint Navigator
# and compare them with existing entries in proxySettings.json
# Usage:
# open flashpoint-navigator, navigate to about:plugins
# save the page as "About Plugins.htm"
# place this script, the HTML file, and proxySettings.json in the same folder
# run the script in PowerShell

$htmlFile = "About Plugins.htm"
$jsonFile = "proxySettings.json"

$html = Get-Content $htmlFile -Raw

$proxySettings = Get-Content $jsonFile -Raw | ConvertFrom-Json
$existingMimeTypes = $proxySettings.extMimeTypes

# Extract all MIME type entries from HTML tables
# Pattern: <td>MIME_TYPE</td><td>DESCRIPTION</td><td>SUFFIXES</td>
$pattern = '<td>([^<]+)</td>\s*<td>[^<]*</td>\s*<td>([^<]*)</td>'
$matches = [regex]::Matches($html, $pattern)

$mimeTypeMap = @{}

Write-Host "Extracting MIME types and suffixes from $htmlFile..."
Write-Host ""

foreach ($match in $matches) {
    $mimeType = $match.Groups[1].Value
    $suffixes = $match.Groups[2].Value
    
    if ($suffixes) {
        $suffixList = $suffixes -split ',' | ForEach-Object { $_.Trim() }
        
        foreach ($suffix in $suffixList) {
            if ($suffix -and $suffix -ne '') {
                if (-not $mimeTypeMap.ContainsKey($suffix)) {
                    $mimeTypeMap[$suffix] = $mimeType
                }
            }
        }
    }
}

Write-Host "Found $($mimeTypeMap.Count) unique suffix-to-MIME-type mappings"
Write-Host ""

$missingEntries = @{}
$existingEntries = @{}
$differentEntries = @{}

foreach ($suffix in $mimeTypeMap.Keys | Sort-Object) {
    $newMimeType = $mimeTypeMap[$suffix]
    
    if ($existingMimeTypes.PSObject.Properties.Name -contains $suffix) {
        $existingMimeType = $existingMimeTypes.$suffix
        if ($existingMimeType -ne $newMimeType) {
            $differentEntries[$suffix] = @{
                existing = $existingMimeType
                new = $newMimeType
            }
        } else {
            $existingEntries[$suffix] = $newMimeType
        }
    } else {
        $missingEntries[$suffix] = $newMimeType
    }
}

Write-Host "============================================"
Write-Host "MISSING ENTRIES (need to be added):"
Write-Host "============================================"
if ($missingEntries.Count -eq 0) {
    Write-Host "  None - all suffixes are already in proxySettings.json"
} else {
    foreach ($suffix in $missingEntries.Keys | Sort-Object) {
        Write-Host "  `"$suffix`": `"$($missingEntries[$suffix])`","
    }
}
Write-Host ""

Write-Host "============================================"
Write-Host "DIFFERENT ENTRIES (same suffix, different MIME type):"
Write-Host "============================================"
if ($differentEntries.Count -eq 0) {
    Write-Host "  None"
} else {
    foreach ($suffix in $differentEntries.Keys | Sort-Object) {
        Write-Host "  $suffix"
        Write-Host "    Existing: $($differentEntries[$suffix].existing)"
        Write-Host "    From HTML: $($differentEntries[$suffix].new)"
    }
}
Write-Host ""

Write-Host "============================================"
Write-Host "SUMMARY:"
Write-Host "============================================"
Write-Host "  Total suffixes in HTML: $($mimeTypeMap.Count)"
Write-Host "  Already in proxySettings.json: $($existingEntries.Count)"
Write-Host "  Missing from proxySettings.json: $($missingEntries.Count)"
Write-Host "  Different MIME type: $($differentEntries.Count)"
Write-Host ""

if ($missingEntries.Count -gt 0) {
    Write-Host "============================================"
    Write-Host "JSON FORMAT (for easy copy-paste):"
    Write-Host "============================================"
    $jsonOutput = @()
    foreach ($suffix in $missingEntries.Keys | Sort-Object) {
        $jsonOutput += "    `"$suffix`": `"$($missingEntries[$suffix])`""
    }
    Write-Host ($jsonOutput -join ",`n")
    Write-Host ""
}
