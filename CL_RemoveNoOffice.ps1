﻿# Copyright © 2016, Microsoft Corporation. All rights reserved.
#============================================================= 
<#
CL_RemoveNoOffice.ps1 removes all the left out components of office.

Arguments:
None

Return values:
None
 
#>
PARAM($commonFilesRegx86,$commonFilesReg,$programFilesReg,$programFilesx86Reg,$count)
#*=================================================================================
# Load Utilities
#*=================================================================================
. .\CL_OfficeUninstall.ps1

#*=================================================================================
#Import localization data
#*=================================================================================
Import-LocalizedData -BindingVariable Strings_CL_RemoveNoOffice -FileName CL_RemoveNoOffice

#Get the size of the OSArchitecure to check whether the office installed in 32bit or 64 bit OS.
$osArchitecture = [IntPtr]::Size;
Function Remove-OfficeComponents($commonFilesRegx86,$commonFilesReg,$programFilesReg,$programFilesx86Reg,$count)
{
	<#
	Remove-Office2016
	Function description:
	Function to remove Office 2016 c2r..

	Arguments:
	$commonFilesRegx86: Office paths
	$commonFilesReg:Office common path
	$officeID:Office version ID
	Return values:
	None
	#>
	$officeIDLists = @("Office11","Office12","Office14","Office15","Office16")
	$OfficeRegIDs =  @("11.0", "12.0","14.0","15.0","16.0")
	$hkcrRegIds = @("Products","Features","UpgradeCodes")
	$hkcrGuidIds = @("*000061*","*000051*","*000021*","*000041*","*904011*")
	$officeVersionID = ""
	$themes = @("Themes11","Themes12","Themes14","Themes15","Themes16")
	$officeGuid = ""
	$officeGuidId = ""
    #Check the Office ID is c2r to stop the related services,processes.
	$services = @("Clicktorunsvc","osppsvc","ose","groove")
	$officec2r1516 = ""
	$dirLists = @()
	$regLists = @()
	$officeThemes = @()
	$officethemesX86 = @()
	$officecommonfilesx86 = @()
	$officecommonfiles = @()
	$hkcrkeys = @()
	$controlpanelregList = @()
	$customPath = @()
	foreach($service in $services)
	{
		Stop-Service -Name $service -ErrorAction SilentlyContinue
	}
	$processList = @("Officeclicktorun","appvshnotify","firstrun","msiexec")
	foreach($getprocesslist in $processList)
	{
		$process = Get-Process |?{$_.ProcessName -ieq $getprocesslist}
		if($process)
		{
			Stop-Process -Name $getprocesslist -force
		}
	}
	 #remove scheduled task...	
	try
	{
		$ScheduledTaskList = @("OfficeTelemetryAgentFallBack","OfficeTelemetryAgentLogOn","OfficeTelemetryAgentFallBack2016","OfficeTelemetryAgentLogOn2016","Office Automatic Updates","Office 15 Subscription Heartbeat","Office Subscription Maintenance","Office ClickToRun Service Monitor","SvcRestartTask")
		foreach($scheduler in $ScheduledTaskList)
		{
			SCHTASKS /Delete /TN  "Microsoft\Office\$scheduler" -f >nul
		}
	}
	catch
	{
		$_.error | Convertto-xml | Update-Diagreport  -id "RS_MultipleOffice" -name "Error: $_.error" -Verbosity Informational
	}
	
	#Assign required values and empty arrays
	foreach($theme in $themes)
	{
		$officeThemes += $commonFilesReg  + "\microsoft shared\$theme"
		$officethemesX86 += $commonFilesRegx86  + "\microsoft shared\$theme"
	}
	foreach($officeID in $officeIDLists)
	{
		$officecommonfilesx86 += $commonFilesRegx86 + "\Microsoft Shared\$officeID"
		$officecommonfiles += $commonFilesReg + "\Microsoft Shared\$officeID"
	}
	$officestartMenushortcut2016 = $env:ProgramData + "\Microsoft\Windows\Start Menu\Programs"
	$officestartMenushortcutAll = $env:ProgramData + "\Microsoft\Windows\Start Menu\Programs\Microsoft Office"
	$officestartMenushortcut2013 = $env:ProgramData + "\Microsoft\Windows\Start Menu\Programs\Microsoft Office 2013"

	$officesoftwareProtectionx86 = $commonFilesRegx86 + "\Microsoft Shared\OfficeSoftwareProtectionPlatform"
	$officesoftwareProtection = $commonFilesReg + "\Microsoft Shared\OfficeSoftwareProtectionPlatform"
	$officesoftwareProtectionData = $env:ProgramData + "\Microsoft\OfficeSoftwareProtectionPlatform"
	$appV = $env:ProgramData + "\Microsoft\AppV"
	$clickToRun = $env:ProgramData + "\Microsoft\ClickToRun"
	$clickToRunShared = $commonFilesReg + "\Microsoft Shared\ClickToRun"
	$clickToRunSharedx86 = $commonFilesRegx86 + "\Microsoft Shared\ClickToRun"
	$office15 = "$programFilesReg\Microsoft Office 15"
	$office15x86 = "$programFilesx86Reg\Microsoft Office 15"
	$clickToRunSvc = "HKLM:\SYSTEM\CurrentControlSet\Services\ClickToRunSvc"
	$osppsvc = "HKLM:\SYSTEM\CurrentControlSet\Services\osppsvc"
	$ose64 = "HKLM:\SYSTEM\CurrentControlSet\Services\ose64"
	$OfficesoftwareProtectionRegx86 = "SOFTWARE\WOW6432Node\Microsoft\OfficeSoftwareProtectionPlatform"
	$OfficesoftwareProtectionReg = "SOFTWARE\Microsoft\OfficeSoftwareProtectionPlatform"
	$deleteOfficePaths = @("$clickToRunSvc","$osppsvc","$ose64","$officesoftwareProtectionx86","$officesoftwareProtection","$officesoftwareProtectionData","$appV","$clickToRun","$office15","$office15x86","$clickToRunShared","$clickToRunSharedx86")

	#pin and unpin to taskbar is not supported in windows 10.
	if([Float]$OSVersion -lt [Float](10.0)) 
	{
		for($i = 0; $i -lt ($officeIDLists.Count) ; $i++)
		{
			Unpin-TaskBar $officeIDLists[$i] $OfficeRegIDs[$i]
		}			
	}
	#If the OS is 64bit then take the path as Wow6432Node and get the office files from control panel...
	if($osArchitecture -eq 8)
	{
		$officeControlPanelRegPath = "SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall" 
		#Call the function to get office reg keys from registry to delete office from control panel 
		$controlpanelregList += List-officeControlPanelRegistryKeys $officeGuid $officeGuidId $officeVersionID $officeControlPanelRegPath $officec2r1516 $officeIDLists $count
	}
	 #Call the function to get office reg keys from registry to delete office from control panel 
     $officeControlPanelRegPath = "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" 
	 $controlpanelregList += List-officeControlPanelRegistryKeys $officeGuid $officeGuidId $officeVersionID $officeControlPanelRegPath $officec2r1516 $officeIDLists $count
	#get HKCR office regkeys from registry	
	 foreach($hkcrID in $hkcrRegIds)
	 {
		 #Function to get HKCR products featurs Upgradecodes keys from registry
		  $hkcrkeys += List-HKCROfficeInstallerRegFiles $hkcrGuidIds $hkcrID
	 }
	 #Function to get the office files if custom installed...
	 $customPath = List-CustomInstallOfficeDirectory $OfficeRegIDs

	#Call the below function to get the list of Common regkeys for all office versions..
	$commonregistryList = List-CommonOfficeRegistry
	$hKLMofficeReg = $commonregistryList.registryHKLM
	$otherRegkeys = $commonregistryList.officeDirPath
	$regLists += $controlpanelregList
	$regLists += $hKLMofficeReg
	$regLists += $OfficesoftwareProtectionRegx86
	$regLists += $OfficesoftwareProtectionReg
	#Function to get the list of common directories for all office versions
	$commondirectoryList = List-CommonOfficeDirectory
	$dirLists += $otherRegkeys 
	$dirLists += $deleteOfficePaths
	$dirLists += $hkcrkeys
	$dirLists += $customPath
	$dirLists += $commondirectoryList
	$dirLists += $clickToRunShared
	$dirLists += $officeThemes
	$dirLists += $officeThemesx86
	$dirLists += $officecommonfilesx86
	$dirLists += $officecommonfiles
	Remove-OfficeRegistry $regLists "Common"
	Remove-RegistryInstallerFolderKey
	Remove-OfficeDirectory $dirLists
	Get-ChildItem $officestartMenushortcut2016 | Where-Object {$_.name -like "*2016*"} | Remove-Item -Recurse -Force 
}

