param(
    [string]$TenantId,
    [string]$ClientId,
    [string]$ClientSecret,
    [string]$AccessToken,
    [string]$CertificateThumbprint,
    [string]$Region = 'EUR',
    [string]$OutFile = $null,
    [string]$Folder = $null,
    [switch]$DebugMode = $False
)

# Help
function Show-Help {
    Write-Host "Available commands:"
    Write-Host "  search_all <query string>                 - Search for files based on the query string (in both SharePoint and OneDrive)"
    Write-Host "  search <query string> <Path>              - Search for files in a specific site/drive based on the query string"
    Write-Host "                                              If Path is not provided, it uses the current directory (if defined)"
    Write-Host "  dir <Path>                                - List site/drive content"
    Write-Host "                                              If Path is not provided, it uses the current directory (if defined)"
    Write-Host "  download [<ArrayID>] [<DriveID> <ItemID>] - Download a file using its array ID (based on search) or its drive ID and item ID"
    Write-Host "  cd <Path>                                 - Move into a specific SharePoint or OneDrive path"
    Write-Host "  region <Region>                           - Set or change the region"
    Write-Host "                                              This parameter is only required when Graph API is used via Application Permissions"
    Write-Host "  recursive                                 - Enable / Disable the recursive mode (not for 'dir' command)"
    Write-Host "  logfile <filename>                        - Log results in output file"
    Write-Host "  folder <folder path>                      - Folder where files are downloaded"
    Write-Host "  debug                                     - Enable / Disable the debug mode"
    Write-Host "  clear                                     - Removes all text from the current display"
    Write-Host "  help                                      - Show this help message"
    Write-Host "  exit                                      - Exit the script"
    Write-Host "`nAdditional information: `n- OneDrive root path is https://xxxxxxxx-my.sharepoint.com/personal/"
    Write-Host "- SharePoint root path is https://xxxxxxxx.sharepoint.com/sites/"
    Write-Host "`nThe following Graph API roles are recommended to fully use this tool:"
    Write-Host "- Sites.Read.All"
    Write-Host "- Files.Read.All"
    Write-Host ""
}

