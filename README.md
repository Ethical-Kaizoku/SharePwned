# SharePwned

### SharePwned is a PowerShell script which enables to explore SharePoint sites and OneDrive drives using Microsoft Graph API.
By Nathan HAMARD, member of Wavestone's Red Team.

### Usage

Simple script usage by providing a TenantId, ClientId and ClientSecret
An access token is retrieved by requesting https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token. The access token is displayed if the debug mode is enabled.

```powershell
PS C:\script> .\SharePwned.ps1 -TenantId '[...]' -ClientId '[...]' -ClientSecret '[...]' -Region 'FRA'
```

Once the access token is expired, a new authentication request is automatically sent.
However, if you quit the CLI before the token expiration, you can still use it to avoid another authentication process.

```powershell
PS C:\script> .\SharePwned.ps1 -AccessToken '[...]' -Region 'FRA'
```

To get help once the script is run, type `help`.

### Search for SharePoint and OneDrive Content
TODO

### Download a file
This tool allows to download files through two different methods.

Method 1. Using the array ID returned by the last search request performed

```powershell
$ > download <ArrayId>
```

Method 2. Using the `DriveId` and `ItemId` refering to a specific file

```powershell
$ > download <DriveId> <ItemId>
```

To configure an output folder for the downloaded files, you can use the `folder` command. 

### Log outputs
This feature enables to write all the search results in a file.
That way, you can still look into the logs to get a specific file back without performing a search request again.

### Microsoft documentation - Search API in Microsoft Graph
You can find the [Microsoft documentation](https://learn.microsoft.com/en-us/graph/search-concept-files#example-4-search-all-content-in-onedrive-and-sharepoint) about the Graph API search feature. It allows to search OneDrive and SharePoint content. 

Please also note that performing [a search with application permission is limited to one geographic region](https://learn.microsoft.com/en-us/graph/search-concept-searchall). In most cases, a region must be specified (FRA, EUR, NAM, etc).

### Contributing
We are always looking for contributors to this script. Please submit requests if you want to contribute.

### Wavestone article
The following [RiskInsight article](https://www.riskinsight-wavestone.com/) gives a real-life example of this tool used during a Red Team operation.