#Call the function to remove all left out components of office if no offfice installed root cause detected...
Remove-OfficeComponents $commonFilesRegx86 $commonFilesReg $programFilesReg $programFilesx86Reg $count

# SIG # Begin signature block
# MIIdpAYJKoZIhvcNAQcCoIIdlTCCHZECAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUjJC2qz6ih9l0f2YcQX9V43kZ
# XPegghhkMIIEwzCCA6ugAwIBAgITMwAAAMWWQGBL9N6uLgAAAAAAxTANBgkqhkiG
# 9w0BAQUFADB3MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSEw
# HwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EwHhcNMTYwOTA3MTc1ODUy
# WhcNMTgwOTA3MTc1ODUyWjCBszELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjENMAsGA1UECxMETU9QUjEnMCUGA1UECxMebkNpcGhlciBEU0UgRVNO
# OkMwRjQtMzA4Ni1ERUY4MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBT
# ZXJ2aWNlMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAtrwz4CWOpvnw
# EBVOe1crKElrs3CQl/yun1cdkpugh/MxsuoGn7BL43GRTxRn7sPD7rq1Dxj4smPl
# gVZr/ZhGMA8J3zXOqyIcD4hYFikXuhlGuuSokunCAxUl5N4gjN/M7+NwJPm2JtYK
# ZLBdH5J/y+GIk7rQhpgbstpLOZf4GHgC8Myji7089O1uX2MCKFFU+wt2Y560O4Xc
# 2NVjeuG+nnq5pGyq9111nK3f0DeT7FWjDVQWFghKOhyeBb4iMhmkdA8vWpYmx6TN
# c+d35nSZcLc0EhSIVJkzEBYfwkrzxFaG/pgNJ9C4jm/zHgwWLZwQpU7K2fP15fGk
# BGplwNjr1wIDAQABo4IBCTCCAQUwHQYDVR0OBBYEFA4B9X87yXgCWEZxOwn8mnVX
# hjjEMB8GA1UdIwQYMBaAFCM0+NlSRnAK7UD7dvuzK7DDNbMPMFQGA1UdHwRNMEsw
# SaBHoEWGQ2h0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3Rz
# L01pY3Jvc29mdFRpbWVTdGFtcFBDQS5jcmwwWAYIKwYBBQUHAQEETDBKMEgGCCsG
# AQUFBzAChjxodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY3Jv
# c29mdFRpbWVTdGFtcFBDQS5jcnQwEwYDVR0lBAwwCgYIKwYBBQUHAwgwDQYJKoZI
# hvcNAQEFBQADggEBAAUS3tgSEzCpyuw21ySUAWvGltQxunyLUCaOf1dffUcG25oa
# OW/WuIFJs0lv8Py6TsOrulsx/4NTkIyXra/MsJvwczMX2s/vx6g63O3osQI85qHD
# dp8IMULGmry+oqPVTuvL7Bac905EqqGXGd9UY7y14FcKWBWJ28vjncTw8CW876pY
# 80nSm8hC/38M4RMGNEp7KGYxx5ZgGX3NpAVeUBio7XccXHEy7CSNmXm2V8ijeuGZ
# J9fIMkhiAWLEfKOgxGZ63s5yGwpMt2QE/6Py03uF+X2DHK76w3FQghqiUNPFC7uU
# o9poSfArmeLDuspkPAJ46db02bqNyRLP00bczzwwggYHMIID76ADAgECAgphFmg0
# AAAAAAAcMA0GCSqGSIb3DQEBBQUAMF8xEzARBgoJkiaJk/IsZAEZFgNjb20xGTAX
# BgoJkiaJk/IsZAEZFgltaWNyb3NvZnQxLTArBgNVBAMTJE1pY3Jvc29mdCBSb290
# IENlcnRpZmljYXRlIEF1dGhvcml0eTAeFw0wNzA0MDMxMjUzMDlaFw0yMTA0MDMx
# MzAzMDlaMHcxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xITAf
# BgNVBAMTGE1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQTCCASIwDQYJKoZIhvcNAQEB
# BQADggEPADCCAQoCggEBAJ+hbLHf20iSKnxrLhnhveLjxZlRI1Ctzt0YTiQP7tGn
# 0UytdDAgEesH1VSVFUmUG0KSrphcMCbaAGvoe73siQcP9w4EmPCJzB/LMySHnfL0
# Zxws/HvniB3q506jocEjU8qN+kXPCdBer9CwQgSi+aZsk2fXKNxGU7CG0OUoRi4n
# rIZPVVIM5AMs+2qQkDBuh/NZMJ36ftaXs+ghl3740hPzCLdTbVK0RZCfSABKR2YR
# JylmqJfk0waBSqL5hKcRRxQJgp+E7VV4/gGaHVAIhQAQMEbtt94jRrvELVSfrx54
# QTF3zJvfO4OToWECtR0Nsfz3m7IBziJLVP/5BcPCIAsCAwEAAaOCAaswggGnMA8G
# A1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFCM0+NlSRnAK7UD7dvuzK7DDNbMPMAsG
# A1UdDwQEAwIBhjAQBgkrBgEEAYI3FQEEAwIBADCBmAYDVR0jBIGQMIGNgBQOrIJg
# QFYnl+UlE/wq4QpTlVnkpKFjpGEwXzETMBEGCgmSJomT8ixkARkWA2NvbTEZMBcG
# CgmSJomT8ixkARkWCW1pY3Jvc29mdDEtMCsGA1UEAxMkTWljcm9zb2Z0IFJvb3Qg
# Q2VydGlmaWNhdGUgQXV0aG9yaXR5ghB5rRahSqClrUxzWPQHEy5lMFAGA1UdHwRJ
# MEcwRaBDoEGGP2h0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1
# Y3RzL21pY3Jvc29mdHJvb3RjZXJ0LmNybDBUBggrBgEFBQcBAQRIMEYwRAYIKwYB
# BQUHMAKGOGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2VydHMvTWljcm9z
# b2Z0Um9vdENlcnQuY3J0MBMGA1UdJQQMMAoGCCsGAQUFBwMIMA0GCSqGSIb3DQEB
# BQUAA4ICAQAQl4rDXANENt3ptK132855UU0BsS50cVttDBOrzr57j7gu1BKijG1i
# uFcCy04gE1CZ3XpA4le7r1iaHOEdAYasu3jyi9DsOwHu4r6PCgXIjUji8FMV3U+r
# kuTnjWrVgMHmlPIGL4UD6ZEqJCJw+/b85HiZLg33B+JwvBhOnY5rCnKVuKE5nGct
# xVEO6mJcPxaYiyA/4gcaMvnMMUp2MT0rcgvI6nA9/4UKE9/CCmGO8Ne4F+tOi3/F
# NSteo7/rvH0LQnvUU3Ih7jDKu3hlXFsBFwoUDtLaFJj1PLlmWLMtL+f5hYbMUVbo
# nXCUbKw5TNT2eb+qGHpiKe+imyk0BncaYsk9Hm0fgvALxyy7z0Oz5fnsfbXjpKh0
# NbhOxXEjEiZ2CzxSjHFaRkMUvLOzsE1nyJ9C/4B5IYCeFTBm6EISXhrIniIh0EPp
# K+m79EjMLNTYMoBMJipIJF9a6lbvpt6Znco6b72BJ3QGEe52Ib+bgsEnVLaxaj2J
# oXZhtG6hE6a/qkfwEm/9ijJssv7fUciMI8lmvZ0dhxJkAj0tr1mPuOQh5bWwymO0
# eFQF1EEuUKyUsKV4q7OglnUa2ZKHE3UiLzKoCG6gW4wlv6DvhMoh1useT8ma7kng
# 9wFlb4kLfchpyOZu6qeXzjEp/w7FW1zYTRuh2Povnj8uVRZryROj/TCCBhAwggP4
# oAMCAQICEzMAAABkR4SUhttBGTgAAAAAAGQwDQYJKoZIhvcNAQELBQAwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMTAeFw0xNTEwMjgyMDMxNDZaFw0xNzAx
# MjgyMDMxNDZaMIGDMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQ
# MA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9u
# MQ0wCwYDVQQLEwRNT1BSMR4wHAYDVQQDExVNaWNyb3NvZnQgQ29ycG9yYXRpb24w
# ggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCTLtrY5j6Y2RsPZF9NqFhN
# FDv3eoT8PBExOu+JwkotQaVIXd0Snu+rZig01X0qVXtMTYrywPGy01IVi7azCLiL
# UAvdf/tqCaDcZwTE8d+8dRggQL54LJlW3e71Lt0+QvlaHzCuARSKsIK1UaDibWX+
# 9xgKjTBtTTqnxfM2Le5fLKCSALEcTOLL9/8kJX/Xj8Ddl27Oshe2xxxEpyTKfoHm
# 5jG5FtldPtFo7r7NSNCGLK7cDiHBwIrD7huTWRP2xjuAchiIU/urvzA+oHe9Uoi/
# etjosJOtoRuM1H6mEFAQvuHIHGT6hy77xEdmFsCEezavX7qFRGwCDy3gsA4boj4l
# AgMBAAGjggF/MIIBezAfBgNVHSUEGDAWBggrBgEFBQcDAwYKKwYBBAGCN0wIATAd
# BgNVHQ4EFgQUWFZxBPC9uzP1g2jM54BG91ev0iIwUQYDVR0RBEowSKRGMEQxDTAL
# BgNVBAsTBE1PUFIxMzAxBgNVBAUTKjMxNjQyKzQ5ZThjM2YzLTIzNTktNDdmNi1h
# M2JlLTZjOGM0NzUxYzRiNjAfBgNVHSMEGDAWgBRIbmTlUAXTgqoXNzcitW2oynUC
# lTBUBgNVHR8ETTBLMEmgR6BFhkNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtp
# b3BzL2NybC9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3JsMGEGCCsGAQUF
# BwEBBFUwUzBRBggrBgEFBQcwAoZFaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3Br
# aW9wcy9jZXJ0cy9NaWNDb2RTaWdQQ0EyMDExXzIwMTEtMDctMDguY3J0MAwGA1Ud
# EwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggIBAIjiDGRDHd1crow7hSS1nUDWvWas
# W1c12fToOsBFmRBN27SQ5Mt2UYEJ8LOTTfT1EuS9SCcUqm8t12uD1ManefzTJRtG
# ynYCiDKuUFT6A/mCAcWLs2MYSmPlsf4UOwzD0/KAuDwl6WCy8FW53DVKBS3rbmdj
# vDW+vCT5wN3nxO8DIlAUBbXMn7TJKAH2W7a/CDQ0p607Ivt3F7cqhEtrO1Rypehh
# bkKQj4y/ebwc56qWHJ8VNjE8HlhfJAk8pAliHzML1v3QlctPutozuZD3jKAO4WaV
# qJn5BJRHddW6l0SeCuZmBQHmNfXcz4+XZW/s88VTfGWjdSGPXC26k0LzV6mjEaEn
# S1G4t0RqMP90JnTEieJ6xFcIpILgcIvcEydLBVe0iiP9AXKYVjAPn6wBm69FKCQr
# IPWsMDsw9wQjaL8GHk4wCj0CmnixHQanTj2hKRc2G9GL9q7tAbo0kFNIFs0EYkbx
# Cn7lBOEqhBSTyaPS6CvjJZGwD0lNuapXDu72y4Hk4pgExQ3iEv/Ij5oVWwT8okie
# +fFLNcnVgeRrjkANgwoAyX58t0iqbefHqsg3RGSgMBu9MABcZ6FQKwih3Tj0DVPc
# gnJQle3c6xN3dZpuEgFcgJh/EyDXSdppZzJR4+Bbf5XA/Rcsq7g7X7xl4bJoNKLf
# cafOabJhpxfcFOowMIIHejCCBWKgAwIBAgIKYQ6Q0gAAAAAAAzANBgkqhkiG9w0B
# AQsFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAG
# A1UEAxMpTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5IDIwMTEw
# HhcNMTEwNzA4MjA1OTA5WhcNMjYwNzA4MjEwOTA5WjB+MQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSgwJgYDVQQDEx9NaWNyb3NvZnQgQ29kZSBT
# aWduaW5nIFBDQSAyMDExMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA
# q/D6chAcLq3YbqqCEE00uvK2WCGfQhsqa+laUKq4BjgaBEm6f8MMHt03a8YS2Avw
# OMKZBrDIOdUBFDFC04kNeWSHfpRgJGyvnkmc6Whe0t+bU7IKLMOv2akrrnoJr9eW
# WcpgGgXpZnboMlImEi/nqwhQz7NEt13YxC4Ddato88tt8zpcoRb0RrrgOGSsbmQ1
# eKagYw8t00CT+OPeBw3VXHmlSSnnDb6gE3e+lD3v++MrWhAfTVYoonpy4BI6t0le
# 2O3tQ5GD2Xuye4Yb2T6xjF3oiU+EGvKhL1nkkDstrjNYxbc+/jLTswM9sbKvkjh+
# 0p2ALPVOVpEhNSXDOW5kf1O6nA+tGSOEy/S6A4aN91/w0FK/jJSHvMAhdCVfGCi2
# zCcoOCWYOUo2z3yxkq4cI6epZuxhH2rhKEmdX4jiJV3TIUs+UsS1Vz8kA/DRelsv
# 1SPjcF0PUUZ3s/gA4bysAoJf28AVs70b1FVL5zmhD+kjSbwYuER8ReTBw3J64HLn
# JN+/RpnF78IcV9uDjexNSTCnq47f7Fufr/zdsGbiwZeBe+3W7UvnSSmnEyimp31n
# gOaKYnhfsi+E11ecXL93KCjx7W3DKI8sj0A3T8HhhUSJxAlMxdSlQy90lfdu+Hgg
# WCwTXWCVmj5PM4TasIgX3p5O9JawvEagbJjS4NaIjAsCAwEAAaOCAe0wggHpMBAG
# CSsGAQQBgjcVAQQDAgEAMB0GA1UdDgQWBBRIbmTlUAXTgqoXNzcitW2oynUClTAZ
# BgkrBgEEAYI3FAIEDB4KAFMAdQBiAEMAQTALBgNVHQ8EBAMCAYYwDwYDVR0TAQH/
# BAUwAwEB/zAfBgNVHSMEGDAWgBRyLToCMZBDuRQFTuHqp8cx0SOJNDBaBgNVHR8E
# UzBRME+gTaBLhklodHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9k
# dWN0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3JsMF4GCCsGAQUFBwEB
# BFIwUDBOBggrBgEFBQcwAoZCaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9j
# ZXJ0cy9NaWNSb29DZXJBdXQyMDExXzIwMTFfMDNfMjIuY3J0MIGfBgNVHSAEgZcw
# gZQwgZEGCSsGAQQBgjcuAzCBgzA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5taWNy
# b3NvZnQuY29tL3BraW9wcy9kb2NzL3ByaW1hcnljcHMuaHRtMEAGCCsGAQUFBwIC
# MDQeMiAdAEwAZQBnAGEAbABfAHAAbwBsAGkAYwB5AF8AcwB0AGEAdABlAG0AZQBu
# AHQALiAdMA0GCSqGSIb3DQEBCwUAA4ICAQBn8oalmOBUeRou09h0ZyKbC5YR4WOS
# mUKWfdJ5DJDBZV8uLD74w3LRbYP+vj/oCso7v0epo/Np22O/IjWll11lhJB9i0ZQ
# VdgMknzSGksc8zxCi1LQsP1r4z4HLimb5j0bpdS1HXeUOeLpZMlEPXh6I/MTfaaQ
# dION9MsmAkYqwooQu6SpBQyb7Wj6aC6VoCo/KmtYSWMfCWluWpiW5IP0wI/zRive
# /DvQvTXvbiWu5a8n7dDd8w6vmSiXmE0OPQvyCInWH8MyGOLwxS3OW560STkKxgrC
# xq2u5bLZ2xWIUUVYODJxJxp/sfQn+N4sOiBpmLJZiWhub6e3dMNABQamASooPoI/
# E01mC8CzTfXhj38cbxV9Rad25UAqZaPDXVJihsMdYzaXht/a8/jyFqGaJ+HNpZfQ
# 7l1jQeNbB5yHPgZ3BtEGsXUfFL5hYbXw3MYbBL7fQccOKO7eZS/sl/ahXJbYANah
# Rr1Z85elCUtIEJmAH9AAKcWxm6U/RXceNcbSoqKfenoi+kiVH6v7RyOA9Z74v2u3
# S5fi63V4GuzqN5l5GEv/1rMjaHXmr/r8i+sLgOppO6/8MO0ETI7f33VtY5E90Z1W
# Tk+/gFcioXgRMiF670EKsT/7qMykXcGhiJtXcVZOSEXAQsmbdlsKgEhr/Xmfwb1t
# bWrJUnMTDXpQzTGCBKowggSmAgEBMIGVMH4xCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25pbmcg
# UENBIDIwMTECEzMAAABkR4SUhttBGTgAAAAAAGQwCQYFKw4DAhoFAKCBvjAZBgkq
# hkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGC
# NwIBFTAjBgkqhkiG9w0BCQQxFgQUX5ZQ86FAE7+kV1ipu63YJ5SonyIwXgYKKwYB
# BAGCNwIBDDFQME6gNIAyAE8AVQA0AF8AQwBMAF8AUgBlAG0AbwB2AGUATgBvAE8A
# ZgBmAGkAYwBlAC4AcABzADGhFoAUaHR0cDovL21pY3Jvc29mdC5jb20wDQYJKoZI
# hvcNAQEBBQAEggEAX6qjA5cdo3ArEqtMahWS9bCtGO51VOZRUrIOaD8mcPcx6V6j
# H2uUCCjtCULSv+Gpjvr7CH/uF43N05nASZcNdQSENxUOvux+Svh71kKiBMoSWhbd
# 2mp/L1kQNgEcNt/9DA+QyagG8cg2ID7YLRAnTYhokiPR906MApGVjn3SDFHRZxnJ
# modWZIar2yioaL+oOuoolOluMcZXwrIp84OuICvBlmqg49WfUNAYRB8sOj6CO6TA
# f+Fe2us1uaSLU3T3HHsiHHHWq3EFkZI53fCAKMEfNa7EH1swcerlJdUpGQoweCdw
# WInQj1I8d3dq1GnNEjF0EeE4ZiqoMMCM+YmkKaGCAigwggIkBgkqhkiG9w0BCQYx
# ggIVMIICEQIBATCBjjB3MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMSEwHwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0ECEzMAAADFlkBg
# S/Teri4AAAAAAMUwCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0B
# BwEwHAYJKoZIhvcNAQkFMQ8XDTE2MTEzMDIwNTgyOFowIwYJKoZIhvcNAQkEMRYE
# FLlX4NqEL/g7hqBdbn6gcHuUkWiwMA0GCSqGSIb3DQEBBQUABIIBAKH/ZrOJzZsY
# IY9izbJN4LOGDR2obIuBGXM2Xr9dQt9EgYJMHdM0DOI8R4Cis9trKcViYfhJSO1a
# GFoOSnbPo2RP19LolJmYtjIMEbV8yFhzUeLV4XA2ytAYba7NVMyd+ii1yAvplBOJ
# kJ2IKniEtgTSVEOJRh/LWZdmWjWC79zDfE6tw1Lp3FC/OP1UJv/8rDg8NwjTeykn
# nzJ2FsnVZbJdcjzFQZc+JtyZkp+Ibf00AAoPcRPoehUckefcC0o2mOuU5QwOpXdt
# bodWoWVBMkUrSoDMze4G//wmTJPshLYGQZSyOVybr0CD+jm5J/+QyMlrx/Ko62xV
# T7z90uX+X3Q=
# SIG # End signature block