# Main interactive function
function Open-InteractiveShell {
    [CmdletBinding(DefaultParameterSetName = 'PasswordAuth')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'PasswordAuth')]
        [Parameter(Mandatory = $true, ParameterSetName = 'CertAuth')]
        [string]$TenantId,

        [Parameter(Mandatory = $true, ParameterSetName = 'PasswordAuth')]
        [Parameter(Mandatory = $true, ParameterSetName = 'CertAuth')]
        [string]$ClientId,

        [Parameter(Mandatory = $true, ParameterSetName = 'PasswordAuth')]
        [string]$ClientSecret,

        [Parameter(Mandatory = $true, ParameterSetName = 'CertAuth')]
        [string]$CertificateThumbprint,
        
        [Parameter(Mandatory = $true, ParameterSetName = 'TokenAuth')]
        [string]$AccessToken,

        [Parameter(Mandatory = $false)]
        [string]$Region,

        [Parameter(Mandatory = $false)]
        [bool]$Recursive = $false,

        [Parameter(Mandatory = $false)]
        [string]$OutFile = $null,

        [Parameter(Mandatory = $false)]
        [string]$Folder = $null,

        [Parameter(Mandatory = $true)]
        [bool]$DebugMode
    )

    # Get an access token
    if (-not $accessToken) {
        $tokenInfo = Connect-ToGraph -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret -CertificateThumbprint $CertificateThumbprint -DebugMode $DebugMode
        if (-not $tokenInfo) { return }
    } else {
        $tokenInfo = @{
            accessToken = $AccessToken
            tokenExpirationDate = $null
        }
    }

    # Get App roles and token expirationDate
    $roles, $tokenInfo.tokenExpirationDate = Get-TokenInformation -Token $tokenInfo.accessToken -DebugMode $DebugMode
    $sitesReadAll = ($roles -and ($roles -contains 'Sites.Read.All' -or $roles -contains 'Sites.ReadWrite.All'))

    $searchResults = $null
    $currentDirectory = $null

    # Interactive shell loop
    while ($true) {
        Write-Host "$ $currentDirectory> " -NoNewline
        $command = Read-Host
        $commandParts = $command -split '\s+'

        $tokenInfo = Update-AccessToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret -CertificateThumbprint $CertificateThumbprint -TokenInfo $tokenInfo -DebugMode $DebugMode
        if (-not $tokenInfo) { return }

        switch -Wildcard ($commandParts[0]) {
            # Search in all SharePoint and OneDrive
            "search_all" {
                if ($commandParts.Length -gt 1) {
                    $queryString = $commandParts[1..($commandParts.Length - 1)] -join " "

                    if ($sitesReadAll -eq $false) { 
                        Write-Host "[WARNING] Neither 'Sites.Read.All' nor 'Sites.ReadWrite.All' are present. Want to proceed in an agressive and slower mode ? (Yes/No) " -NoNewline -ForegroundColor Red
                        $proceed = Read-Host
                        $proceed = $proceed.ToLower()
                        if ($proceed -ne 'yes') { 
                            if ($DebugMode) { Write-Host "[DEBUG] Search_All abort.`n" -ForegroundColor Yellow }
                            break 
                        } else {
                            $searchResults = Search-InAllDrivesWithGraphAPI -Query $queryString -Token $tokenInfo.accessToken -OutFile $OutFile -Recursive $Recursive -DebugMode $DebugMode
                            break
                        }
                    }

                    $searchResults = Search-FilesWithGraphAPI -Query $queryString -Token $tokenInfo.accessToken -Region $Region -OutFile $OutFile -Recursive $Recursive -DebugMode $DebugMode
                    if (-not $searchResults -and $DebugMode) { Write-Host "[DEBUG] No result found." -ForegroundColor Yellow }
                } elseif ($DebugMode) { Write-Host "[DEBUG] No query string provided." -ForegroundColor Red }
            }

            # Search in the current directory or in the Path provided
            "search" {
                if ($commandParts.Length -gt 2) {
                    $queryString = $commandParts[1..($commandParts.Length - 2)] -join " "
                    $queryURL = $commandParts[($commandParts.Length - 1)]
                    $searchResults = Search-FilesWithGraphAPI -Query $queryString -Token $tokenInfo.accessToken -URL $queryURL -Region $Region -OutFile $OutFile -Recursive $Recursive -DebugMode $DebugMode
                    if (-not $searchResults -and $DebugMode) { Write-Host "[DEBUG] No result found." -ForegroundColor Yellow }
                } elseif ($currentDirectory)  {
                    $queryString = $commandParts[1..($commandParts.Length - 1)] -join " "
                    $searchResults = Search-FilesWithGraphAPI -Query $queryString -Token $tokenInfo.accessToken -URL $currentDirectory -Region $Region -OutFile $OutFile -Recursive $Recursive -DebugMode $DebugMode
                } elseif ($DebugMode) { Write-Host "[DEBUG] No query string provided." -ForegroundColor Red }
            }
            
            # List children of the current Path or the Path provided
            "dir" {
                # Check if an argument (Path) is provided
                if ($commandParts.Length -gt 1) {
                    $queryURL = $commandParts[1..($commandParts.Length - 1)] -join " "
                    $searchResults = Get-DriveItemsWithGraphAPI -Token $tokenInfo.accessToken -URL $queryURL -Region $Region -DebugMode $DebugMode
                    if (-not $searchResults -and $DebugMode) { Write-Host "[DEBUG] No result found." -ForegroundColor Yellow }
                } elseif ($currentDirectory) { 
                    $searchResults = Get-DriveItemsWithGraphAPI -Token $tokenInfo.accessToken -URL $currentDirectory -Region $Region -DebugMode $DebugMode
                    if (-not $searchResults -and $DebugMode) { Write-Host "[DEBUG] No result found." -ForegroundColor Yellow }
                } elseif ($DebugMode) { Write-Host "[DEBUG] No path provided and no directory set." -ForegroundColor Red }
            }

            # Download a file
            "download" {
                # Check if one argument is provided (Array ID) 
                if ($commandParts.Length -eq 2) {
                    if (-not $searchResults -or $searchResults.Count -eq 0) {
                        if ($DebugMode) { Write-Host "[DEBUG] No search result to download." -ForegroundColor Yellow }
                        break
                    }
                    $arrayID = $commandParts[1]
                    if ($arrayID -match '^\d+(\.\d+)?$') {
                        $fileToDownload = $searchResults[$arrayID]
                    } else {
                        if ($DebugMode) { Write-Host "[DEBUG] Invalid Array ID." -ForegroundColor Red }
                        break
                    }
                    $downloadResult = Get-FileWithGraphAPI -DriveId $fileToDownload.DriveID -DriveItemId $fileToDownload.ID -Size $fileToDownload.size -OutFile $fileToDownload.name -Folder $Folder -Token $tokenInfo.accessToken -DebugMode $DebugMode
                }
                # Check if two arguments are provided (DriveID and DriveItemID)  
                elseif ($commandParts.Length -eq 3) {
                    $driveId = $commandParts[1]
                    $driveItemId = $commandParts[2]
                    $driveIdPattern = "^b![A-Za-z0-9_-]+$"          # Starts with "b!" and has alphanumeric, -, or _
                    $driveItemIdPattern = "^[A-Za-z0-9!_/=-]+$"     # Alphanumeric with allowed special chars

                    # Check if the DriveID and DriveItemID values match the defined patterns  
                    if ($driveId -match $driveIdPattern -and $driveItemId -match $driveItemIdPattern) {
                        $downloadResult = Get-FileWithGraphAPI -DriveId $driveId -DriveItemId $driveItemId -OutFile $fileToDownload.name -Folder $Folder -Token $tokenInfo.accessToken -DebugMode $DebugMode
                    } elseif ($DebugMode) {
                        Write-Host "[DEBUG] Invalid format for DriveId or DriveItemId." -ForegroundColor Red 
                        break
                    } 
                } elseif ($DebugMode) { 
                    Write-Host "[DEBUG] Provide ID to download (based on previous search results or DriveID & ID)." -ForegroundColor Red 
                    break
                }

                if (-not $downloadResult -and $DebugMode) { Write-Host "[DEBUG] Download failed." -ForegroundColor Red }
            }

            # Move to a drive
            "cd" {
                if ($commandParts.Length -lt 2) {
                    if ($DebugMode) { Write-Host "[DEBUG] No path provided." -ForegroundColor Yellow }
                    break
                }

                $newPath = $commandParts[1..($commandParts.Length - 1)] -join " "

                switch -Regex ($newPath) {
                    # Check if it is an absolute path
                    "^https://" { $currentDirectory = $newPath.TrimEnd("/") }
                    
                    # if "cd .."
                    "^\.\.$" {
                        if ($currentDirectory -match "^https://[^/]+/[^/]+(/.+)?$") { $currentDirectory = $currentDirectory -replace "/[^/]+$", "" } 
                        elseif ($DebugMode) { Write-Host "[DEBUG] Already at the root. Cannot go back further." -ForegroundColor Yellow }
                    }
                    default {
                        if ($currentDirectory) { $currentDirectory = "$currentDirectory/$newPath" -replace "(?<!https:)/+", "/" } 
                        elseif ($DebugMode) { Write-Host "[DEBUG] Invalid path to 'cd' on. Must be https://x.sharepoint.com/x" -ForegroundColor Yellow }
                    }
                }
                if ($DebugMode) { Write-Host "[DEBUG] Current directory changed to: $currentDirectory" -ForegroundColor Yellow }
            }

            # Define a region (FRA, EUR, AMA, etc.)
            "region" {
                # Ensure there are enough arguments
                if ($commandParts.Length -eq 2) {
                    $Region = $commandParts[1]
                    if ($DebugMode) { Write-Host "[DEBUG] Region set to $Region." -ForegroundColor Yellow }
                } else {
                    if ($DebugMode) { Write-Host "[DEBUG] No region provided." -ForegroundColor Red }
                }
            }
            
            # Enable or disable recursive mode
            "recursive" {
                $Recursive = -not $Recursive
            }

            # Specify a log file path
            "logfile" {
                if ($commandParts.Length -lt 2) {
                    if ($DebugMode) { Write-Host "[DEBUG] No path provided." -ForegroundColor Yellow }
                    break
                }
                $OutFile = $commandParts[1..($commandParts.Length - 1)] -join " "
                if ($DebugMode) { Write-Host "[DEBUG] Current log file changed to: $OutFile" -ForegroundColor Yellow }
            }

            # Specify a folder path where file are downloaded
            "folder" {
                if ($commandParts.Length -lt 2) {
                    if ($DebugMode) { Write-Host "[DEBUG] No path provided." -ForegroundColor Yellow }
                    break
                }
                $tmpFolder = $commandParts[1..($commandParts.Length - 1)] -join " "

                if (Test-Path -Path $tmpFolder -PathType Container) {
                    $Folder = $tmpFolder.TrimEnd('\', '/') + "/"
                    if ($DebugMode) { Write-Host "[DEBUG] Current folder where files are downloaded to: $Folder" -ForegroundColor Yellow }
                } else {
                    if ($DebugMode) { Write-Host "[DEBUG] Folder does not exist." -ForegroundColor Yellow }
                    break
                }
            }
            
            # Enable or disable debug mode
            "debug" {
                $DebugMode = -not $DebugMode
            }

            "clear" {
                Clear-Host
            }

            "help" {
                Show-Help
            }

            "exit" {
                if ($DebugMode) { Write-Host "[DEBUG] Exiting script.`n" -ForegroundColor Yellow }
                return
            }

            default {
                Write-Host "[ERROR] Invalid command. Type 'help' for a list of available commands.`n" -ForegroundColor Red
            }
        }
    }
}

