# SharePwned

### SharePwned is a PowerShell script that allows exploration of SharePoint sites and OneDrive drives using the Microsoft Graph API.  
By Nathan HAMARD, member of Wavestone's Red Team.

---

## Features

- Authenticate to Microsoft Graph with Client Credentials or Access Token
- Interactive shell interface (CLI)
- Search for SharePoint and OneDrive files
- List drive and folder contents
- Download files individually
- Navigate through SharePoint/OneDrive folders (cd command)
- Configure output folder and logfile
- Support for multiple Microsoft regions
- Debug mode for troubleshooting

---

## Requirements

Before using **SharePwned**, ensure you meet the following requirements:

- **PowerShell Version:**  
  PowerShell 5.1 or later.

- **Microsoft Graph API Access:**  
  A registered application in Azure Active Directory with the following **Application Permissions**:
  - `Sites.Read.All` (best option: recommended for a stealthier `search_all` feature)
  <br>**or**<br>
  - `Directory.Read.All` (to list users and their OneDrive)
  - `Files.Read.All` (to explore OneDrive content)
  - `Sites.FullControl` (to explore SharePoint content)

- **Region Awareness:**  
  If your tenant spans multiple regions, you must specify the correct region using the `-Region` parameter (e.g., `FRA`, `NAM`, `EUR`, `EMEA`).

---

## Usage

Authenticate and launch the interactive shell by providing your Azure credentials:

```powershell
PS C:\> .\SharePwned.ps1 -TenantId '<TenantId>' -ClientId '<ClientId>' -ClientSecret '<ClientSecret>' -Region 'FRA'

```

Once the access token expires, a new authentication request is automatically sent.
However, if you exit the CLI before token expiration or if you already have a valid access token, you can use it to avoid re-authenticating:

```powershell
PS C:\script> .\SharePwned.ps1 -AccessToken '[...]' -Region 'FRA'
```

To get help once the script is run, type `help`.

## Search for SharePoint and OneDrive Content
SharePwned offers two main search options using Microsoft Graph's Search API:

### `search` – Targeted Search

The `search` command allows you to query specific SharePoint sites or OneDrive drives that your application can access.
```powershell
$ > search <query> [<path>]
```

Example of search in all OneDrive:
```powershell
$ > search password https://xxxxxxxx-my.sharepoint.com/personal/
```

### `search_all` – Broad Search Across the Tenant

The `search_all` command performs a global search across all available SharePoint and OneDrive content within the specified Microsoft region.
```powershell
$ > search_all <query>
```

Example:
```powershell
$ > search_all password
```

> ⚠️ **Warning**  
> Without `Sites.Read.All` permission, the search_all feature will try to:
> 1. List users
> 2. Perform a search request in each OneDrive drive
> 3. List SharePoint sites
> 4. Perform a search request in each SharePoint site


## Download a file
You can download files using two different methods:

Method 1. Using the array ID returned by the last search request:

```powershell
$ > download <ArrayId>
```

Method 2. Using the `DriveId` and `ItemId` corresponding to a specific file

```powershell
$ > download <DriveId> <ItemId>
```

You can configure an output folder for downloaded files using the `folder` command.

## Log outputs
This feature allows you to write all search results to a file.
You can later refer to these logs to retrieve specific files without having to perform another search.

## Example Workflow
```powershell
PS C:\> .\SharePwned.ps1 -TenantId '<TenantId>' -ClientId '<ClientId>' -ClientSecret '<ClientSecret>' -Region 'EUR'

$ > search_all password
$ > download 3
$ > cd https://xxxxxxxx.sharepoint.com/sites/DSI/Shared Documents/
$ > search token
$ > download 2
$ > exit
```

## Microsoft documentation - Search API in Microsoft Graph
You can find the [Microsoft documentation](https://learn.microsoft.com/en-us/graph/search-concept-files#example-4-search-all-content-in-onedrive-and-sharepoint) about the Graph API search feature for OneDrive and SharePoint content. 

Please note: [Searching with application permission is limited to a single geographic region](https://learn.microsoft.com/en-us/graph/search-concept-searchall). You must usually specify a region (e.g., FRA, EUR, NAM, etc).

## Contributing
We are always looking for contributors!
Please submit a pull request if you would like to contribute.

## Wavestone article
The following [RiskInsight article](https://www.riskinsight-wavestone.com/) provides a real-life example of this tool used during a Red Team operation.
