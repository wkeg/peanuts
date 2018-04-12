#########################################
#   VM Automation						#
#	Will McKeigney/Chris Faria 			#
#	Server build 		shopping cart	#
#										#
#########################################

#mount file system Where request file from open cart exists.

#$newlocation = "drf-isilon\ifs\mixed"
$newlocation = "<share_name>\vol_serverbuild"
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

$filename = "rainbow_dash.csv"
$filename1 = "rainbow_dash1.csv"
$filename2 = "rainbow_dash2008sql.csv"


#validate csv files exist or not. If so exist script until clean
if (test-path z:\rainbow_dash1.csv)
{
	#Exit

}
else
{

#convert CSV to comma delimited file

Import-Csv \\$newlocation\$filename -Delimiter `t | Export-Csv \\$newlocation\$filename1 -NoTypeInformation


#########################################################################################################
#connects to vcenter server to run script

# Adds the base cmdlets
   Add-PSSnapin VMware.VimAutomation.Core

   Connect-VIServer -Server <vCenter FQDN> -User skynet\administrator -Password <Password>

#########################################################################################################


#read in CSV

	Import-Csv \\$newlocation\$filename1 | foreach-object {

    # define variables for csv imput

	$vmMem = $_.Memory
	$vmCPU = $_.Vcpu
	$nic = $_.Nic
	$order_id = $_.order_id
	$firstname = $_.firstname
	$email = $_.email
	$product_id=$_.order_product_id
	$platform = $_.Operating_system
	$quantity = $_.Qty
	$ServerName = $order_id+"-"+$product_id
	$storage_amount = $_.Storage
	$cust_attri_value = $_.BaaS
	$expDate = $_.Expire
	$vmhost = $_.Datacenter
	$file = " "

	#variables
	$x=1


# Loop through and create x number of vm's depending on what the user specified

do {
	##########################################################################################################
	#Parse UserID from email address
	$email  > E:\temp\tmp\userID.txt
	(Get-Content e:\temp\tmp\userID.txt)| ForEach-Object {$_ -replace "@.*", ""} | Set-Content e:\temp\tmp\finalUserID.txt
	$userID = Get-Content e:\temp\tmp\finalUserID.txt

	$myVM=$ServerName+"_"+$userID+"_"+$x
	##########################################################################################################

  	#################################################
	#****** Set Variables based on OS type*****#
	#################################################
	if ($platform -eq "Windows 2008" )
	{
		$OsId = "windows7Server64Guest"
		$file = "2008"
		$MacVar = "11"
		$netType = "Vmxnet3"
	}
	elseif ($platform -eq "Windows 2012" )
	{
		$OsId = "windows8Server64Guest"
		$file = "2012"
		$MacVar = "21"
		$netType = "Vmxnet3"
	}
	elseif ($platform -eq "informix" )
	{
		$OsId = "sles11_64Guest"
		$file = "informix"
		$MacVar = "14"
		$netType = "Vmxnet3"
	}
	elseif ($platform -eq "Windows 8" )
	{
		$OsId = "windows8_64Guest"
		$file = "Win8"
		$MacVar = "01"
		$netType = "e1000"
	}
	elseif ($platform -eq "Windows 7" )
	{
		$OsId = "windows7_64Guest"
		$file = "2007"
		$MacVar = "31"
		$netType = "Vmxnet3"
	}
	elseif ($platform -eq "RHEL 6.4" )
	{
		$OsId = "rhel6_64Guest"
		$file = "RHEL"
		$MacVar = "07"
		$netType = "e1000"
	}
	elseif ($platform -eq "SLES 11" )
	{
		$OsId = "sles11_64Guest"
		$file = "SLES"
		$MacVar = "27"
		$netType = "Vmxnet3"
	}
	elseif ($platform -eq "Pivotal HD" )
	{
		$vmTemp = "Pivotal-HD-template"
		$file = "2012"
	}

	if ($vmhost -eq "EDC")
		{
			# Dump datastore output to a text document for testing sorting in
			Get-Datastore *EDC*  | Sort-Object FreeSpaceGB -descending > e:\temp\$file\ds_dump_info.txt

			# parse file and take out unnecessary context
			(Get-Content e:\temp\$file\ds_dump_info.txt)|
			ForEach-Object {$_-replace "Name                               FreeSpaceGB      CapacityGB"} |
			ForEach-Object {$_-replace "----                               -----------      ----------"} |
			ForEach-Object {$_-replace ''}|
			out-file e:\temp\$file\ds_clean1.txt

			# parses out blank lines
			(Get-Content e:\temp\$file\ds_clean1.txt) | get-Unique |Select-String -Pattern "EDC" | Set-Content e:\temp\$file\ds_clean2.txt

			# get datastore name to use on next parse to pull out name alone
				Get-Content e:\temp\$file\ds_clean2.txt -TotalCount 1 |Set-Content e:\temp\$file\ds_name.txt

			# Parse the actual datastore  name from the file
			(Get-Content e:\temp\$file\ds_name.txt) | foreach {$_.ToString().Split("")[0]} | Set-Content e:\temp\$file\ds_name_final.txt

			# set datastore variable
			$myDatastore = Get-Content e:\temp\$file\ds_name_final.txt
		}

		elseif ($vmhost -eq "NDC")
		{

			# Dump datastore output to a text document for testing sorting in
			Get-Datastore *NDC*  | Sort-Object FreeSpaceGB -descending > e:\temp\$file\ds_dump_info.txt

			# parse file and take out unnecessary context
			(Get-Content e:\temp\$file\ds_dump_info.txt)|
			ForEach-Object {$_-replace "Name                               FreeSpaceGB      CapacityGB"} |
			ForEach-Object {$_-replace "----                               -----------      ----------"} |
			ForEach-Object {$_-replace ''}|
			out-file e:\temp\$file\ds_clean1.txt

			# parses out blank lines
			(Get-Content e:\temp\$file\ds_clean1.txt) | get-Unique |Select-String -Pattern "NDC" | Set-Content e:\temp\$file\ds_clean2.txt

			# get datastore name to use on next parse to pull out name alone
				Get-Content e:\temp\$file\ds_clean2.txt -TotalCount 1 |Set-Content e:\temp\$file\ds_name.txt

			# Parse the actual datastore  name from the file
			(Get-Content e:\temp\$file\ds_name.txt) | foreach {$_.ToString().Split("")[0]} | Set-Content e:\temp\$file\ds_name_final.txt

			# set datastore variable
			$myDatastore = Get-Content e:\temp\$file\ds_name_final.txt
		}

		elseif ($vmhost -eq "CDC")
		{

			# Dump datastore output to a text document for testing sorting in
			Get-Datastore *CDC*  | Sort-Object FreeSpaceGB -descending > e:\temp\$file\ds_dump_info.txt

			# parse file and take out unnecessary context
			(Get-Content e:\temp\$file\ds_dump_info.txt)|
			ForEach-Object {$_-replace "Name                               FreeSpaceGB      CapacityGB"} |
			ForEach-Object {$_-replace "----                               -----------      ----------"} |
			ForEach-Object {$_-replace ''}|
			out-file e:\temp\$file\ds_clean1.txt

			# parses out blank lines
			(Get-Content e:\temp\$file\ds_clean1.txt) | get-Unique |Select-String -Pattern "CDC" | Set-Content e:\temp\$file\ds_clean2.txt

			# get datastore name to use on next parse to pull out name alone
				Get-Content e:\temp\$file\ds_clean2.txt -TotalCount 1 |Set-Content e:\temp\$file\ds_name.txt

			################################
			#check capacity of datastores
			#################################
			(Get-Content e:\temp\$file\ds_name.txt) | foreach {$_.ToString().Split("")[20]} | Set-Content e:\temp\$file\free_cap_check.txt
			(Get-Content e:\temp\$file\ds_name.txt) | foreach {$_.ToString().Split("")[27]} | Set-Content e:\temp\$file\total_cap.txt

			$total_stg = Get-Content e:\temp\$file\total_cap.txt

			#cast as integer
			$total_int_stg = [int]$total_stg

			#get eightyfive percent of $total_int_stg
			$eightyfive = $total_int_stg * .80

			$compare_string = Get-Content e:\temp\$file\free_cap_check.txt

			#cast as integer
			$compare = [int]$compare_string


			if ($compare -lt $eightyfive )
			{
				print "Not enough room on any datrastore to continue provisioning, exiting script"

				$body = "All data stores are at or above 80% on cluster "+$vmhost

				Send-MailMessage -to "Admin <will.mckeigney@walmart.com>", "Admin2 <christopher.faria@walmart.com>"  -From " Script01 <script@skynet.com> " -subject "Out of Storage" -Body $body  -dno onSuccess, onFailure -smtpServer css-smtp.wal-mart.com
				break;
			}
			else{

			# Parse the actual datastore  name from the file
			(Get-Content e:\temp\$file\ds_name.txt) | foreach {$_.ToString().Split("")[0]} | Set-Content e:\temp\$file\ds_name_final.txt
			}

			# set datastore variable
			$myDatastore = Get-Content e:\temp\$file\ds_name_final.txt
		}
	else
		{
			Write-Host "Valid datastores not found, please try again."
		}

			#########################################################################################################################

			# Build virtual machine
			New-VM -Name "$myVM"  -DiskMB 40960 -DiskStorageFormat thin -MemoryGB 2 -GuestId "$OsId" -Version v8 -NetworkName "WOOKIE" -datastore "$myDatastore" -ResourcePool "$vmhost"
			#change network adapter type
			Get-VM -Name "$MyVM" | Get-NetworkAdapter -Name "Network adapter 1" | Set-NetworkAdapter -type $netType -Confirm:$false
			#change Memory and CPU if necessary
			Get-VM -Name "$myVM" | Set-VM -Name $myVM -NumCpu $vmCPU -MemoryGB $vmMem -Confirm:$false

			#########################################################################################################################
			#****** Change Mac Address for PXE booting *****#
			#################################################

			# Get the virtual machine network adapters
			Get-VM $myVM | get-NetworkAdapter > e:\temp\$file\initial.txt
		if ($netType -eq "e1000")
			{
				# Parse the adapter and pull our the MAC for the Wookie Network
				Get-ChildItem e:\temp\$file\initial.txt | Select-String -Pattern "WOOKIE" | foreach {$_.ToString().Split(" ")[19]} > e:\temp\$file\net_conf.txt

			}
		else{
				# Parse the adapter and pull our the MAC for the Wookie Network
				Get-ChildItem e:\temp\$file\initial.txt | Select-String -Pattern "WOOKIE" | foreach {$_.ToString().Split(" ")[17]} > e:\temp\$file\net_conf.txt
			}
			# Parse the net_conf (Wookie MAC) and pull out the octect following "00:50:56:" to set for PXE
			(Get-Content e:\temp\$file\net_conf.txt) |foreach {$_.ToString().Split(":")[3]} |Set-Content e:\temp\$file\temp1_mac.txt

			# Assign that octet to a variable
			$chgVar = (Get-Content e:\temp\$file\temp1_mac.txt)

			# Replace that variable with a value for a specific OS type (10 = Windows 2k8 R2)
			(Get-Content e:\temp\$file\net_conf.txt) -replace "$chgVar", $MacVar |Set-Content e:\temp\$file\changed_mac.txt

			# Run command to change mac address
			$newMac = Get-Content e:\temp\$file\changed_mac.txt
			get-vm $myVM | Get-NetworkAdapter -Name "Network adapter 1" | Set-NetworkAdapter -MacAddress $newMac -Confirm:$false

			#########################################################################################################################
			#Add additional drives to server builds

			#determines which cluster the vm is apart of
 			$cluster_name = Get-cluster -VM $myVM

			$calculation = $storage_amount + "GB"

			$data = $calculation/1KB

			#add drives
			Get-vm $myVM  | New-HardDisk -CapacityKB $data -Datastore $myDatastore  -StorageFormat Thin

			#########################################################################################################################


			#########################################################################################################################
			#Manipulate custom VM attributes

			Get-VM -Name $myVM | Set-Annotation -CustomAttribute "BAAS" -Value $cust_attri_value -Confirm:$false
			Get-VM -Name $myVM | Set-Annotation -CustomAttribute "Expire" -Value $expDate -Confirm:$false
			Get-VM -Name $myVM | Set-Annotation -CustomAttribute "Email" -Value $email -Confirm:$false

			#########################################################################################################################

			#  Clean up  #
			Remove-Item e:\temp\$file\*.txt

			#########################################################################################################################

			#Start the VM
			Start-VM "$MyVM"

		    #increment X for next host name
			$x++

		}

until($x -gt $quantity )

}
}
#########################################################################################################

#Remove csv file
remove-item \\$newlocation\$filename1
remove-item \\$newlocation\$filename
remove-item \\$newlocation\$filename2

#Disconnect from Vcenter

   Disconnect-VIServer -Server skynetvc01.skynet.com  -Confirm:$false

#########################################################################################################
