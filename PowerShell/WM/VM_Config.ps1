$Global:VCS_HO = @("phova72003us.homeoffice.wal-mart.com", "phont72001usa.homeoffice.wal-mart.com", "phont72001usb.homeoffice.wal-mart.com", "phova72001usa.homeoffice.wal-mart.com", "phova72001usb.homeoffice.wal-mart.com", "phova72001usc.homeoffice.wal-mart.com", "phova72001usd.homeoffice.wal-mart.com", "phova72001use.homeoffice.wal-mart.com", "phova72001usf.homeoffice.wal-mart.com")
Import-Module "Vmware.VimAutomation.Core"
Import-Module Influx
# Get user credentials
$Creds = Get-Credential
# Login to vcenters
Connect-VIServer -Server $Global:VCS_HO -Credential $Creds -SaveCredentials
#$myclusters = get-cluster | where {$_.name -like "hovsh020[456789][en]dc" -or $_.name -like "hovsh3301[en]dc"} | sort-object
$myclusters = get-cluster | where { $_.name -like "hovsh020[9][n]dc" } | sort-object
$myreport = @()
foreach ($mycluster in $myclusters) {
    $myClusterStats = new-object psobject
    $myClusterStats | Add-Member -membertype NoteProperty -Name Name -Value $mycluster.name
    $myClusterStats | Add-Member -membertype NoteProperty -Name Nodes -Value $null
    $myClusterStats | Add-Member -membertype NoteProperty -Name CPU_Core -Value $null
    $myClusterStats | Add-Member -membertype NoteProperty -Name VM_CPU_Core -Value $null
    $myClusterStats | Add-Member -membertype NoteProperty -Name CPU_MHZ -Value $null
    $myClusterStats | Add-Member -membertype NoteProperty -Name VM_CPU_MHZ -Value $null
    $myClusterStats | Add-Member -membertype NoteProperty -Name Used_CPU_Percent -Value $null
    $myClusterStats | Add-Member -membertype NoteProperty -Name Memory -Value $null
    $myClusterStats | Add-Member -membertype NoteProperty -Name VM_Memory -Value $null
    $myClusterStats | Add-Member -membertype NoteProperty -Name VM_Memory_Used -Value $null
    $myClusterStats | Add-Member -membertype NoteProperty -Name Used_Memory_Percent -Value $null
    $myClusterStats | Add-Member -membertype NoteProperty -Name Storage -Value $null
    $myClusterStats | Add-Member -membertype NoteProperty -Name Storage_Provisioned -Value $null
    $myClusterStats | Add-Member -membertype NoteProperty -Name Storage_Used -Value $null
    $myClusterStats | Add-Member -membertype NoteProperty -Name Storage_Used_Percent -Value $null
    $myClusterStats | Add-Member -membertype NoteProperty -Name VMCount -Value $null
    $myclusterstats.Nodes = ($mycluster | get-vmhost).count
    $myclusterstats.cpu_core = ($mycluster | get-vmhost | select numcpu | measure-object -sum -property numcpu).sum
    $myclusterstats.memory = [math]::round(($mycluster | get-vmhost | select MemoryTotalGB | measure-object -sum -property MemoryTotalGB).sum)
    $myclusterstats.VM_cpu_core = (($mycluster | get-vm | select numcpu) | measure-object -sum -property numcpu).sum
    $myclusterstats.VM_memory = [math]::round((($mycluster | get-vm | select memorygb) | measure-object -sum -property memorygb).sum)
    $myclusterstats.cpu_mhz = ($mycluster | get-vmhost | select cputotalmhz | measure-object -sum -property cputotalmhz).sum
    $myclusterstats.VM_cpu_mhz = ($mycluster | get-vmhost | select cpuusagemhz | measure-object -sum -property cpuusagemhz).sum
    $myclusterstats.Used_CPU_Percent = [math]::round( ( ($myclusterstats.VM_cpu_mhz) / ($myclusterstats.cpu_mhz) ) * 100 )
    $myclusterstats.VM_Memory_Used = [math]::round(($mycluster | get-vmhost | select memoryusagegb | measure-object -sum -property memoryusagegb).sum)
    $myclusterstats.Used_Memory_Percent = [math]::round( ( ($myclusterstats.VM_Memory_Used) / ($myclusterstats.Memory) ) * 100 )
    $myclusterstats.VMCount = ($mycluster | get-vm).count
    $myclusterstats.Storage = [math]::round((($mycluster | get-vmhost | get-datastore | where { $_.name -like "$($mycluster.name)*" } | select capacitygb | measure-object -sum -property capacitygb).sum) / 1024)
    $FreeSpace = [math]::round((($mycluster | get-vmhost | get-datastore | where { $_.name -like "$($mycluster.name)*" } | select freespacegb | measure-object -sum -property freespacegb).sum) / 1024)
    $myclusterstats.Storage_Used = [math]::round($($myclusterstats.storage) - $($freespace))
    $myclusterstats.Storage_Used_Percent = [math]::round( ( ($myclusterstats.Storage_Used) / ($myclusterstats.Storage) ) * 100 )
    $datastoreView = $mycluster | get-vmhost | get-datastore | where { $_.name -like "$($mycluster.name)*" } | get-view | select -ExpandProperty summary | select *
    $Capacity = ($datastoreView | measure-object -sum -Property Capacity).sum
    $FreeSpace = ($datastoreView | measure-object -sum -Property FreeSpace).sum
    $Uncommitted = ($datastoreView | measure-object -sum -Property Uncommitted).sum
    $myclusterstats.Storage_Provisioned = ([math]::round(($($Capacity) - $($FreeSpace) + $($Uncommitted)) / 1TB))
    #-Value ([math]::round(($($DS_View.Capacity) - $($DS_View.FreeSpace) + $($DS_View.Uncommitted))/1GB,2))
    $myreport += $myclusterstats
    #Invoke-WebRequest 'http://phont11980us.homeoffice.wal-mart.com:8086/write?db=HOVSH0209NDC' -Method POST -Body $myreport
    #Invoke-WebRequest 'http://phont11980us.homeoffice.wal-mart.com:8086/write?db=HOVSH0209NDC' -Method POST $mycluster.name,Nodes=$myclusterstats.Nodes,CPU_Core=$myclusterstats.cpu_core,VM_CPU_Core=$myclusterstats.VM_cpu_core,CPU_MHZ=$myclusterstats.cpu_mhz,VM_CPU_MHZ=$myclusterstats.VM_cpu_mhz,Used_CPU_Percent=$myclusterstats.Used_CPU_Percent,Memory=$myclusterstats.memory,VM_Memory=$myclusterstats.VM_memory,VM_Memory_Used=$myclusterstats.VM_Memory_Used,Used_Memory_Percent=$myclusterstats.Used_Memory_Percent,Storage=$myclusterstats.Storage,Storage_Provisioned=$myclusterstats.Storage_Provisioned,Storage_Used=$myclusterstats.Storage_Used,Storage_Used_Percent=$myclusterstats.Storage_Used_Percent,VMCount=$myclusterstats.VMCount
}
write-output $myreport | format-table -AutoSize -Property *
#$myreport | export-csv C:\Users\gbroad1\Desktop\workloads_reports\clusters\report-5-30-19.csv -NoTypeInformation
#$myreport | Out-File -FilePath .\stuff.txt
