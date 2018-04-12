###########################################################
# AUTHOR  : Will McKeigney
# DATE    : 26-04-2014
# COMMENT : This script creates new Active Directory users
#           including different kind of properties based
#           on an input_create_ad_users.csv.
###########################################################
Import-Module ActiveDirectory
#mount file system

$newlocation = "drf-isilon\ifs\mixed"
$homedir = $pwd

if (get-psdrive | where {$_.name -eq "Z"}){
	if ((get-psdrive | where {$_.name -eq "Z"}).Root -eq "\\$newlocation"){cd z:}
	else{
		Remove-PSDrive -Name "Z" -Force
		New-PSDrive -Name "Z" -PSProvider FileSystem -root \\$newlocation
		cd Z:
	}
}
else {
	New-PSDrive -Name "Z" -PSProvider FileSystem -root \\$newlocation | out-null
	cd Z:
}



#convert csv file

$filename = "import_create_ad_users.csv"
$filename1 = "import_create_ad_users1.csv"
$Command1 = ".\unix2dos.exe "

<#
#convert data in csv
iex "$command1$filename"
#>
#convert CSV to comma delimited file

Import-Csv \\$newlocation\$filename -Delimiter `t | Export-Csv \\$newlocation\$filename1 -NoTypeInformation



# Get current directory and set import file in variable
#$path     = Split-Path -parent $MyInvocation.MyCommand.Definition
# Define variables

$log      = "create_ad_users.log"
$date     = Get-Date
$i        = 0

# Change this to the location you want the users to be created in your AD
$location = "OU=WMT,OU=USER,DC=skynet,DC=com"

# FUNCTIONS

Function createUsers
{
#	"Created following users (on " + $date + "): " | Out-File $log -append
#	"--------------------------------------------" | Out-File $log -append

	Import-CSV \\$newlocation\$filename1 | ForEach-Object {
		# A check for the country, because those were full names and need
		# to be landcodes in order for AD to accept them. I used Netherlands
		# as example

		$CN = $_.firstname + " " + $_.lastname

		# Replace dots / points (.) in names, because AD will error when a
		# name ends with a dot (and it looks cleaner as well)
		$replace = $CN.Replace(".","")
		If($replace.length -lt 4){
			$lastname = $replace
		}
		Else{
			$lastname = $replace.substring(0,4)
		}
		# Create sAMAccountName according to this 'naming convention':
		# <FirstLetterInitials><FirstFourLettersLastName> for example
		# hhica
		$sam = $_.id.ToLower()

		Try   { $exists = Get-ADUser -LDAPFilter "(sAMAccountName=$sam)" }
		Catch { }
		If(!$exists){
			$i++

			# Set all variables according to the table names in the Excel
			# sheet / import CSV. The names can differ in every project, but
			# if the names change, make sure to change it below as well.
			$setpass = ConvertTo-SecureString -AsPlainText "Welc0me1" -force
			New-ADUser $sam -GivenName $_.firstname -Surname $_.lastname -EmailAddress $_.email -EmployeeID $_.id -OfficePhone $_.telephone -AccountPassword $setpass

			#test
			Add-ADGroupMember -Identity VDI_Users -Member $sam
			Enable-ADAccount $sam
			Set-ADUser -Identity $sam -ChangePasswordAtLogon 1


			# Set an ExtensionAttribute
			$dn  = (Get-ADUser $sam).DistinguishedName
			$ext = [ADSI]"LDAP://$dn"
			#If ($_.ExtensionAttribute1 -ne "" -And $_.ExtensionAttribute1 -ne $Null)
			#{
			#  $ext.Put("extensionAttribute1", $_.ExtensionAttribute1)
			#  $ext.SetInfo()
			#}

			# Move the user to the OU you set above. If you don't want to
			# move the user(s) and just create them in the global Users
			# OU, comment the string below
			Move-ADObject -Identity $dn -TargetPath $location

			# Rename the object to a good looking name (otherwise you see
			# the 'ugly' shortened sAMAccountNames as a name in AD. This
			# can't be set right away (as sAMAccountName) due to the 20
			# character restriction
			$newdn = (Get-ADUser $sam).DistinguishedName
			Rename-ADObject -Identity $newdn -NewName $CN

			$output  = $i.ToString() + ") Name: " + $CN + "  sAMAccountName: "
			$output += $sam + "  Pass: " + $setpass
			$output | Out-File $log -append
		}
		Else{
#			"SKIPPED - ALREADY EXISTS OR ERROR: " + $CN | Out-File $log -append
		}

#		"----------------------------------------" + "`n" | Out-File $log -append
	}
}
cd $homedir

# RUN SCRIPT
createUsers

#Cleanup
remove-item \\$newlocation\$filename1 -Force





Remove-PSDrive -Name "Z" -Force
Write-Host `n"Fin"
Write-Host
