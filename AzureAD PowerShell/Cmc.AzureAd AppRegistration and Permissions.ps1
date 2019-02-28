# This scripts will facilitate creation of App Registration for Campus Nexus Web Apps
# Once applications are registered this script does not need to be re-run with each upgrade

#  ====== ********* STARTS - UPDATE ENVIRONMENT SPECIFIC VALUES *********  ====== 


#  Update name and URL of each application 

$webapps = new-object System.Collections.Hashtable
$webapps.Add("Cmc.AdminConsole","http://adminconsoleurl/")
$webapps.Add("Cmc.ConfigTool","http://configtoolurl/")
$webapps.Add("Cmc.FbDesigner","http://FbDesignerUrl/")
$webapps.Add("Cmc.FbRenderer","http://apply.myuniversity.edu/")
$webapps.Add("Cmc.CrmWebClient","http://CrmWebClientUrl/")
$webapps.Add("Cmc.CrmWorkspace","http://CrmWorkspaceUrl/")

$portalAppName = "Cmc.Portal MyUniversity"
$portalAppURI = "https://portal.myuniversity.edu/"
 
$cnsWebAppName = "Cmc.CampusNexus Web MyUniversity"
$studentWebClientAppURI = "http://webclient.myuniversity.edu/"

#  ====== ********* ENDS - UPDATE ENVIRONMENT SPECIFIC VALUES *********  ======

$logfile = "App Registration Log-$(get-date -f yyyy-MM-dd).txt"
"------------ App registartion Begin $(Get-Date) ------------" >> $logfile

Write-Host "App registration will be created for following web apps" -ForegroundColor Green
foreach ($h in $webapps.GetEnumerator()) {
    Write-Host "  $($h.Name): $($h.Value)"
}
Write-Host "  $($portalAppName): $($portalAppURI)"
Write-Host "  $($cnsWebAppName): $($studentWebClientAppURI)"

Write-Host "`nPress any key to continue or CTRL+C to quit: "  -ForegroundColor Green -NoNewline
Read-Host 