<#
    .DESCRIPTION
    The Get-TokenInformation function retrieves the roles of the application used by decoding the JWT token, as well as the expiration date of this token.
#>
function Get-TokenInformation { 
    param (
        [Parameter(Mandatory = $true)]
        [string]$Token,

        [Parameter(Mandatory = $true)]
        [bool]$DebugMode
    )

    $tokenPayload = $Token.Split('.')[1]
    $padLength = 4 - ($tokenPayload.Length % 4)
    if ($padLength -lt 4) { $tokenPayload += "=" * $padLength }

    $payload = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($tokenPayload))
    $expTimestamp = ($payload | ConvertFrom-Json).exp
    $expirationDate = [DateTimeOffset]::FromUnixTimeSeconds($expTimestamp).DateTime.ToLocalTime()

    $rolesList = ($payload | ConvertFrom-Json).roles
    if (-not $rolesList) { $rolesList = ($payload | ConvertFrom-Json).scp }
    return $rolesList, $expirationDate
}

<#
    .DESCRIPTION
    The Update-AccessToken function checks if the JWT token is still valid or not. 
    If not, it performs the authentication process again and returns a new JWT token.
#>
function Update-AccessToken {
    param (
        [Parameter(Mandatory = $true)]
        $TokenInfo,

        [Parameter(Mandatory = $false)]
        [string]$TenantId,

        [Parameter(Mandatory = $false)]
        [string]$ClientId,

        [Parameter(Mandatory = $false)]
        [string]$ClientSecret,

        [Parameter(Mandatory = $false)]
        [string]$CertificateThumbprint,

        [Parameter(Mandatory = $true)]
        [bool]$DebugMode
    )

    $currentDateTime = Get-Date
    # Check if the current date is greater than the token expiration date 
    if ($currentDateTime -gt $TokenInfo.tokenExpirationDate) {
        if ($DebugMode) { Write-Host "[DEBUG] Token has expired." -ForegroundColor Yellow }
        if (-not $TenantId -or -not $ClientId -or -not $ClientSecret) { 
            if ($DebugMode) { Write-Host "[DEBUG] Cannot update it without ClientId and ClientSecret. Exiting." -ForegroundColor Yellow }
            return $null 
        }
        return Connect-ToGraph -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret -DebugMode $DebugMode
    }

    return $TokenInfo
}

