<#
_author_ = Texas Roemer <Texas_Roemer@Dell.com>
_version_ = 2.0

Copyright (c) 2017, Dell, Inc.

This software is licensed to you under the GNU General Public License,
version 2 (GPLv2). There is NO WARRANTY for this software, express or
implied, including the implied warranties of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. You should have received a copy of GPLv2
along with this software; if not, see
http://www.gnu.org/licenses/old-licenses/gpl-2.0.txt
#>

<#
.Synopsis
   Cmdlet used to either get current next boot onetime boot device value / supported possible values or set next onetime boot device using REDFISH API.
   IMPORTANT: Make sure you are using latest Powershell version 5 or newer to execute this cmdlet. Execute "Get-Host" to check the version.
.DESCRIPTION
   Cmdlet used to either get current next boot onetime boot device value / supported possible values or set next onetime boot device with reboot now or no reboot but still set next onetime boot device.
   - idrac_ip, REQUIRED, pass in idrac IP
   - idrac_username, REQUIRED, pass in idrac user name
   - idrac_password, REQUIRED, pass in idrac password
   - view_current_boot_device_and_options, OPTIONAL, pass in a value of "y" to view current onetime boot device setting and possible supported values
   - next_onetime_boot_device, OPTIONAL, pass in the device you want to next onetime boot to (Values are case senstive, make sure to pass in the exact string value. Example: "Pxe" is the correct value, "pxe" or "PXE" is the incorrect value ).
   - uefi_target_path, OPTIONAL, pass in the UEFI target path you want to one time boot to. This parameter should be used when setting next_onetime_boot_device to UefiTarget.
   - reboot_now, OPTIONAL, pass in "y" if you want the server to reboot now and boot to onetime boot device. Pass in "n" which will still set the onetime boot device but not reboot the server.
.EXAMPLE
	This example shows only getting current onetime boot device setting and possible values
    Set-NextOneTimeBootDeviceREDFISH -idrac_ip 192.168.0.120 -idrac_username root -idrac_password calvin -view_current_boot_device_and_options y
.EXAMPLE
	This example shows setting next onetime boot device to Pxe and reboots the server now
    Set-NextOneTimeBootDeviceREDFISH -idrac_ip 192.168.0.120 -idrac_username root -idrac_password calvin -next_onetime_boot_device Pxe -reboot_now y
    .EXAMPLE
	This example shows setting next onetime boot device to UefiTarget, setting uefi_target_path to http://192.168.0.130/uefi_image.efi and reboots the server now. Once the server reboots, server will enter Lifecycle Controller to set HTTP URI target, reboot the server one more time and once the server completes POST, it will one time boot to this URI HTTP path. 
    Set-NextOneTimeBootDeviceREDFISH -idrac_ip 192.168.0.120 -idrac_username root -idrac_password calvin -next_onetime_boot_device UefiTarget -uefi_target_path http://192.168.0.130/uefi_image.efi -reboot_now y
#>