#Install Azure-Module if necessary
if (!(Get-Module -ListAvailable -Name AzureAD*)) {
	if(!(([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544"))
	{
		Write-Host "Not running as admin, please restart PowerShell in Administrator Mode."  -ForegroundColor Red -BackgroundColor White
		exit
	}
	Write-Host "Installing AzureAD module `n"
	"Installing AzureAD module `n" >> $logfile
    Install-Module AzureAD
}

# ====== 1. Connect with your AzureAD (replace tenantid) ======
Connect-AzureAD 
$currentSession = Get-AzureADCurrentSessionInfo
Write-Host "Logged in as $($currentSession.Account) in Tenant $($currentSession.TenantId) `n"
"Logged in as $($currentSession.Account) in Tenant $($currentSession.TenantId) `n" >> $logfile

# ====== 2. Define Global permission set to be used by all Apps ======

#Windows Azure Active Directory
$winAdSvcPrincipal = Get-AzureADServicePrincipal -All $true | ? { $_.DisplayName -match "Windows Azure Active Directory" }
$reqWinAd = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess"
$reqWinAd.ResourceAppId = $winAdSvcPrincipal.AppId

#Sign you in and read your profile
$delPermission3 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "311a71cc-e848-46a1-bdf8-97ff7156d8e6","Scope" #Sign you in and read your profile
$reqWinAd.ResourceAccess = $delPermission3

# ====== 3. App Registration for all the apps except Portal and WebClient  ======
foreach ($h in $webapps.GetEnumerator()) {
    Write-Host "Registering: - $($h.Name): $($h.Value)"  -ForegroundColor Green 
	$appName = $h.Name
	$appURI = $h.Value
	$appReplyURLs = @($appURI)
	
	if(!($myApp = Get-AzureADApplication -Filter "DisplayName eq '$($appName)'"  -ErrorAction SilentlyContinue))
	{
		$myApp = New-AzureADApplication -DisplayName $appName -IdentifierUris $appURI -Homepage $appURI -ReplyUrls $appReplyURLs -RequiredResourceAccess $reqWinAd
		$AppDetailsOutput = "App registration for $appName is successful. App Id: $($myApp.AppId)"
		Write-Host $AppDetailsOutput
		Write-Host
		$AppDetailsOutput >> $logfile
	}
	else{
		"Web App already present with name $($appName)" >> $logfile
		Remove-AzureADApplication -ObjectId $myApp.ObjectId
		Write-Host "Web App already present with name $($appName)" -ForegroundColor Red -BackgroundColor White
	}
}

#  ====== 4. App Registration for WebClient  ======

#Register CampusNexus Student WebClient App
$appReplyURL1 = $studentWebClientAppURI+"Account/ExternalLoginCallback?loginProvider=Azure&returnUrl="
$appReplyURL2 =$studentWebClientAppURI+"Account/OAuthTokenRedirect"

if(!($myApp = Get-AzureADApplication -Filter "DisplayName eq '$($cnsWebAppName)'"  -ErrorAction SilentlyContinue))
{
	#Prepare permission set
	$permSet = New-Object System.Collections.ArrayList
	$permSet.Add($reqWinAd)

	# Add PowerBI permissions if enabled
	$PowerBiSvcPrincipal = Get-AzureADServicePrincipal -All $true | ? { $_.DisplayName -match "Power BI Service" }
	if($PowerBiSvcPrincipal){
		$reqPowerBI = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess"
		$reqPowerBI.ResourceAppId = $PowerBiSvcPrincipal.AppId

		#Delegated Permissions
		#Access PowerBI workspaces as signed in user
		$powerBidelPermission1 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "b2f1b2fa-f35c-407c-979c-a858a808ba85","Scope" #View all workspaces
		$powerBidelPermission2 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "4ae1bf56-f562-4747-b7bc-2fa0874ed46f","Scope" #View all Reports (preview)
		$powerBidelPermission3 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "2448370f-f988-42cd-909c-6528efd67c1a","Scope" #View all Dashboards (preview)
	
		$reqPowerBI.ResourceAccess = $powerBidelPermission1,$powerBidelPermission2,$powerBidelPermission3
		$permSet.Add($reqPowerBI)
	} else {
		$msg = "Cannot add PowerBI permissions to CampusNexus Student registration."
		Write-Host $msg -ForegroundColor Red 
		$msg >> $logfile
	}
	
	# Microsoft Graph Permissions to be used by User sync service
	$GraphSvcPrincipal = Get-AzureADServicePrincipal -All $true | ? { $_.DisplayName -match "Microsoft Graph" }
	if($GraphSvcPrincipal) {
		$reqGraph = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess"
		$reqGraph.ResourceAppId = $GraphSvcPrincipal.AppId

		##Delegated Permissions
		#$delPermission1 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "0e263e50-5827-48a4-b97c-d940288653c7","Scope" #Access Directory as the signed in user

		##Application Permissions
		$appPermissionReadDirData = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "7ab1d382-f21e-4acd-a863-ba3e13f7da61","Role" #Read directory data
		$reqGraph.ResourceAccess = $appPermissionReadDirData
		$permSet.Add($reqGraph)
	} else {
		$msg = "Cannot add Microsoft Graph permissions to CampusNexus Student registration. User sync service will fail without this permission"
		Write-Host $msg -ForegroundColor Red 
		$msg >> $logfile
	}

	#Generate client secrete
	$Guid = New-Guid
	$startDate = Get-Date
		
	$PasswordCredential = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordCredential
	$PasswordCredential.StartDate = $startDate
	$PasswordCredential.EndDate = $startDate.AddYears(5)
	$PasswordCredential.KeyId = $Guid
	$PasswordCredential.Value = ([System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(($Guid))))+"="
	
	Write-Host "Registering: - $($cnsWebAppName): $($studentWebClientAppURI)"  -ForegroundColor Green 
	
    $myApp = New-AzureADApplication -DisplayName $cnsWebAppName -IdentifierUris $studentWebClientAppURI -Homepage $studentWebClientAppURI -ReplyUrls @($appReplyURL1,$appReplyURL2) -PasswordCredentials $PasswordCredential -RequiredResourceAccess $permSet
	$AppDetailsOutput = "Application Details for the $cnsWebAppName application:
=========================================================
Application Name: 	$cnsWebAppName
Application Id:   	$($myApp.AppId)
Secret Key:       	$($PasswordCredential.Value)
	
*** ATTENTION: 
Copy following URL in browser and complete admin consent:
https://login.microsoftonline.com/common/adminconsent?client_id=$($myApp.AppId)&state=12345&redirect_uri=$($appReplyURL2)
"
	Write-Host $AppDetailsOutput
	Write-Host
	$AppDetailsOutput | Add-Content -Path "$($cnsWebAppName).txt", $logfile
}
else
{
	Remove-AzureADApplication -ObjectId $myApp.ObjectId
	Write-Host "Web App already present with name $($cnsWebAppName)", $logfile -ForegroundColor Red -BackgroundColor White
}

#  ====== 5. App Registration for Portal  ======
#Register App
$appReplyURLs = @($portalAppURI)

if(!($myApp = Get-AzureADApplication -Filter "DisplayName eq '$($portalAppName)'"  -ErrorAction SilentlyContinue))
{
	#Prepare permission set
	
	# Microsoft Graph
	$GraphSvcPrincipal = Get-AzureADServicePrincipal -All $true | ? { $_.DisplayName -match "Microsoft Graph" }
	$reqGraph = New-Object -TypeName "Microsoft.Open.AzureAD.Model.RequiredResourceAccess"
	$reqGraph.ResourceAppId = $GraphSvcPrincipal.AppId

	##Delegated Permissions
	#$delPermission1 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "0e263e50-5827-48a4-b97c-d940288653c7","Scope" #Access Directory as the signed in user

	##Application Permissions
	$appPermission1 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "19dbc75e-c2e2-444c-a770-ec69d8559fc7","Role" #Read and write directory data
	$appPermission2 = New-Object -TypeName "Microsoft.Open.AzureAD.Model.ResourceAccess" -ArgumentList "741f803b-c850-494e-b5df-cde7c675a1ca","Role" #Read and write all users' full profiles

	$reqGraph.ResourceAccess = $appPermission1, $appPermission2 #$delPermission1, 

	#Generate client secrete
	$Guid = New-Guid
	$startDate = Get-Date
		
	$PasswordCredential = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordCredential
	$PasswordCredential.StartDate = $startDate
	$PasswordCredential.EndDate = $startDate.AddYears(5)
	$PasswordCredential.KeyId = $Guid
	$PasswordCredential.Value = ([System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(($Guid))))+"="

	Write-Host "Registering: - $($portalAppName): $($portalAppURI)"  -ForegroundColor Green 
	
    $myApp = New-AzureADApplication -DisplayName $portalAppName -IdentifierUris $portalAppURI -Homepage $portalAppURI -ReplyUrls $appReplyURLs -PasswordCredentials $PasswordCredential -RequiredResourceAccess @($reqWinAd, $reqGraph)
	$AppDetailsOutput = "Application Details for the $portalAppName application:
=========================================================
Application Name: 	$portalAppName
Application Id:   	$($myApp.AppId)
Secret Key:       	$($PasswordCredential.Value)

*** ATTENTION: 
Copy following URL in browser and complete admin consent:
https://login.microsoftonline.com/common/adminconsent?client_id=$($myApp.AppId)&state=12345&redirect_uri=$($portalAppURI)
"
	Write-Host $AppDetailsOutput
	$AppDetailsOutput | Add-Content -Path "$($portalAppName).txt",$logfile 
	#$myApp | Add-Content -Path "$($portalAppName).txt",$logfile

}
else
{
	Remove-AzureADApplication -ObjectId $myApp.ObjectId
	Write-Host "Web App already present with name $($portalAppName)" -ForegroundColor Red -BackgroundColor White
}
"------------ App registartion End $(Get-Date) ------------" >> $logfile
Write-Host "Log is available at '$($logfile)'" -ForegroundColor Green