<#
    .DESCRIPTION
    The Connect-ToGraph function connects to Microsoft Graph API using TenantID, AppID, and AppSecret. 
    If successful, it returns a JWT token.
#>
function Connect-ToGraph {
    param (
        [Parameter(Mandatory = $true)]
        [string]$TenantId,

        [Parameter(Mandatory = $true)]
        [string]$ClientId,

        [Parameter(Mandatory = $false)]
        [string]$ClientSecret,

        [Parameter(Mandatory = $false)]
        [string]$CertificateThumbprint,

        [Parameter(Mandatory = $true)]
        [bool]$DebugMode
    )

    if ($CertificateThumbprint) {
        if ($DebugMode) { Write-Host "[DEBUG] Authenticating with certificate." -ForegroundColor Yellow }

        $stores = "CurrentUser","LocalMachine"
        foreach ($store in $stores) {
            $cert = Get-Item "Cert:\$store\My\$CertificateThumbprint" -ErrorAction SilentlyContinue
            if ($cert) { break }
        }
        if (!$cert -or $cert.NotAfter -lt (Get-Date)) {
            if ($DebugMode) { Write-Host "[ERROR] Certificate missing or invalid." -ForegroundColor Red }
            return $null
        }
        
        function b64url([byte[]]$bytes) { return [Convert]::ToBase64String($bytes).Split('=')[0].Replace('+', '-').Replace('/', '_') }
        $header = @{ alg="RS256"; typ="JWT"; x5t=(b64url $Cert.GetCertHash()) } | ConvertTo-Json -Compress
        $payload = @{
            aud="https://login.microsoftonline.com/$TenantId/v2.0"; exp=([DateTimeOffset]::Now.ToUnixTimeSeconds()+600)
            iss=$ClientId; jti=[guid]::NewGuid().ToString(); nbf=([DateTimeOffset]::Now.ToUnixTimeSeconds()); sub=$ClientId
        } | ConvertTo-Json -Compress
        
        $data = "$(b64url([System.Text.Encoding]::UTF8.GetBytes($header))).$(b64url ([System.Text.Encoding]::UTF8.GetBytes($payload)))"
        $rsa = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)
        $sig = b64url($rsa.SignData([System.Text.Encoding]::UTF8.GetBytes($data), [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1))
        
        $body = @{
            grant_type       = "client_credentials"; 
            client_id        = $ClientId; client_assertion_type = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
            client_assertion = "$data.$sig"; 
            scope            = "https://graph.microsoft.com/.default"
        }
    } else {
        if ($DebugMode) { Write-Host "[DEBUG] Authenticating with Client Secret." -ForegroundColor Yellow }
        $body = @{
            grant_type    = "client_credentials";
            client_id     = $ClientId
            client_secret = $ClientSecret
            scope         = "https://graph.microsoft.com/.default"
        }
        $headers = @{
            "Content-Type" = "application/x-www-form-urlencoded"
        }
    }
    
    # Authenticate to Microsoft Graph
    $response = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Body $Body -Headers $headers
    
    $accessToken = $response.access_token
    $tokenExpiration = $response.expires_in
    $currentDateTime = Get-Date
    $tokenExpirationDate = $currentDateTime.AddSeconds($tokenExpiration)

    if ($accessToken) {
        Write-Host "[+] Successfully connected to Microsoft Graph API." -ForegroundColor Green
        if ($DebugMode) { Write-Host "[DEBUG] Token: $accessToken" -ForegroundColor Yellow }
    } else {
        Write-Host "[ERROR] Authentication failed." -ForegroundColor Red
        return $null
    }

    return @{
        accessToken         = $accessToken
        tokenExpirationDate = $tokenExpirationDate
    }
}

