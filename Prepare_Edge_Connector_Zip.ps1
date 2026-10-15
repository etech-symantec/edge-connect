param([Parameter(Mandatory=$true)][string]$ZipPath)
$ErrorActionPreference="Stop"
$ZipPath=(Resolve-Path -LiteralPath $ZipPath).Path
$root=Split-Path $ZipPath -Parent
$work=Join-Path $env:TEMP ("EdgeConnectorPrepare_"+[guid]::NewGuid().ToString("N"))
$out=Join-Path $root "edge_connector_upload"
New-Item -ItemType Directory -Force -Path $work,$out|Out-Null
try{
  Expand-Archive -LiteralPath $ZipPath -DestinationPath $work -Force

  # Rename legacy executable filename if present.
  $exe=Get-ChildItem $work -Recurse -File -Filter "ProxySG_Policy_Trace_Editor*.exe"|Select-Object -First 1
  if($exe){
    Rename-Item -LiteralPath $exe.FullName -NewName "Edge_Connector.exe"
  }

  # Rename Trace Editor wording in text/source files.
  $textExt=@(".html",".htm",".js",".css",".json",".txt",".md",".go",".ps1",".cmd")
  Get-ChildItem $work -Recurse -File|Where-Object{$textExt -contains $_.Extension.ToLower()}|ForEach-Object{
    try{
      $c=Get-Content -Raw -LiteralPath $_.FullName -Encoding UTF8
      $n=$c.Replace("ProxySG Policy Trace Editor","Edge Connector").
            Replace("ProxySG Trace Editor","Edge Connector").
            Replace("Policy Trace Editor","Edge Connector").
            Replace("Trace Editor","Edge Connector").
            Replace("ProxySG_Policy_Trace_Editor","Edge_Connector")
      if($n -ne $c){Set-Content -LiteralPath $_.FullName -Value $n -Encoding UTF8}
    }catch{}
  }

  $outZip=Join-Path $out "Edge_Connector.zip"
  if(Test-Path $outZip){Remove-Item $outZip -Force}
  Compress-Archive -Path (Join-Path $work "*") -DestinationPath $outZip -CompressionLevel Optimal
  $hash=(Get-FileHash $outZip -Algorithm SHA256).Hash.ToLowerInvariant()
  "$hash  Edge_Connector.zip"|Set-Content -LiteralPath (Join-Path $out "Edge_Connector.zip.sha256") -Encoding ASCII
  Write-Host "[OK] $outZip"
  Write-Host "[OK] $(Join-Path $out 'Edge_Connector.zip.sha256')"
  Start-Process explorer.exe $out
}finally{
  Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}
