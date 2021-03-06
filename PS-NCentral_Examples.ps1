## PS-NCentral Usage Examples
## Applies to version 1.0

# Load PS-NCentral module and display available commands.
Import-Module "$PSScriptRoot\PS-NCentral"
Get-NCHelp

## Connect to the N-Central server (interactive).
## This will also be initiated if any NC-command is given before connecting.
## After connecting NC-commands will keep using this connection/session.
## For advanced options type: Get-Help New-NCentralConnection.
New-NCentralConnection

## Fully automated connection; use the 4 lines below, replace the <Data> tags.
#$NCentralFQDN = "<name>.<domain>"
#$SecurePass = ConvertTo-SecureString <PassWord> -AsPlainText -Force
#$PSUserCredential = New-Object PSCredential (<UserName>, $SecurePass)
#New-NCentralConnection $NCentralFQDN $PSUserCredential


## PS-NCentral commands can now be used for server-interaction.
## The NC-CmdLets can be used without the Get- prefix.
## Examples (unmark individual lines)
#Get-NCCustomerList | Format-Table
#Get-NCCustomerList | Select-Object CustomerName,CustomerID,ExternalID,ExternalID2,ParentID | Format-Table
Get-NCDeviceLocal
Get-NCDeviceList 100 | Select-Object -First 2 | Get-NCDeviceInfo | Format-List
Get-NCDeviceID "ComputerName" | Get-NCDeviceStatus | Out-GridView
Get-NCDeviceLocal | Set-NCDeviceProperty -PropertyName "Label" -PropertyValue "Value"


## The Advanced Exmples may take some time to complete.

## Advanced example1: Pipeline using Filter and Export to file (unmark both lines).
#Get-NCDevicePropertyListFilter 1 | Get-NCDeviceInfo |
#Export-Csv C:\Temp\DetectedWindowsServersList.csv -Encoding UTF8 -NoTypeInformation

## Advanced example2: Pipeline using Local Computer and Device-object (unmark both lines).
#$Device = Get-NCDeviceLocal | Get-NCDeviceObject
#$Device.Application | Sort-Object deviceid,displayname | Format-Table
#$Device | Get-Member			## See all attributes