function Set-NextOneTimeBootDeviceREDFISH {


param(
    [Parameter(Mandatory=$True)]
    [string]$idrac_ip,
    [Parameter(Mandatory=$True)]
    [string]$idrac_username,
    [Parameter(Mandatory=$True)]
    [string]$idrac_password,
    [Parameter(Mandatory=$False)]
    [string]$view_current_boot_device_and_options,
    [Parameter(Mandatory=$False)]
    [string]$next_onetime_boot_device,
    [Parameter(Mandatory=$False)]
    [string]$uefi_target_path,
    [Parameter(Mandatory=$False)]
    [string]$reboot_now

    )

# Function to ignore SSL certs

function Ignore-SSLCertificates
{
    $Provider = New-Object Microsoft.CSharp.CSharpCodeProvider
    $Compiler = $Provider.CreateCompiler()
    $Params = New-Object System.CodeDom.Compiler.CompilerParameters
    $Params.GenerateExecutable = $false
    $Params.GenerateInMemory = $true
    $Params.IncludeDebugInformation = $false
    $Params.ReferencedAssemblies.Add("System.DLL") > $null
    $TASource=@'
        namespace Local.ToolkitExtensions.Net.CertificatePolicy
        {
            public class TrustAll : System.Net.ICertificatePolicy
            {
                public bool CheckValidationResult(System.Net.ServicePoint sp,System.Security.Cryptography.X509Certificates.X509Certificate cert, System.Net.WebRequest req, int problem)
                {
                    return true;
                }
            }
        }
'@ 
    $TAResults=$Provider.CompileAssemblyFromSource($Params,$TASource)
    $TAAssembly=$TAResults.CompiledAssembly
    $TrustAll = $TAAssembly.CreateInstance("Local.ToolkitExtensions.Net.CertificatePolicy.TrustAll")
    [System.Net.ServicePointManager]::CertificatePolicy = $TrustAll
}

Ignore-SSLCertificates


[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::TLS12
$user = $idrac_username
$pass= $idrac_password
$secpasswd = ConvertTo-SecureString $pass -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($user, $secpasswd)

$u = "https://$idrac_ip/redfish/v1/Systems/System.Embedded.1"
$result = Invoke-WebRequest -Uri $u -Credential $credential -Method Get -UseBasicParsing 

if ($view_current_boot_device_and_options -eq "y")
{
if ($result.StatusCode -eq 200)
{
    [String]::Format("`n- PASS, statuscode {0} returned successfully to current next boot option and supported values",$result.StatusCode)
    $r=$result.Content | ConvertFrom-Json
    $current_next_boot=$r.Boot.BootSourceOverrideTarget
    Write-Host "`n- Current next boot setting is: " $current_next_boot
    $possible_values="BootSourceOverrideTarget@Redfish.AllowableValues"
    Write-Host "`n- Possible values for next onetime boot are:`n"
    $r.Boot.$possible_values
	Write-Host
    return
}
else
{
    [String]::Format("- FAIL, statuscode {0} returned",$result.StatusCode)
    return
}
}

if ($view_current_boot_device_and_options -eq "n")
{
return
}

if ($next_onetime_boot_device -eq "UefiTarget" -and $uefi_target_path -ne "")
{

$JsonBody = @{ Boot = @{
    "BootSourceOverrideTarget"=$next_onetime_boot_device;"UefiTargetBootSourceOverride"=$uefi_target_path
    }} | ConvertTo-Json -Compress
}
else
{
$JsonBody = @{ Boot = @{
    "BootSourceOverrideTarget"=$next_onetime_boot_device
    }} | ConvertTo-Json -Compress
}

$u = "https://$idrac_ip/redfish/v1/Systems/System.Embedded.1"
$result1 = Invoke-WebRequest -Uri $u -Credential $credential -Method Patch -Body $JsonBody -ContentType 'application/json'
$q=$result1.RawContent | ConvertTo-Json -Compress


if ($result1.StatusCode -eq 200)
{
    if ($next_onetime_boot_device -eq "UefiTarget" -and $uefi_target_path -ne "")
    {
    [String]::Format("`n- PASS, statuscode {0} returned to successfully set UEFI target path to ""{1}"" and next onetime boot device to ""{2}""`n",$result1.StatusCode,$uefi_target_path,$next_onetime_boot_device)
    Start-Sleep 5
    }
    else
    {
    [String]::Format("`n- PASS, statuscode {0} returned to successfully set next onetime boot device to ""{1}""`n",$result1.StatusCode,$next_onetime_boot_device)
    Start-Sleep 5
    }
}
else
{
    [String]::Format("`n- FAIL, statuscode {0} returned",$result1.StatusCode)
    return
}


if ($reboot_now -eq "y") 
{

Write-Host "- WARNING, user selected to automatically reboot the server now and boot to onetime boot device`n"

$JsonBody = @{ "ResetType" = "ForceOff"
    } | ConvertTo-Json -Compress


$u4 = "https://$idrac_ip/redfish/v1/Systems/System.Embedded.1/Actions/ComputerSystem.Reset"
$result1 = Invoke-WebRequest -Uri $u4 -Credential $credential -Method Post -Body $JsonBody -ContentType 'application/json'

if ($result1.StatusCode -eq 204)
{
    [String]::Format("- PASS, statuscode {0} returned successfully to power OFF the server",$result1.StatusCode)
    Start-Sleep 10
}
else
{
    [String]::Format("- FAIL, statuscode {0} returned",$result1.StatusCode)
    return
}

$JsonBody = @{ "ResetType" = "On"
    } | ConvertTo-Json -Compress


$u4 = "https://$idrac_ip/redfish/v1/Systems/System.Embedded.1/Actions/ComputerSystem.Reset"
$result1 = Invoke-WebRequest -Uri $u4 -Credential $credential -Method Post -Body $JsonBody -ContentType 'application/json'

if ($result1.StatusCode -eq 204)
{
    [String]::Format("- PASS, statuscode {0} returned successfully to power ON the server",$result1.StatusCode)
}
else
{
    [String]::Format("- FAIL, statuscode {0} returned",$result1.StatusCode)
    return
}

Write-Host -Foreground Yellow "`n- WARNING, system automatically rebooted and will now onetime boot to device" $next_onetime_boot_device
Write-Host
}

if ($reboot_now -eq "n")
{
Write-Host -Foreground Yellow "`n- WARNING, user requested to not reboot the server now. Onetime boot device is still set and will boot to the device on next manual server reboot"
Write-Host
}

}
