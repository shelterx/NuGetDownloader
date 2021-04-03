# --- settings ---
$feedUrlBase = "https://aka.ms/sme-extension-feed"
$overwrite = $false
$destinationDirectory = "C:\Temp\WACPackages"

# --- locals ---
$webClient = New-Object System.Net.WebClient

# --- functions ---

# download entries on a page, recursively called for page continuations
function DownloadEntries {
 param ([string]$feedUrl) 
 $feed = [xml]$webClient.DownloadString($feedUrl)
 write-host $feedUrl
 $entries = $feed.feed.entry 
 $progress = 0
            
 foreach ($entry in $entries) {
    $url = $entry.content.src
    $fileName = $entry.properties.id + "." + $entry.properties.version + ".nupkg"
    $saveFileName = join-path $destinationDirectory $fileName
    $pagepercent = ((++$progress)/$entries.Length*100)
    if ((-not $overwrite) -and (Test-Path -path $saveFileName)) 
    {
        write-progress -Activity "$fileName already downloaded" `
                       -Status "$pagepercent% of current page complete" `
                       -PercentComplete $pagepercent
        Continue
    }
    write-progress -Activity "Downloading $fileName" `
                   -Status "$pagepercent% of current page complete" `
                   -PercentComplete $pagepercent

    [int]$trials = 0
    do {
        Try {
            $trials +=1
            $webClient.DownloadFile($url, $saveFileName)
            Break
        } Catch [System.Net.WebException] {
            Write-Host "Problem downloading $url `tTrial $trials `
                       `n`tException: " $_.Exception.Message
        }
    }
    While ($trials -lt 3)
  }

  $link = $feed.feed.link | Where { $_.rel.startsWith("next") } | Select href
  if ($link -ne $null) {
    # if using a paged url with a $skiptoken like 
    # http:// ... /Packages?$skiptoken='EnyimMemcached-log4net','2.7'
    # remember that you need to escape the $ in powershell with `
    Return $link.href
  }
  Return $null
}  

# the NuGet feed uses a fwlink which redirects
# using this to follow the redirect
Function GetPackageUrl {
 Param ([string]$feedUrlBase) 
 $resp = [xml]$webClient.DownloadString($feedUrlBase)
 Return $resp.service.GetAttribute("xml:base")
}

# --- do the actual work ---

# if dest dir doesn't exist, create it
if (!(Test-Path -path $destinationDirectory)) { 
    New-Item $destinationDirectory -type directory 
}

# set up feed URL
$serviceBase = GetPackageUrl($feedUrlBase)
$feedUrl = $serviceBase + "/"
$feedUrl = $feedUrl + "Search()?IsLatestVersion=true"

While($feedUrl -ne $null) {
     $feedUrl = DownloadEntries $feedUrl
}