<#
    .DESCRIPTION
    The Search-InAllDrivesWithGraphAPI function enumerates OneDrive users and SharePoint sites.
    Then, it search in these drives for a specific text (Query) and returns the results.
#>
function Search-InAllDrivesWithGraphAPI {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Query,

        [Parameter(Mandatory = $true)]
        [string]$Token,

        [Parameter(Mandatory = $false)]
        [bool]$Recursive,

        [Parameter(Mandatory = $false)]
        [string]$OutFile = $null,

        [Parameter(Mandatory = $true)]
        [bool]$DebugMode
    )

    $allResults = @()
    $count = 0
    $headers = @{
        "Authorization" = "Bearer $Token"
        "Content-Type"  = "application/json"
    }

    # Verify if the app has the required role to enumerate users
    $roles, $expirationDate = Get-TokenInformation -Token $Token -DebugMode $DebugMode
    if ($roles -and ($roles -contains 'Directory.Read.All' -or $roles -contains 'Directory.ReadWrite.All')) {
        # Get the users' list
        $usersUrl = "https://graph.microsoft.com/v1.0/users"
        $users = Invoke-RestMethod -Uri $usersUrl -Headers $headers -Method Get

        # Search in all OneDrive drives
        foreach ($user in $users.value) {
            $searchUrl = "https://graph.microsoft.com/v1.0/users/$($user.id)/drive/root/search(q='$Query')"

            # Perform the search request
            try {
                $response = Invoke-RestMethod -Uri $searchUrl -Headers $headers -Method Get
            } catch {
                # Handle specific HTTP errors
                if ($_.Exception.Response.StatusCode -eq 404 -and $DebugMode) { Write-Host "[DEBUG] OneDrive not found for this user (404)." -ForegroundColor Yellow }
                elseif ($DebugMode) { Write-Host "[DEBUG] An error occurred: $($_.Exception.Message)." -ForegroundColor Red }
            }
            Write-Host $response.'@odata.nextLink'
            foreach ($resource in $response.value) {
                $tableData = [PSCustomObject]@{
                    ArrayID               = $count
                    Name                  = $resource.name
                    ID                    = $resource.id
                    DriveID               = $resource.parentReference.driveId
                    WebUrl                = $resource.webUrl
                    LastModifiedDateTime  = $resource.lastModifiedDateTime
                    Size                  = $resource.size
                    Summary               = ""
                }
                Write-Host "[" $count "]" $resource.name -ForegroundColor Green
                Write-Host "`tURL: "$resource.webUrl
                Write-Host "`tDriveID & ItemID: $($resource.parentReference.driveId) $($resource.id)"
                Write-Host "`tLastModifiedDateTime: "$resource.lastModifiedDateTime

                if ($OutFile) {
                    Write-Output "[" $count "]" $resource.name | Out-File -Append -FilePath $OutFile
                    Write-Output "`tURL: $($resource.webUrl)" | Out-File -Append -FilePath $OutFile
                    Write-Output "`tDriveID & ItemID: $($resource.parentReference.driveId) $($resource.id)" | Out-File -Append -FilePath $OutFile
                    Write-Output "`tLastModifiedDateTime: $($resource.lastModifiedDateTime)" | Out-File -Append -FilePath $OutFile
                }

                $allResults += $tableData
                $count += 1
            }
        }
    } elseif ($DebugMode) { Write-Host "[DEBUG] Neither 'Directory.Read.All' nor 'Directory.ReadWrite.All' are present. Skipping users' enumeration." -ForegroundColor Red }

    # Get SharePoint sites list 
    $sitesUrl = "https://graph.microsoft.com/v1.0/sites?search=*"
    # Perform the search request
    try {
        $sites = Invoke-RestMethod -Uri $sitesUrl -Headers $headers -Method Get
    } catch {
        # Handle specific HTTP errors
        if ($_.Exception.Response.StatusCode -eq 403 -and $DebugMode) { Write-Host "[DEBUG] Sites cannot be enumerated (403)." -ForegroundColor Yellow }
        elseif ($DebugMode) { Write-Host "[DEBUG] An error occurred: $($_.Exception.Message)." -ForegroundColor Red }
        return $allResults
    }
    
    # Search in all SharePoint sites
    foreach ($site in $sites.value) {
        $drivesUrl = "https://graph.microsoft.com/v1.0/sites/$($site.id)/drives"
        $drives = Invoke-RestMethod -Uri $drivesUrl -Headers $headers -Method Get
    
        foreach ($drive in $drives.value) {
            $searchUrl = "https://graph.microsoft.com/v1.0/drives/$($drive.id)/root/search(q='$Query')"

            # Perform the search request
            try {
                $response = Invoke-RestMethod -Uri $searchUrl -Headers $headers -Method Get
            } catch {
                # Handle specific HTTP errors
                if ($DebugMode) { Write-Host "[DEBUG] An error occurred: $($_.Exception.Message)." -ForegroundColor Red }
            }
        
            foreach ($resource in $response.value) {
                $tableData = [PSCustomObject]@{
                    ArrayID               = $count
                    Name                  = $resource.name
                    ID                    = $resource.id
                    DriveID               = $resource.parentReference.driveId
                    WebUrl                = $resource.webUrl
                    LastModifiedDateTime  = $resource.lastModifiedDateTime
                    Size                  = $resource.size
                    Summary               = ""
                }
                Write-Host "[" $count "]" $resource.name -ForegroundColor Green
                Write-Host "`tURL: "$resource.webUrl
                Write-Host "`tDriveID & ItemID: $($resource.parentReference.driveId) $($resource.id)"
                Write-Host "`tLastModifiedDateTime: "$resource.lastModifiedDateTime

                if ($OutFile) {
                    Write-Output "[" $count "]" $resource.name | Out-File -Append -FilePath $OutFile
                    Write-Output "`tURL: $($resource.webUrl)" | Out-File -Append -FilePath $OutFile
                    Write-Output "`tDriveID & ItemID: $($resource.parentReference.driveId) $($resource.id)" | Out-File -Append -FilePath $OutFile
                    Write-Output "`tLastModifiedDateTime: $($resource.lastModifiedDateTime)" | Out-File -Append -FilePath $OutFile
                }

                $allResults += $tableData
                $count += 1
            }
        }
    }
    return $allResults
}

