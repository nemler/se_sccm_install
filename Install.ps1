#Check that this is Windows 10
IF ([System.Environment]::OSVersion.Version.Major -lt 10) {
    Exit
}

#Check if Solid Edge 2019 is Already Installed
IF ((Test-Path -path("C:\Program Files\Siemens\Solid Edge 2019\Program\Edge.exe")) -eq "TRUE") {
    Exit
}

$sUninstalls = @("{886F91D5-4B45-45DC-938E-6B0276C6B015}") #V20
$sUninstalls += "{D7BCF606-5821-4D1D-889E-76AE9D00E439}" #ST1
$sUninstalls += "{CC185D10-5C0E-40C3-91F2-63314BB365AF}" #ST2
$sUninstalls += "{66ED11B7-4988-47FA-BE42-45A3AF0415BC}" #ST3
$sUninstalls += "{DE02B016-E096-437F-8D96-853BB36011D5}" #ST4
$sUninstalls += "{6350353B-BE44-4E86-9B3F-CE2C77BDFAEC}" #ST5
$sUninstalls += "{132B6ABB-431A-4DDA-8861-914AB7B0325A}" #ST6
$sUninstalls += "{AB0F3228-D90C-4574-8A28-589483A68C93}" #ST7
$sUninstalls += "{C69F7B10-60F2-476C-B0C1-4D61628462B7}" #ST8
$sUninstalls += "{1E02E133-6790-460A-B9C7-9CEA71CB502A}" #ST9
$sUninstalls += "{3D4C868F-5CCD-49F9-820C-DA31D714ABF6}" #ST10
# $sUninstalls += "{C62CE6BD-CC1D-4459-AA70-19295563C462}" #V2019

$sKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\"

#Uninstall Previous Versions
$sUninstalls  |foreach {
    IF ((Test-Path -Path(-join($sKeyPath,$_))) -eq 'True') {
        Start-Process -FilePath("MsiExec.exe") -argumentlist(-join("/X",$_," /qn")) -Wait
    }
}


$sKeyshot = @("C:\Program Files\KeyShot5") #Keyshot 5
$sKeyshot += "C:\Program Files\KeyShot6" #Keyshot 6
$sKeyshot += "C:\Program Files\KeyShot7" #Keyshot 7

#Uninstall Keyshot
$sKeyshot  |foreach {
    IF ((Test-Path(-join($_,"\uninst.exe"))) -eq "True") { 
        Start-Process -FilePath(-join($_,"\uninst.exe")) -ArgumentList(-join("/S _?=",$_)) -Wait
    }
}

#Cleaning up Solid Edge Registry
Remove-Item -Path "HKCU:\Software\Siemens\Solid Edge" -Recurse
Remove-Item -Path "HKCU:\Software\Siemens\Standard Parts" -Recurse
Remove-Item -Path "HKCU:\Software\Unigraphics Solutions\Solid Edge" -Recurse
Remove-Item -Path "HKCU:\Software\Unigraphics Solutions\Standard Parts" -Recurse

#Cleaning up Solid Edge ST10...
If ((Test-Path("C:\Users\Default\AppData\Roaming\Unigraphics Solutions\Solid Edge\Version 110")) -eq "True") {
    Remove-Item -LiteralPath("C:\Users\Default\AppData\Roaming\Unigraphics Solutions\Solid Edge\Version 110") -Force  -Recurse
}
Get-ChildItem("C:\Users") | ForEach-Object {
    If ((Test-Path(-join($_.FullName,"\AppData\Roaming\Unigraphics Solutions\Solid Edge\Version 110"))) -eq "True") {
        Remove-Item -LiteralPath(-join($_.FullName,"\AppData\Roaming\Unigraphics Solutions\Solid Edge\Version 110")) -Force  -Recurse
    }
}
If ((test-path("C:\Program Files\Solid Edge ST10")) -eq "True") {
    Remove-Item -LiteralPath("C:\Program Files\Solid Edge ST10") -Force -Recurse
}

#Installing Prereqs
#Check if .Net 4.5 or Later is installed, if not install
if ((Test-Path("HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full")) -eq "True") {
    $NetRegKey = Get-Childitem 'HKLM:\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full'
    $Release = $NetRegKey.GetValue("Release")
    if (!$Release) {
        Start-Process -FilePath(-join($PSScriptRoot, ".\SolidEdge\ISSetupPrerequisites\{B1BC5D8E-4DB2-47e3-9023-7BDC896CA031}\dotnetfx45_full_x86_x64.exe")) -ArgumentList("/q /norestart") -Wait
    }
}

#Check if MS VC++ 2015 is installed, if not install
If ((Test-Path -Path(-join($sKeyPath,"{B8E14C55-53F6-3693-A74A-77A3C6B96041}"))) -eq "True") {
    Start-Process -FilePath(-join($PSScriptRoot, ".\SolidEdge\ISSetupPrerequisites\MS VC++ 2015 Redist (x64)\vc_redist_x64_VC2015.exe")) -ArgumentList("/install /quiet /norestart") -Wait
}

#Installing Keyshot
Start-Process -FilePath(-join($PSScriptRoot,".\SolidEdge\ISSetupPrerequisites\{AF1F3FFA-CB2C-4249-AC4A-A597F8C34B78}\keyshot_w64.exe")) -ArgumentList("/S /AllUsers /D=C:\Program Files\KeyShot7") -Wait

#Copy UserProfile data to all user profiles
$sourcefolder = -join($PSScriptRoot,"\Custom\Customization\*")
$profilesfolder = "c:\users\"
$excluded_profiles = @( 'Administrator', 'Public', 'Csdmaint', 'All Users' )
$profiles = get-childitem $profilesfolder -Directory -Force | Where-Object { $_.BaseName -notin $excluded_profiles }
$targetfolder = "\AppData\Roaming\Siemens\Solid Edge\Version 219\Customization\"


foreach ($profile in $profiles) {
    $destination = $profilesfolder + $profile + $targetfolder
    New-Item $destination -itemtype directory -force
	copy-item $sourcefolder $destination -Recurse -force
}

#Installing Solid Edge 2019
$TEMP=[System.Environment]::GetEnvironmentVariable('TEMP','Machine')
$SolidEdgePath = -join($PSScriptRoot,"\SolidEdge\Setup.exe")
$SolidEdgeArgs = -join("/S /clone_wait /v""/qn"" /v""MYTEMPLATE=4"" /v""USERFILESPEC=",$PSScriptRoot,"\SELicense.dat"" /v""USERFILESPECXML=",$PSScriptRoot,"\options.xml"" /v""/l*v $TEMP\se2019_setup.log""")
Start-Process -FilePath($SolidEdgePath) -ArgumentList($SolidEdgeArgs) -Wait

#Install Solid Edge 2019 Latest Update
$Scriptpath = -join($PSScriptRoot,"\Update\64\setup.exe")
$ScriptArgs = -join("/S /clone_wait /v"" /qn""")
Start-Process -FilePath($Scriptpath) -ArgumentList($ScriptArgs) -Wait

#Copy Custom Program Files to Program Files Directory
$Copypath = -join($PSScriptRoot,"\Custom\ProgramFiles\*")
Copy-Item -Path($Copypath) -Destination "C:\Program Files\Siemens\Solid Edge 2019\" -Recurse -Force

#Copy Macros to ArielCorporation Folder
$Copypath1 = -join($PSScriptRoot,"\Custom\ArielCorporation\*")
Copy-Item -path($Copypath1) -Destination "C:\Program Files\Ariel Corporation\SEMacros\" -Recurse -Force