<#
    .DESCRIPTION
    The Search-FilesWithGraphAPI function performs a search query (https://learn.microsoft.com/en-us/graph/search-concept-files).
    It search OneDrive and SharePoint content for a specific text (Query) and returns the results.
    If no URL is provided, this method requires Sites.Read.All or Sites.ReadWrite.All.
#>
function Search-FilesWithGraphAPI {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Query,

        [Parameter(Mandatory = $true)]
        [string]$Token,

        [Parameter(Mandatory = $false)]
        [string]$Region = "",

        [Parameter(Mandatory = $false)]
        [string]$URL,

        [Parameter(Mandatory = $false)]
        [string]$OutFile = $null,

        [Parameter(Mandatory = $false)]
        [bool]$Recursive,

        [Parameter(Mandatory = $true)]
        [bool]$DebugMode
    )

    $headers = @{
        "Authorization" = "Bearer $Token"
        "Content-Type"  = "application/json"
    }

    $allResults = @()
    $searchUrl = "https://graph.microsoft.com/v1.0/search/query"
    $from = 0
    $size = 500
    $moreResults = $true
    $count = 0

    while ($moreResults) {
        $request = @{
            entityTypes = @("driveItem")
            query       = @{ queryString = if ($URL) { "$Query path:`"$URL`"" } else { $Query } }
            region      = $Region
            from        = $from
            size        = $size
            fields      = @("id", "parentReference", "name", "summary", "webUrl", "lastModifiedDateTime", "size")
            sortProperties = @(@{ name = "lastModifiedDateTime"; isDescending = $true })
        }

        if (-not $URL) {
            $request.sharePointOneDriveOptions = @{
                includeHiddenContent = $true
                includeContent       = "privateContent,sharedContent"
            }
            $request.entityTypes += "listItem", "list"
        }

        $payload = @{ requests = @($request) } | ConvertTo-Json -Depth 10

        try {
            $response = Invoke-RestMethod -Uri $searchUrl -Method Post -Headers $headers -Body $payload
        } catch {
            if ($DebugMode) { Write-Host "[DEBUG] An error occurred: $($_.Exception.Message)." -ForegroundColor Red }
            break
        }

        if ($response.value -and $response.value[0].hitsContainers) {
            $hitsContainer = $response.value[0].hitsContainers[0]
            $hits = $hitsContainer.hits

            foreach ($hit in $hits) {
                $resource = $hit.resource
                $tableData = [PSCustomObject]@{
                    ArrayID              = $count
                    Name                 = $resource.name
                    ID                   = $resource.id
                    DriveID              = $resource.parentReference.driveId
                    WebUrl               = $resource.webUrl
                    LastModifiedDateTime = $resource.lastModifiedDateTime
                    Size                 = $resource.size
                    Summary              = $hit.summary
                }

                Write-Host "[" $count "]" $resource.name -ForegroundColor Green
                Write-Host "`tURL: $($resource.webUrl)"
                Write-Host "`tLastModifiedDateTime: $($resource.lastModifiedDateTime)"
                Write-Host "`tDriveID & ItemID: $($resource.parentReference.driveId) $($resource.id)"
                Write-Host "`tSummary: $($hit.summary)"

                if ($OutFile) {
                    Write-Output "[ $count ] " $resource.name | Out-File -Append -FilePath $OutFile -NoNewline
                    Write-Output "`tURL: $($resource.webUrl)" | Out-File -Append -FilePath $OutFile
                    Write-Output "`tLastModifiedDateTime: $($resource.lastModifiedDateTime)" | Out-File -Append -FilePath $OutFile
                    Write-Output "`tDriveID & ItemID: $($resource.parentReference.driveId) $($resource.id)" | Out-File -Append -FilePath $OutFile
                    Write-Output "`tSummary: $($hit.summary)" | Out-File -Append -FilePath $OutFile
                }

                $allResults += $tableData
                $count++
            }

            if ($Recursive) {
                $moreResults = $hitsContainer.moreResultsAvailable
                $from += $size
            } else { break }    
        } else {
            if ($DebugMode) { Write-Host "[DEBUG] No hitsContainers found." -ForegroundColor Yellow }
            break
        }
    }

    return $allResults
}

<#
    .DESCRIPTION
    The Get-DriveItemsWithGraphAPI function performs a search query (https://learn.microsoft.com/en-us/graph/search-concept-files).
    It lists driveItems of a specific drive and returns the results.
#>
function Get-DriveItemsWithGraphAPI {
    param (
        [Parameter(Mandatory = $true)]
        [string]$URL,

        [Parameter(Mandatory = $true)]
        [string]$Token,

        [Parameter(Mandatory = $false)]
        [string]$Region = "",

        [Parameter(Mandatory = $true)]
        [bool]$DebugMode
    )

    $headers = @{
        "Authorization" = "Bearer $Token"
        "Content-Type"  = "application/json"
    }
    $allResults = @()

    # Search payload
    $jsonPayload = @"
{
    "requests": [
        {
            "entityTypes": [
                "driveItem"
            ],
            "query": {
                "queryString": "path: \"$URL\"",
            },
            "region": "$Region",
            "from": 0,
            "size": 500,
            "fields": [
                "id",
                "parentReference",
                "name",
                "summary",
                "webUrl",
                "lastModifiedDateTime",
                "size"
            ],
            "sortProperties": [
                {
                    "name": "lastModifiedDateTime",
                    "isDescending": true
                }
            ]
        }
    ]
}
"@
    # Perform the search request
    try {
        $response = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/search/query" -Method Post -Headers $headers -Body $jsonPayload
    } catch {
        # Handle specific HTTP errors
        if ($DebugMode) { Write-Host "[DEBUG] An error occurred: $($_.Exception.Message)." -ForegroundColor Red }  
        return $null
    }
    
    # Check results
    if ($response.value -and $response.value.hitsContainers) {
        $hitsContainers = $response.value.hitsContainers
        $count = 0
        foreach ($hitsContainer in $hitsContainers) {
            $hits = $hitsContainer.hits
            foreach ($hit in $hits) {
                $resource = $hit.resource
                $tableData = [PSCustomObject]@{
                    ArrayID               = $count
                    Name                  = $resource.name
                    ID                    = $resource.id
                    DriveID               = $resource.parentReference.driveId
                    WebUrl                = $resource.webUrl
                    LastModifiedDateTime  = $resource.lastModifiedDateTime
                    Size                  = $resource.size
                    Summary               = $hit.summary
                }
                Write-Host "[" $count "]" $resource.webUrl -ForegroundColor Green
                Write-Host "`tDriveID & ItemID: $($resource.parentReference.driveId) $($resource.id)"
                $allResults += $tableData
                $count += 1
            }
        }
    } elseif ($DebugMode) {
        Write-Host "[DEBUG] Invalid or empty response." -ForegroundColor Red
    }

    return $allResults
}

<#
    .DESCRIPTION
    The Get-FileInformationWithGraphAPI function retrieves information about a specific driveItem.
    It requires the parent DriveId and the DriveItemId.
    Doc: https://learn.microsoft.com/en-us/graph/api/driveitem-search?view=graph-rest-1.0&tabs=http
#>
function Get-FileInformationWithGraphAPI {
    param (
        [Parameter(Mandatory = $true)]
        [string]$DriveId,

        [Parameter(Mandatory = $true)]
        [string]$DriveItemId,

        [Parameter(Mandatory = $true)]
        [string]$Token,

        [Parameter(Mandatory = $true)]
        [bool]$DebugMode
    )

    $headers = @{
        "Authorization" = "Bearer $Token"
        "Content-Type"  = "application/json"
    }

    # Perform the get request
    try {
        $response = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/drives/$DriveId/items/$DriveItemId" -Headers $headers
    } catch {
        # Handle specific HTTP errors
        if ($DebugMode) { Write-Host "[DEBUG] An error occurred: $($_.Exception.Message)." -ForegroundColor Red }
        return $null
    }

    return $response
}

<#
    .DESCRIPTION
    The Get-FileWithGraphAPI function download the content of a specific driveItem.
    It requires the parent DriveId and the DriveItemId.
    Doc: https://learn.microsoft.com/en-us/graph/api/driveitem-get-content?view=graph-rest-1.0&tabs=http
#>
function Get-FileWithGraphAPI {
    param (
        [Parameter(Mandatory = $true)]
        [string]$DriveId,

        [Parameter(Mandatory = $true)]
        [string]$DriveItemId,

        [Parameter(Mandatory = $false)]
        [string]$Size = $null,

        [Parameter(Mandatory = $false)]
        [string]$OutFile = $null,
        
        [Parameter(Mandatory = $false)]
        [string]$Folder = $null,

        [Parameter(Mandatory = $true)]
        [string]$Token,

        [Parameter(Mandatory = $true)]
        [bool]$DebugMode
    )

    $headers = @{
        "Authorization" = "Bearer $Token"
    }

    # If the name and the size of the file to download are not passed as arguments, file information is retrieved before download
    if (-not $OutFile -and -not $Size) {
        $file = Get-FileInformationWithGraphAPI -DriveId $DriveId -DriveItemId $DriveItemId -Token $Token -DebugMode $DebugMode
        $OutFile = $file.name
        $Size = $file.size
    }

    # If the size is null or equal to 0, the download operation is not launched.
    if (-not $Size -or $Size -eq 0) {
        if ($DebugMode) { Write-Host "[DEBUG] Seems to be a folder or an empty file.`n" -ForegroundColor Yellow }
        return $null
    }

    # Perform the download request
    try {
        Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/drives/$DriveId/items/$DriveItemId/content" -Headers $headers -OutFile "$Folder$OutFile"
        Write-Host "File downloaded successfully: $Folder$OutFile" -ForegroundColor Green
    } catch {
        # Handle specific HTTP errors
        if ($DebugMode) { Write-Host "[DEBUG] An error occurred: $($_.Exception.Message)." -ForegroundColor Red }
        return $null
    }

    return $true
}

if ($TenantId -and $ClientId -and $ClientSecret) {
    Open-InteractiveShell -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret -Region $Region -OutFile $OutFile -Folder $Folder -DebugMode $DebugMode
} elseif ($TenantId -and $ClientId -and $CertificateThumbprint) {
    Open-InteractiveShell -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -Region $Region -OutFile $OutFile -Folder $Folder -DebugMode $DebugMode
} elseif ($AccessToken) {
    Open-InteractiveShell -AccessToken $AccessToken -Region $Region -OutFile $OutFile -Folder $Folder -DebugMode $DebugMode
} else {
    Open-InteractiveShell -Region $Region -OutFile $OutFile -Folder $Folder -DebugMode $DebugMode
}
