## PowerShell Module for N-Central(c) by Solarwinds
##
## Version	:	1.1
## Author	:	Adriaan Sluis (as@tosch.nl)
##
## !Still some Work In Progress!
##
## Provides a PowerShell Interface for N-Central(c)
## Uses the SOAP-API of N-Central(c) by Solarwinds
## Completely written in PowerShell for easy reference/analysis.
##
##

##Copyright 2020 Tosch Automatisering
##
##Licensed under the Apache License, Version 2.0 (the "License");
##you may not use this file except in compliance with the License.
##You may obtain a copy of the License at
##
##    http://www.apache.org/licenses/LICENSE-2.0
##
##Unless required by applicable law or agreed to in writing, software
##distributed under the License is distributed on an "AS IS" BASIS,
##WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
##See the License for the specific language governing permissions and
##limitations under the License.

#Region Classes and Generic Functions

Class NCentral_Connection {
	## Using the Interface ServerEI2_PortType
	## See documentation @:
	## http://mothership.n-able.com/dms/javadoc_ei2/com/nable/nobj/ei2/ServerEI2_PortType.html
	
	#Region Properties
	
		## TODO - Enum-lists for DeviceStatus, ...
	
		## Initialize the API-specific values (as static).
		## No separate NameSpace needed because of Class-enclosure. Instance NameSpace available as Property.
		#static hidden [String]$NWSNameSpace = "NCentral" + ([guid]::NewGuid()).ToString().Substring(25)
		static hidden [String]$SoapURL = "/dms2/services2/ServerEI2?wsdl"
	
		
		## Create Properties
		[Object]$Error						## Last known Error
		[String]$ConnectionURL				## Server FQDN
		[String]$BindingURL					## Full SOAP-path
		[Boolean]$IsConnected = $false		## Connection Status
		hidden [PSCredential]$Creds = $null	## Encrypted Credentials
	
		hidden [Object]$Connection			## Store Server Session
		hidden [Object]$NameSpace			## For accessing API-Class Objects
	
		## Work In Progress
		$NCVersion
		$tCreds
	
		## Create a general Key/Value Pair. Will be casted at use. Skipped in most methods for non-reuseablity.
		## Integrated (available in session only): $KeyPair = New-Object -TypeName ($NameSpace + '.tKeyPair')
		## Also create Pairs container(Array).
		hidden $KeyPair = [PSObject]@{Key=''; Value='';}
		hidden [Array]$KeyPairs = @()
	
		## Defaults and ValidationLists
		[int]$DefaultCustomerID
		# Documented under CustomerModify:
		[Array]$CustomerValidation = @('zip/postalcode','street1','street2','city','state/province','telephone','country','externalid','externalid2','firstname','lastname','title','department','contact_telephone','ext','email','licensetype')
	
		## Hold data-objects returning from API-Call or reference.
		hidden [Array]$rc				#Returned Raw Collection of NCentral-Data.
		hidden [Object]$CustomerData	#Caching of CustomerData for quick reference
	
		## Testing / Debugging only
		hidden $Testvar
	#	$Testvar = $this.GetType().name
		
	
	#EndRegion	
		
	#Region Constructors
	
		#Base Constructors
		## Using ConstructorHelper for chaining.
		
		NCentral_Connection(){
		
			Try{
				## [ValidatePattern('^server\d{1,4}$')]
				$ServerFQDN = Read-Host "Enter the fqdn of the N-Central Server"
			}
			Catch{
				Write-Host "Connection Aborted"
				Break
			}
			$PSCreds = Get-Credential -Message "Enter NCentral API-User credentials"
			$this.ConstructorHelper($ServerFQDN,$PSCreds)
		}
		
		NCentral_Connection([String]$ServerFQDN){
			$PSCreds = Get-Credential -Message "Enter NCentral API-User credentials"
			$this.ConstructorHelper($ServerFQDN,$PSCreds)
		}
		
		NCentral_Connection([String]$ServerFQDN,[PSCredential]$PSCreds){
			$this.ConstructorHelper($ServerFQDN,$PSCreds)
		}
	
		hidden ConstructorHelper([String]$ServerFQDN,[PSCredential]$Credentials){
			## Constructor Chaining not Standard in PowerShell. Needs a Helper-Method.
			##
			## ToDo: 	ValidatePattern for $ServerFQDN
				
			If (!$ServerFQDN){	
				Write-Host "Invalid ServerFQDN given."
				Break
			}
			If (!$Credentials){	
				Write-Host "No Credentials given."
				Break
			}
	
			## Construct Session-parameters.
			$this.ConnectionURL = $ServerFQDN		## In Class-Property for later reference
			$this.Creds = $Credentials
	
			Write-Debug "Connecting to $this.ConnectionURL."
			$this.bindingURL = "https://" + $this.ConnectionURL + [NCentral_Connection]::SoapURL
	
			## Initiate the session to the NCentral-server.
			$this.Connect()
		
		}	
		
	
	#EndRegion
	
	#Region Methods
		
	#	## Features
	#	## Returns all data as Object-collections to allow pipelines.
	#	## Mimic the names of the API-method where possible.
	#	## Supports Synchronous Requests only (for now).
	#	## NO 'Dangerous' API's are implemented (Delete/Remove).
		
	#	## To Do
	#	## TODO - Check for $this.IsConnected before execution.
	#	## TODO - Replace remaining $this.KeyPair with Generic KeyPairs (see: DeviceList-method).
	#	## TODO - General Error-handling + customized throws.
	#	## TODO - Additional Set-methods (Only Custom-Properties for now)
	#	## TODO - Progress indicator (Write-Progress)
	#	## TODO - DeviceAssetInfoExportWithSettings options (Exclude/Include)
	#	## TODO - Error on AccessGroupGet
	#	## TODO - Async processing
		
		#Region CustomerData
		[Object]ActiveIssuesList([Int]$ParentID){
			# No SearchBy-string adds an empty String.
			return $this.ActiveIssuesList($ParentID,"")
		}
		
		[Object]ActiveIssuesList([Int]$ParentID,[String]$IssueSearchBy){
			## Refresh / Clean KeyPair-container.
			$this.KeyPairs = @()
	
			## Add parameters as KeyPairs.
			$KeyPair1 = [PSObject]@{Key='customerID'; Value=$ParentID;}
			$this.KeyPairs += $KeyPair1
	
			## Optional keypair(s) for activeIssuesList. ToDo: Create ENums for choices.
	
			## SearchBy
			## A string-value to search the: so, site, device, deviceClass, service, transitionTime,
			## notification, features, deviceID, and ip address.
			If ($IssueSearchBy){
				$KeyPair2 = [PSObject]@{Key='searchBy'; Value=$IssueSearchBy;}
				$this.KeyPairs += $KeyPair2
			}
			
			## OrderBy
			## Valid inputs are: customername, devicename, servicename, status, transitiontime,numberofacknoledgednotification,
			## 					serviceorganization, deviceclass, licensemode, and endpointsecurity.
			## Default is customername.
	#		$IssueOrderBy = "transitiontime"
	#		$KeyPair3 = [PSObject]@{Key='orderBy'; Value=$IssueOrderBy;}
	#		$this.KeyPairs += $KeyPair3
	
			## ReverseOrder
			## Must be true or false. Default is false.
	#		$IssueOrderReverse = "true"
	#		$KeyPair4 = [PSObject]@{Key='reverseorder'; Value=$IssueOrderReverse;}
	#		$this.KeyPairs += $KeyPair4
	
			## Status
			## Only 1 (last) statusfilter will be applied (if used).
	
			## NOC_View_Notification_Acknowledgement_Filter.
			## Valid inputs are: "Acknowledged" or "Unacknowledged"
	#		$IssueAcknowledged = "Unacknowledged"
	#		$KeyPair5 = [PSObject]@{Key='NOC_View_Notification_Acknowledgement_Filter'; Value=$IssueAcknowledged;}
	#		$this.KeyPairs += $KeyPair5
	
			## NOC_View_Status_Filter
			## Valid inputs are: no data, stale, normal, warning, failed, misconfigured, disconnected
			## 'normal' does not return any data.
	#		$IssueStatus = "warning"
	#		$KeyPair6 = [PSObject]@{Key='NOC_View_Status_Filter'; Value=$IssueStatus;}
	#		$this.KeyPairs += $KeyPair6
	
	
			$this.rc = $null
	
			## KeyPairs is mandatory in this query. returns limited list
			Try{
				$this.rc = $this.Connection.activeIssuesList($this.PlainUser(), $this.PlainPass(), $this.KeyPairs)
			}
			Catch {
				$this.Error = $_
				$this.ErrorHandler()
			}
	
			## Needs 'issue' iso 'items' for ReturnObjects
	#		Return $this.ProcessData1($this.rc, "issue")
			Return $this.ProcessData1($this.rc)
		}
	
		[Object]JobStatusList([Int]$ParentID){
			## Uses CustomerID. Reports ONLY Scripting-tasks now (not AMP or discovery).
	
			## Refresh / Clean KeyPair-container.
			$this.KeyPairs = @()
	
			## Add parameters as KeyPairs.
			$KeyPair1 = [PSObject]@{Key='customerID'; Value=$ParentID;}
			$this.KeyPairs += $KeyPair1
	
			$this.rc = $null
	
			Try{
				$this.rc = $this.Connection.jobStatusList($this.PlainUser(), $this.PlainPass(), $this.KeyPairs)
			}
			Catch {
				$this.Error = $_
				$this.ErrorHandler()
			}
	
			Return $this.ProcessData1($this.rc)
		}
		
		[Object]CustomerList(){
		
			Return $this.CustomerList($false)
		}
		
		[Object]CustomerList([Boolean]$SOList){
			## Refresh / Clean KeyPair-container.
			$this.KeyPairs = @()
	
			If($SOList){
				$KeyPair1 = [PSObject]@{Key='listSOs'; Value='true';}
				$this.KeyPairs += $KeyPair1
			}
	
			$this.rc = $null
	
			## KeyPairs Array must exist, but is not used in this query.
			Try{
				$this.rc = $this.Connection.customerList($this.PlainUser(), $this.PlainPass(), $this.KeyPairs)
			}
			Catch {
				$this.Error = $_
				$this.ErrorHandler()
			}
	
	#		Return $this.ProcessData1($this.rc, "items")
			Return $this.ProcessData1($this.rc)
		}
	
		[Object]CustomerListChildren([Int]$ParentID){
			## Refresh / Clean KeyPair-container.
			$this.KeyPairs = @()
	
			## Add parameters as KeyPairs.
			$KeyPair1 = [PSObject]@{Key='customerID'; Value=$ParentID;}
			$this.KeyPairs += $KeyPair1
	
			$this.rc = $null
	
			## KeyPairs is mandatory in this query. returns limited list
			Try{
				$this.rc = $this.Connection.customerListChildren($this.PlainUser(), $this.PlainPass(), $this.KeyPairs)
			}
			Catch {
				$this.Error = $_
				$this.ErrorHandler()
			}
	
	#		Return $this.ProcessData1($this.rc, "items")
			Return $this.ProcessData1($this.rc)
		}
	
		[void]CustomerModify([Int]$CustomerID,[String]$PropertyName,[String]$PropertyValue){
			## Basic Customer-properties in KeyPairs
	
			## Validate $PropertyName
			If(!($this.CustomerValidation -contains $PropertyName)){
				Write-Host "Invalid customer field: $PropertyName."
				Break
			}
	
			#Mandatory (Key) customerid - (Value) the (customer) id of the ID of the existing service organization/customer/site being modified.
			#Mandatory (Key) customername - (Value) Desired name for the new customer or site. Maximum of 120 characters.
			#Mandatory (Key) parentid - (Value) the (customer) id of the parent service organization or parent customer for the new customer/site.
			
			## Data-caching for faster future-access. Additional data-lookup and key-check.
			If(!$this.CustomerData){
				$this.CustomerData = $this.customerlist() | Select-Object customerid,customername,parentid
			}
			## Lookup Data from cache for mandatory fields related to the $CustomerID.
			$CustomerName = ($this.CustomerData).where({ $_.customerID -eq $CustomerID }).CustomerName
			$ParentID = ($this.CustomerData).where({ $_.customerID -eq $CustomerID }).ParentID
	
			## For an Invalid CustomerID, No additional data is found.
			If(!$ParentID){
				Write-Host "Unknown CustomerID: $CustomerID."
				Break
			}
	
			## Refresh / Clean KeyPair-container.
			$this.KeyPairs = @()
	
			## Add Mandatory parameters as KeyPairs.
			$KeyPair1 = [PSObject]@{Key='customerID'; Value=$CustomerID;}
			$this.KeyPairs += $KeyPair1
			
			$KeyPair2 = [PSObject]@{Key="customername"; Value=$CustomerName;}
			$this.KeyPairs += $KeyPair2
			
			$KeyPair3 = [PSObject]@{Key="parentid"; Value=$ParentID;}
			$this.KeyPairs += $KeyPair3
	
			## PropertyName already validated
			$KeyPair4 = [PSObject]@{Key=$PropertyName; Value=$PropertyValue;}
			$this.KeyPairs += $KeyPair4
	
			## Using as [void]: No returndata needed/used.
			Try{
				$this.Connection.CustomerModify($this.PlainUser(), $this.PlainPass(), $this.KeyPairs)
			}
			Catch {
				$this.Error = $_
				$this.ErrorHandler()
			}
		}
	
		[Object]OrganizationPropertyList(){
			# No FilterArray-parameter adds an empty ParentIDs-Array. Returns all customers
			return $this.OrganizationPropertyList(@())
		}
		
		[Object]OrganizationPropertyList([Array]$ParentIDs){
			# Returns all Custom Customer-Properties and values.
	
			$this.rc = $null
			Try{
				$this.rc = $this.Connection.organizationPropertyList($this.PlainUser(), $this.PlainPass(), $ParentIDs, $false)
			}
			Catch {
				$this.Error = $_
				$this.ErrorHandler()
			}
	
			Return $this.ProcessData1($this.rc, "properties")
		}
	
		[Int]OrganizationPropertyID([Int]$OrganizationID,[String]$PropertyName){
			## Search the DevicePropertyID by Name (Case InSensitive).
			## Returns 0 (zero) if not found.
			$OrganizationPropertyID = 0
			
			$this.rc = $null
			Try{
				$this.rc = $this.Connection.OrganizationPropertyList($this.PlainUser(), $this.PlainPass(), $OrganizationID, $false)
			}
			Catch {
				$this.Error = $_
				$this.ErrorHandler()
			}
		
			ForEach ($OrganizationProperty in $this.rc.properties){
				If($OrganizationProperty.label -eq $PropertyName){
					$OrganizationPropertyID = $OrganizationProperty.PropertyID
				}
			}		
			
			Return $OrganizationPropertyID
		}
	
		[void]OrganizationPropertyModify([Int]$OrganizationID,[Int]$OrganizationPropertyID,[String]$OrganizationPropertyValue){
	
			$OrganizationProperty = [PSObject]@{PropertyID=$OrganizationPropertyID; value=$OrganizationPropertyValue; PropertyIDSpecified='True';}
	#		$Organization = [PSObject]@{OrganizationID=$OrganizationID; properties=$OrganizationProperty; OrganizationIDSpecified='True';}
			$Organization = [PSObject]@{CustomerID=$OrganizationID; properties=$OrganizationProperty; CustomerIDSpecified='True';}
			
			[void]$this.OrganizationPropertyModify($Organization)
		
		}		
		
		[void]OrganizationPropertyModify([Int]$OrganizationID,[String]$OrganizationPropertyName,[String]$OrganizationPropertyValue){
		
			[Int]$OrganizationPropertyID = $this.OrganizationPropertyID($OrganizationID,$OrganizationPropertyName)
			If ($OrganizationPropertyID -gt 0){
				[void]$this.OrganizationPropertyModify($OrganizationID,$OrganizationPropertyID,$OrganizationPropertyValue)
			}
			Else{
				## Throw Error
				Write-Host "OrganizationProperty '$OrganizationPropertyName' not found on this Customer."
				Break
			}
		}		
			
		[void]OrganizationPropertyModify([Array]$OrganizationsPropertyArray){
		
			## Organization-layout:
			# $Organization = [PSObject]@{CustomerID=''; properties=''; CustomerIDSpecified='True';}
			# $Organization = New-Object -TypeName ($this.NameSpace + '.organizationProperties')
			## properties hold an array of DeviceProperties
	
			## Individual OrganizationProperty layout:
			# $OrganizationProperty = [PSObject]@{PropertyID=''; value=''; PropertyIDSpecified='True';}
			# $OrganizationProperty = New-Object -TypeName ($this.NameSpace + '.organizationProperty')
	
			If ($OrganizationsPropertyArray){
				Try{
					$this.Connection.OrganizationPropertyModify($this.PlainUser(), $this.PlainPass(), $OrganizationsPropertyArray)
				}
				Catch {
					$this.Error = $_
					$this.ErrorHandler()
				}
			}
			Else{
	#			Write-Host "INFO:Nothing to save"
			}
			
		}
	
		
		
		#EndRegion
	
		#Region DeviceData
		[Object]DeviceList([Int]$ParentID){
			## Use default Settings for DeviceList
			Return $this.Devicelist($ParentID,'true','false')
		}
		
		[Object]DeviceList([Int]$ParentID,[String]$Devices,[String]$Probes){
			## Returns only Managed/Imported Items.
	
			## Refresh / Clean KeyPair-container.
			$this.KeyPairs = @()
	
			## Add parameters as KeyPairs. Need to be unique Objects.
			$KeyPair1 = [PSObject]@{Key='customerID'; Value=$ParentID;}
			$this.KeyPairs += $KeyPair1
	
			$KeyPair2 = [PSObject]@{Key='devices'; Value=$Devices;}
			$this.KeyPairs += $KeyPair2
	
			$KeyPair3 = [PSObject]@{Key='probes'; Value=$Probes;}
			$this.KeyPairs += $KeyPair3
	
			$this.rc = $null
			Try{
				$this.rc = $this.Connection.deviceList($this.PlainUser(), $this.PlainPass(), $this.KeyPairs)
			}
			Catch{
				$this.Error = $_
				$this.ErrorHandler()
			}
			
	#		Return $this.ProcessData1($this.rc, "info")
			Return $this.ProcessData1($this.rc)
		}
	
	
		[Object]DeviceGet([Array]$DeviceIDs){
			## Refresh / Clean KeyPair-container.
			
			$this.KeyPairs = @()
	
			## Add parameters as KeyPairs.
			ForEach ($DeviceID in $DeviceIDs) {
	#			Write-Host "Adding key for $DeviceID"
				## Most likely an issue when adding multiple IDs.
				$this.KeyPair.Key = 'deviceID'
				$this.KeyPair.Value = $DeviceID
				$this.KeyPairs += $this.KeyPair
			}
	
			$this.rc = $null
	
			Try{
				$this.rc = $this.Connection.deviceGet($this.PlainUser(), $this.PlainPass(), $this.KeyPairs)
			}
			Catch {
				$this.Error = $_
				$this.ErrorHandler()
			}
			
			Return $this.ProcessData1($this.rc)
		}
	
		[Object]DeviceGetAppliance([Array]$ApplianceIDs){
			## Refresh / Clean KeyPair-container.
			$this.KeyPairs = @()
	
			## Add parameters as KeyPairs.
			ForEach ($ApplianceID in $ApplianceIDs) {
	#			Write-Host "Adding key for $DeviceID"
				$this.KeyPair.Key = 'applianceID'
				$this.KeyPair.Value = $ApplianceID
				$this.KeyPairs += $this.KeyPair
			}
	
			$this.rc = $null
		
			Try{
				$this.rc = $this.Connection.deviceGet($this.PlainUser(), $this.PlainPass(), $this.KeyPairs)
			}
			Catch {
				$this.Error = $_
				$this.ErrorHandler()
			}
			
			Return $this.ProcessData1($this.rc)
		}
			
		[Object]DeviceGetStatus([Int]$DeviceID){
			## Refresh / Clean KeyPair-container.
			$this.KeyPairs = @()
	
			## Add parameters as KeyPairs.
			$KeyPair1 = [PSObject]@{Key='deviceID'; Value=$DeviceID;}
			$this.KeyPairs += $KeyPair1
	
			$this.rc = $null
		
			Try{
				$this.rc = $this.Connection.deviceGetStatus($this.PlainUser(), $this.PlainPass(), $this.KeyPairs)
			}
			Catch {
				$this.Error = $_
				$this.ErrorHandler()
			}
			
	#		Return $this.ProcessData1($this.rc, "info")
			Return $this.ProcessData1($this.rc)
		}
	
		[Object]DevicePropertyList([Array]$DeviceIDs,[Array]$DeviceNames,[Array]$FilterIDs,[Array]$FilterNames){
			## Reports the Custom Device-Properties and values. Uses filter-arrays.
			## Names are Case-sensitive.
			## Returns both Managed and UnManaged Devices.
	
			$this.rc = $null
	
			Try{
				$this.rc = $this.Connection.devicePropertyList($this.PlainUser(), $this.PlainPass(), $DeviceIDs,$DeviceNames,$FilterIDs,$FilterNames,$false)
			}
			Catch {
				$this.Error = $_
				$this.ErrorHandler()
			}
	
			Return $this.ProcessData1($this.rc, "properties")
		}
	
		[Int]DevicePropertyID([Int]$DeviceID,[String]$PropertyName){
			## Search the DevicePropertyID with Name-Filter (Case InSensitive).
			## Returns 0 (zero) if not found.
			$DevicePropertyID = 0
			
			$this.rc = $null
			Try{
				$this.rc = $this.Connection.devicePropertyList($this.PlainUser(), $this.PlainPass(), $DeviceID,$null,$null,$null,$false)
			}
			Catch {
				$this.Error = $_
				$this.ErrorHandler()
			}
		
			ForEach ($DeviceProperty in $this.rc.properties){
				If($DeviceProperty.label -eq $PropertyName){
					$DevicePropertyID = $DeviceProperty.devicePropertyID
				}
			}		
			
			Return $DevicePropertyID
		}
	
		[void]DevicePropertyModify([Int]$DeviceID,[Int]$DevicePropertyID,[String]$DevicePropertyValue){
	
			## Create a custom DevicePropertyArray. Details in main DevicePropertyModify method.
			$DeviceProperty = [PSObject]@{devicePropertyID=$DevicePropertyID; value=$DevicePropertyValue; devicePropertyIDSpecified='True';}
			$Device = [PSObject]@{deviceID=$DeviceID; properties=$DeviceProperty; deviceIDSpecified='True';}
			
			[void]$this.DevicePropertyModify($Device)
		
		}		
		
		[void]DevicePropertyModify([Int]$DeviceID,[String]$DevicePropertyName,[String]$DevicePropertyValue){
		
			[Int]$DevicePropertyID = $this.DevicePropertyID($DeviceID,$DevicePropertyName)
			If ($DevicePropertyID -gt 0){
				[void]$this.DevicePropertyModify($DeviceID,$DevicePropertyID,$DevicePropertyValue)
			}
			Else{
				## Throw Error
				Write-Host "DeviceProperty '$DevicePropertyName' not found on this Device."
				Break
			}
	
		}		
			
		[void]DevicePropertyModify([Array]$DevicesPropertyArray){
		
			## Device-layout:
			# $Device = [PSObject]@{deviceID=''; properties=''; deviceIDSpecified='True';}
			# $Device = New-Object -TypeName ($this.NameSpace + '.deviceProperties')
			## properties hold an array of DeviceProperties
	
			## Individual DeviceProperty layout:
			# $DeviceProperty = [PSObject]@{devicePropertyID=''; value=''; devicePropertyIDSpecified='True';}
			# $DeviceProperty = New-Object -TypeName ($this.NameSpace + '.deviceProperty')
	
			If ($devicesPropertyArray){
				Try{
					$this.Connection.devicePropertyModify($this.PlainUser(), $this.PlainPass(), $devicesPropertyArray)
				}
				Catch {
					$this.Error = $_
					$this.ErrorHandler()
				}
			}
			Else{
	#			Write-Host "INFO:Nothing to save"
			}		
		}
	
		[Object]DeviceAssetInfoExportDevice(){
			## Reports Monitored Assets. Work In Progress
			
	#		## Class: DeviceData
	#		##   deviceAssetInfoExport						Deprecated
	#		##	 deviceAssetInfoExportDevice
	#		##	 deviceAssetInfoExportDeviceWithSettings
	#		##
	#		## Reports all Monitored Assets and Details. No filtering by CustomerID or DeviceID. Reports All Assets.
	#		## Use without Header-formatting (has sub-headers). Device.customerid=siteid.
	#		## Generating this list takes quite a long time. Might even time-out.
	#		#$rc = $nws.deviceAssetInfoExport2("0.0", $username, $password)		#Error - nonexisting
	#		#$ri = $nws.deviceAssetInfoExport("0.0", $username, $password)		#Error - unsupported version
	#		#$ri = $nws.deviceAssetInfoExportDevice("0.0", $username, $password)
	#		#$PairClass="info"
	
			$this.rc = $null
		
			Try{
				$this.rc = $this.Connection.deviceAssetInfoExportDevice("0.0", $this.PlainUser(), $this.PlainPass())
			}
			Catch {
				$this.Error = $_
				$this.ErrorHandler()
			}
			
			Return $this.rc
	#		Return $this.ProcessData1($this.rc, "info")
		}
	
		[Object]DeviceAssetInfoExportDeviceWithSettings($DeviceIDs){
			## Reports Monitored Assets.
			## Calls Full Command with Parameters
			Return $this.DeviceAssetInfoExportDeviceWithSettings($DeviceIds,$null,$null,$null)
		}
	
		[Object]DeviceAssetInfoExportDeviceWithSettings([Array]$DeviceIDs,[Array]$DeviceNames,[Array]$FilterIDs,[Array]$FilterNames){
			## Reports Monitored Assets.
			## Currently returns all categories for the selected devices. TODO: category-filtering. 
	
	#		From Documentation:
	#		http://mothership.n-able.com/dms/javadoc_ei2/com/nable/nobj/ei2/ServerEI2_PortType.html#deviceAssetInfoExportDeviceWithSettings-java.lang.String-java.lang.String-com.nable.nobj.ei2.T_KeyPair:A-
	#
	#		Use only ONE of the following options to limit information to certain devices 	 
	#		"TargetByDeviceID" - value for this key is an array of deviceids 	 
	#		"TargetByDeviceName" - value for this key is an array of devicenames 	 
	#		"TargetByFilterID" - value for this key is an array of filterids 	 
	#		"TargetByFilterName" - value for this key is an array filternames 	 
	
			$this.KeyPairs = @()
			$this.KeyPair.Key = $null
	
			## Add only one of the parameters as KeyPair. by priority.
			If ($DeviceIDs){
				$this.KeyPair.Key = 'TargetByDeviceID'
				$this.KeyPair.Value = $DeviceIDs
			}ElseIf($FilterIDs){
				$this.KeyPair.Key = 'TargetByFilterID'
				$this.KeyPair.Value = $FilterIDs
			}ElseIF($DeviceNames){
				$this.KeyPair.Key = 'TargetByDeviceName'
				$this.KeyPair.Value = $DeviceNames
			}ElseIf($FilterNames){
				$this.KeyPair.Key = 'TargetByFilterName'
				$this.KeyPair.Value = $FilterNames
			}
	
			If (!$this.KeyPair.Key){
				## TODO: Throw Error
				Break
			}
			$this.KeyPairs += $this.KeyPair
	
	
	#		## Documentation On Inclusion/Exclusion:
	#		## Key = "InformationCategoriesInclusion" and Value = String[] {"asset.device", "asset.os"} then only information for these two categories will be returned. 	 
	#		## Key = "InformationCategoriesExclusion" and Value = String[] {"asset.device", "asset.os"}
	#		## Work in Progress
	
	#		$KeyPair2 = [PSObject]@{Key="InformationCategoriesInclusion"; Value=[Array]{"asset.device", "asset.os"};}
	
	#		$KeyPair2 = [PSObject]@{Key="InformationCategoriesExclusion"; Value=[Array]{"asset.device", "asset.os"};}
	
	#		$KeyPair2 = New-Object -TypeName ($this.namespace + '.tKeyPair')
	#		$KeyPair2.Key = 'InformationCategoriesExclusion'
	#		$KeyPair2.Value = [Array]{"asset.application", "asset.os"}
			
	#		$this.KeyPairs += $KeyPair2
	
	
			$this.rc = $null
			
			Try{
				$this.rc = $this.Connection.deviceAssetInfoExportDeviceWithSettings("0.0", $this.PlainUser(), $this.PlainPass(), $this.KeyPairs)
				#$this.rc = $this.Connection.deviceAssetInfoExport2("0.0", $this.PlainUser(), $this.PlainPass(), $this.KeyPairs)
			}
			Catch {
				$this.Error = $_
				$this.ErrorHandler()
			}
			
			## Todo: Parameter for what to return:
			##		Flat Object (ProcessData1) or 
			##		Multi-Dimesional Object (ProcessData2).
	#		Return $this.ProcessData2($this.rc, "info")
			Return $this.ProcessData2($this.rc)
		}
	
		#EndRegion
	
		#Region NCentralAppData
			
	#	## To Do
	#	## TODO - User/Role/AccessGroup as user-object.
	#	## TODO - Filter/Rule list (Not available through API yet)
	#	## TODO - AccessGroupGet Method not functioning yet.
		
		[Object]AccessGroupList([Int]$ParentID){
			## List All Access Groups
			## Mandatory valid CustomerID (SO/Customer/Site-level), does not seem to use it. 
	
			## Refresh / Clean KeyPair-container.
			$this.KeyPairs = @()
	
			## Add parameters as KeyPairs.
			$KeyPair1 = [PSObject]@{Key='customerID'; Value=$ParentID;}
			$this.KeyPairs += $KeyPair1
	
			$this.rc = $null
	
			Try{
				$this.rc = $this.Connection.accessGroupList($this.PlainUser(), $this.PlainPass(), $this.KeyPairs)
			}
			Catch {
				#$this.ErrorHandler($_)
				$this.Error = $_
				$this.ErrorHandler()
			}
			Return $this.ProcessData1($this.rc)
	
		}
	
		[Object]AccessGroupGet([Int]$GroupID,[Int]$ParentID,[Boolean]$IsCustomerGroup){
			## List Access Groups details. Work in Progress.
			## Uses groupID and customerGroup. Gets details for the specified AccessGroup.
			## Mandatory parameters ?? Error: '1012 Mandatory settings not present'
			
			## Refresh / Clean KeyPair-container.
			$this.KeyPairs = @()
	
			## Add parameters as KeyPairs.
			$KeyPair1 = [PSObject]@{Key='groupID'; Value=$GroupID;}
			$this.KeyPairs += $KeyPair1
	
	#		$KeyPair2 = [PSObject]@{Key='customerID'; Value=$ParentID;}
	#		$this.KeyPairs += $KeyPair2
	#
	#		$KeyPair3 = [PSObject]@{Key='customerGroup'; Value=$IsCustomerGroup;}
	#		$this.KeyPairs += $KeyPair3
	
			$this.rc = $null
	
			Try{
				$this.rc = $this.Connection.accessGroupGet($this.PlainUser(), $this.PlainPass(), $this.KeyPairs)
			}
			Catch {
				$this.Error = $_
				$this.ErrorHandler()
			}
		
			Return $this.ProcessData1($this.rc)
		}
	
		[Object]UserRoleList([Int]$ParentID){
			## List All User Roles
			## Mandatory valid CustomerID (SO/Customer/Site-level), does not seem to use it. 
	
			## Refresh / Clean KeyPair-container.
			$this.KeyPairs = @()
	
			## Add parameters as KeyPairs.
			$KeyPair1 = [PSObject]@{Key='customerID'; Value=$ParentID;}
			$this.KeyPairs += $KeyPair1
	
			$this.rc = $null
			Try{
				$this.rc = $this.Connection.userRoleList($this.PlainUser(), $this.PlainPass(), $this.KeyPairs)
			}
			Catch {
				$this.Error = $_
				$this.ErrorHandler()
			}
	
			Return $this.ProcessData1($this.rc)
	
		}
	
		[Object]UserRoleGet([Int]$UserRoleID,[Int]$ParentID){
			## List User Role details.
	
			## Refresh / Clean KeyPair-container.
			$this.KeyPairs = @()
	
			## Add parameters as KeyPairs.
			$KeyPair1 = [PSObject]@{Key='userRoleID'; Value=$UserRoleID;}
			$this.KeyPairs += $KeyPair1
	
			If($ParentID){
				$KeyPair2 = [PSObject]@{Key='customerID'; Value=$ParentID;}
				$this.KeyPairs += $KeyPair2
			}
			
			$this.rc = $null
	
			Try{
				$this.rc = $this.Connection.userRoleGet($this.PlainUser(), $this.PlainPass(), $this.KeyPairs)
			}
			Catch {
				$this.Error = $_
				$this.ErrorHandler()
			}
			
			Return $this.ProcessData1($this.rc)
		}
		
		#EndRegion
	
		#Region ClassSupport
	
		[void]Connect(){
		
			## Clear existing connection (if any)
			$this.Connection = $null
			$this.IsConnected = $false
			
			Try{
				## Connect to Soap-service. Use ErrorAction to enable Catching.
				## Explicit Namespace not needed at creation when used inside a Class.
				## Credentials needed for NCentral class-access/queries. Not checked for setting connection.
				#$this.Connection = New-Webserviceproxy $this.bindingURL -credential $this.creds -Namespace [NCentral_Connection]::NWSNameSpace -ErrorAction Stop
				$this.Connection = New-Webserviceproxy $this.bindingURL -credential $this.creds -ErrorAction Stop
				#$this.Connection = New-Webserviceproxy $this.bindingURL -ErrorAction Stop
			}
			Catch [System.Net.WebException]{
	#		    Write-Host ([string]::Format("Error : {0}", $_.Exception.Message))
				$this.Error = $_
				$this.ErrorHandler()
			}
	
			## Connection Properties/Methods
			#Write-host $this.connection | Get-Member -Force
	
			## Connecting agent info. Only available after succesful connection with Credentials.
	#		Write-Host $this.connection.useragent
	
	
			## API-Class Properties/Methods base
			$this.NameSpace = $this.connection.GetType().namespace
			#Write-host $this.NameSpace| Get-Member -Force
	
	
			## ToDo Determine NCentral Version		
			## Errors. DataType Error, Not CLS-compliant.
	#		$this.tCreds = New-Object -TypeName ($this.NameSpace + ".tCredentials")
	#		$this.tCreds.username = $this.PlainUser()
	#		$this.tCreds.password = $this.PlainPass()
	#		
	#		$this.NCVersion = $this.Connection.versionInfoGet($this.tCreds)
	#		Write-Host $this.NCVersion
	#		## Reset tCreds to obscure security-data.
	#		$this.tCreds = $null
	
			
			## TODO Make valid check on connection-error (incl. Try/Catch)
			## Now checking on data-retrieval.
	#		if ($this.Connection){
			if ($this.Connection.useragent){
				$this.IsConnected = $true
			}
	
		}
	
		[void]ErrorHandler(){
			$this.ErrorHandler($this.Error)
		}
	
		[void]ErrorHandler($ErrorObject){
		
			#Write-Host$ErrorObject.Exception|Format-List -Force
			#Write-Host ($ErrorObject.Exception.GetType().FullName)
			$global:ErrObj = $ErrorObject
	
	
			Write-Host ($ErrorObject.Exception.Message)
	#		Write-Host ($ErrorObject.ErrorDetails.Message)
			
	#		Known Errors List:
	#		Connection-error (https): There was an error downloading ..
	#	    1012 - Thrown when mandatory settings are not present in "settings".
	#	    2001 - Required parameter is null - Thrown when null values are entered as inputs.
	#	    2001 - Unsupported version - Thrown when a version not specified above is entered as input.
	#	    2001 - Thrown when a bad username-password combination is input, or no PSA integration has been set up.
	#	    2100 - Thrown when invalid MSP N-central credentials are input.
	#	    2100 - Thrown when MSP-N-central credentials with MFA are used.
	#	    3010 - Maximum number of users reached.
	#	    3012 - Specified email address is already assigned to another user.
	#	    3014 - Creation of a user for the root customer (CustomerID 1) is not permitted.
	#	    3014 - When adding a user, must not be an LDAP user.
	#		3022 - Customer/Site already exists.
	#		3026 - Customer name length has exceeded 120 characters.
	#    	3026 - Customer name length has exceeded 120 characters.
	#		4000 - SessionID not found or has expired.
	#	    5000 - An unexpected exception occurred.
	#		5000 - javax.validation.ValidationException: Unable to validate UI session
	#    	9910 - Service Organization already exists.
			
			Break
		}
	
		[PSObject]ProcessData1([Array]$InArray){
			## Most Common PairClass is Info or Item.
			## Fill if not specified.
	
			# Hard (Pre-)Fill
			$PairClass = "info"
	
			## Base on found Array-Properties if possible
			If($InArray.Count -gt 0){
				$PairClasses = $InArray[0] | Get-member -MemberType Property
				$PairClass = $PairClasses[0].Name
			}
			
			Return $this.ProcessData1($InArray,$PairClass)
		}
		
		[PSObject]ProcessData1([Array]$InArray,[String]$PairClass){
			
			## Received Dataset KeyPairs 2 List/Columns
			$OutObjects = @()
			
			if ($InArray){
				foreach ($InObject in $InArray) {
	
	#				$ThisObject = New-Object PSObject				## In this routine the object is created at start. Properties are added with values.
					$Props = @{}									## In this routine the object is created at the end. Properties from a list.
	
					## Add a Reference-Column at Object-Level
					If ($PairClass -eq "Properties"){
						## CustomerLink if Available
						if(Get-Member -inputobject $InObject -name "CustomerID"){
	#						$ThisObject | Add-Member -MemberType NoteProperty -Name 'CustomerID' -Value $InObject.CustomerID -Force
							$Props.add('CustomerID',$InObject.CustomerID)
						}
						
						## DeviceLink if Available
						if(Get-Member -inputobject $InObject -name "DeviceID"){
	#						$ThisObject | Add-Member -MemberType NoteProperty -Name 'DeviceID' -Value $InObject.DeviceID -Force
							$Props.add('DeviceID',$InObject.DeviceID)
						}
					}
	
					## Convert all (remaining) keypairs to Properties
					foreach ($item in $InObject.$PairClass) {
	
						## Cleanup the Key and/or Value before usage.
						If ($PairClass -eq "Properties"){
							$Header = $item.label
						}
						Else{
							If($item.key.split(".")[0] -eq 'asset'){	##Should use ProcessData2 (ToDo)
								$Header = $item.key
							}
							Else{
								$Header = $item.key.split(".")[1]
							}
						}
	
						## Ensure a Flat Value
						If ($item.value -is [Array]){
							$DataValue = $item.Value[0]
						}
						Else{
							$DataValue = $item.Value
						}
	
						## Now add the Key/Value pairs.
	#					$ThisObject | Add-Member -MemberType NoteProperty -Name $Header -Value $DataValue -Force
	
						 # if a key is found that already exists in the hashtable
						if ($Props.ContainsKey($Header)) {
							# either overwrite the value 'Last-One-Wins'
							# or do nothing 'First-One-Wins'
							#if ($this.allowOverwrite) { $Props[$Header] = $DataValue }
						}
						else {
							$Props[$Header] = $DataValue
						}					
	#					$Props.add($Header,$DataValue)
	
					}
					$ThisObject = New-Object -TypeName PSObject -Property $Props	#Alternative option
	
					## Add the Object to the list
					$OutObjects += $ThisObject
				}
			}
			## Return the list of Objects
			Return $OutObjects
	#		$OutObjects
	#		Write-Output $OutObjects
		}
	
		[PSObject]ProcessData2([Array]$InArray){
			## Most Common PairClass is Info or Item.
			## Fill if not specified.
			
			# Hard (Pre-)Fill
			$PairClass = "info"
	
			## Base on found Array-Properties if possible
			If($InArray.Count -gt 0){
				$PairClasses = $InArray[0] | Get-member -MemberType Property
				$PairClass = $PairClasses[0].Name
			}
	
			Return $this.ProcessData2($InArray,$PairClass)
		}
	
		[PSObject]ProcessData2([Array]$InArray,[String]$PairClass){
			
			## Received Dataset KeyPairs 2 Object
			## Key-structure: asset.service.caption.28
			## 
			## Only One Asset at the time can be processed.
	
			$OutObjects = @()
			$SortedInfo = @()
			$Props = @{}
	
			$OldArrayID = ""
			[Array]$ArrayProperty = $null
			$OldArrayItemID = ""
			[HashTable]$ArrayItemProperty = @{}
			
			if ($InArray){
				## Get DeviceId to repeat in every Object-Property
				$CurrentDeviceID = ($InArray.$PairClass | Where-Object {$_.key -eq 'asset.device.deviceid'} | Select-Object value).value
				Write-Debug "DeviceObject CurrentDeviceID: $CurrentDeviceID"
				
				## Sort for processing. Column 2,4
				$SortedInfo = $InArray.$PairClass | Sort-Object @{Expression={$_.key.split(".")[1] + $_.key.split(".")[3]}; Descending=$false}
	
				$Props = @{}		## In this routine the object is created at the end. Properties from this list.
	
				## Process the Keypairs
				ForEach ($InObject in $SortedInfo) {
	
					## Convert the keypairs to Properties
					ForEach ($item in $InObject) {
						
						## Add property direct if column4 does not exist
						## --> Changed to only asset.device items. Header changed accordingly.
						## Build and Add Array if int
	
	#					If(($item.key.split(".")[3]) -lt 0){
						If(($item.key.split(".")[1]) -eq 'device'){
							## Add property as a Non-Array.
							Write-Debug $item.key
	#						$Header = ($item.key.split(".")[1])+"."+($item.key.split(".")[2])
							$Header = $item.key.split(".")[2]
							$DataValue = $item.Value
	
							Write-Debug $Header":"$DataValue
	
							$Props[$Header] = $DataValue
							
						}
						Else{
							## Add property as an Array.
							## Make an object-Array Before Adding
							
							## Key-structure: asset.service.caption.28
							## Outer-loop differenting on column 2		MainObject Array-Property
							## Inner-loop differenting on column 4		
							## ObjectItem is column 2.4  (easysplit)	Array-ItemID
							## ObjectHeaders are Column 3				Array-Item-PropertyHeader
							
							
							## Create the Property ItemID from the Key-Name
							$ArrayItemId = ($item.key.split(".")[1])+"."+($item.key.split(".")[3])
	
							## Is this a new Array-Item?
							If($ArrayItemId -ne $OldArrayItemID){
								## Add the current object to the array-property and start over
								
								If($OldArrayItemID -ne ""){
									Write-Debug "ArrayItemId = $ArrayItemId"
									$ArrayItem = New-Object -TypeName PSObject -Property $ArrayItemProperty
									$ArrayProperty += $ArrayItem
								}							
	
								$ArrayItemProperty = @{}
								$OldArrayItemID = $ArrayItemId
								
								## Add an unique ID-Column and the DeviceID to the item.
								$ArrayItemProperty["ItemId"]=$ArrayItemId
	#							$ArrayItemProperty.add("ItemId", $ArrayItemId)
								$ArrayItemProperty["DeviceId"]=$CurrentDeviceID
							}
	
	
							## Create the Main Property Name from the Key-Name
							$ArrayId = ($item.key.split(".")[1])
	
							## Is this a new Array?
							If($ArrayId -ne $OldArrayID){
								## Add the current array to the main object and start a new one
								
								If($OldArrayID -ne ""){
									Write-Debug "ArrayId = $ArrayId"
									$Props[$OldArrayId] = $ArrayProperty
								}
	
								$ArrayProperty = $null
								$OldArrayID = $ArrayId
							}
	
							
							## Add the current item to the array-item
							$Header2 = ($item.key.split(".")[2])
							$DataValue2 = $item.Value
							Write-Debug "Header2 = $Header2"
							Write-Debug "DataValue2 = $DataValue2"
							
							$ArrayItemProperty[$Header2]=$DataValue2
	
						}
	
					## End of item-loop
					}
					
				## End of Keypairs-loop
				}
	
				## Debug
	#			$this.TestVar = $Props
				
				$ThisObject = New-Object -TypeName PSObject -Property $Props	#Alternative option
	
				## Add the Object to the list
				$OutObjects += $ThisObject
	
			## End of Input-check
			}
	
			## Return the list of Objects
			Return $OutObjects
		}
	
		hidden [String]PlainUser(){
			Return $this.Creds.GetNetworkCredential().UserName
		}
		
		hidden [String]PlainPass(){
			Return $this.Creds.GetNetworkCredential().Password
		}
		
		#EndRegion
		
	#EndRegion	
			
	}
	
	
	Function NcConnected{
	<#
	.Synopsis
	Checks or initiates the NCentral connection.
	
	.Description
	Checks or initiates the NCentral connection.
	Returns $true if a connection established.
	
	#>
		
		$NcConnected = $false
		
		If (!$Global:_NCSession){
	#		Write-Host "No connection to NCentral Server found.`r`nUsing 'New-NCentralConnection' to connect."
			New-NCentralConnection
		}
	
		## Succesful connection?	
		If ($Global:_NCSession){
			$NcConnected = $true
		}
		Else{
			Write-Host "No valid connection to NCentral Server."
		}
		
		Return $NcConnected
	}
	
	#EndRegion
	
	#Region PowerShell CmdLets
	#	## To Do
	#	## TODO - Error-handling at CmdLet Level.
	#	## TODO - Add Examples to in-line documentation.
	#	## TODO - Additional CmdLets (DataExport, PSA, ...) 
	
	Function New-NCentralConnection{
	<#
	.Synopsis
	Connect to the NCentral server.
	
	.Description
	Connect to the NCentral server.
	Https is always used, since the data itself is unencrypted.
	
	The returned connection-object allows to extract and manipulate 
	NCentral Data through methods of the NCentral_Connection Class.
	
	To show available Commands, type:
	Get-NCHelp
	
	.Parameter ServerFQDN
	Specify the Server DNS-name for this Connection.
	The server needs to have a valid certficate for HTTPS.
	
	.Parameter PSCredential
	PowerShell-Credential object containing Username and
	Password for N-Central access. No MFA.
	
	.Parameter DefaultCustomerID
	Sets the default CustomerID for this instance.
	The CustomerID can be found in the customerlist.
		CustomerID  1	Root / System
		CustomerID 50 	First ServiceOrganization	(Default)
	
	.Example
	$PSUserCredential = Get-Credential -Message "Enter NCentral API-User credentials"
	New-NCentralConnection NCserver.domain.com $PSUserCredential
	
	
	.Example
	$NCentralFQDN = "<name>.<domain>"
	$SecurePass = ConvertTo-SecureString <PassWord> -AsPlainText -Force
	$PSUserCredential = New-Object PSCredential (<UserName>, $SecurePass)
	New-NCentralConnection $NCentralFQDN $PSUserCredential
	
	Use the 4 lines above inside a script for a fully-automated connection.
	
	#>
	
		[CmdletBinding()]
	
		Param(
			[Parameter(Mandatory=$false)][String]$ServerFQDN,
			[Parameter(Mandatory=$false)][PSCredential]$PSCredential,
			[Parameter(Mandatory=$false)][Int]$DefaultCustomerID = 50
		)
		Begin{
			## Check parameters
	
			## Clear the ServerFQDN if there is no . in it. Will create dialog.
			If ($ServerFQDN -notmatch "\.") {
				$ServerFQDN = $null
			}
	
		}
		Process{
			## Store the session in a global variable as the default connection.
	
			# Initiate the connection with the given information.
			# Prompts for additional information if needed.
			If ($ServerFQDN){
				If ($PSCredential){
					$Global:_NCSession = [NCentral_Connection]::New($ServerFQDN, $PSCredential)
				}
				Else {
					$Global:_NCSession = [NCentral_Connection]::New($ServerFQDN)
				}
			}
			Else {
				$Global:_NCSession = [NCentral_Connection]::New()
			}
	
			## ToDo: Check for succesful connection.
	
			
	
			# Set the default CustomerID for this session.
			$Global:_NCSession.DefaultCustomerID = $DefaultCustomerID
		}
		End{
			Write-Output $Global:_NCSession
		}
	}
	
	Function Get-NCHelp{
	<#
	.Synopsis
	Shows a list of available PS-NCentral commands and the synopsis.
	
	.Description
	Shows a list of available PS-NCentral commands and the synopsis.
	
	#>
		Get-Command -Module PS-NCentral | Select-Object Name |Get-Help | Select-Object Name,Synopsis
	}
	
	Function Get-NCTimeOut{
	<#
	.Synopsis
	Returns the max. time in seconds to wait for data returning from a (Synchronous) NCentral API-request.
	
	.Description
	Shows the maximum time to wait for synchronous data-request. Dialog in seconds.
	
	#>
		[CmdletBinding()]
	
		Param(
			[Parameter(Mandatory=$false,
					HelpMessage = 'Existing NCentral_Connection')]
			$NcSession
		)
		Begin{
				If (!$NcSession){
				If (-not (NcConnected)){
					Break
				}
				$NcSession = $Global:_NCSession
			}
		}
		Process{
			Write-Output ($NCSession.Connection.TimeOut/1000)
		}
		End{}
	}
	
	Function Set-NCTimeOut{
	<#
	.Synopsis
	Sets the max. time in seconds to wait for data returning from a (Synchronous) NCentral API-request.
	
	.Description
	Sets the maximum time to wait for synchronous data-request. Time in seconds.
	Range: 15-600. Default is 100.
	
	#>
		[CmdletBinding()]
	
		Param(
			[Parameter(Mandatory=$false,
					HelpMessage = 'TimeOut for NCentral Requests')]
			[Int]$TimeOut,
	
			[Parameter(Mandatory=$false,
					HelpMessage = 'Existing NCentral_Connection')]
			$NcSession
		)
		Begin{
			If (!$NcSession){
				If (-not (NcConnected)){
					Break
				}
				$NcSession = $Global:_NCSession
			}
	
			## Limit Range. Set to Default (100000) if too small or no value is given.
			$TimeOut = $TimeOut * 1000
			If ($TimeOut -lt 15000){
				Write-Host "Minimum TimeOut is 15 Seconds. Is now reset to default; 100 seconds"
				$TimeOut = 100000
			}
			If ($TimeOut -gt 600000){
				Write-Host "Maximum TimeOut is 600 Seconds. Is now reset to Max; 600 seconds"
				$TimeOut = 600000
			}
		}
		Process{
			$NCSession.Connection.TimeOut = $TimeOut
			Write-Output ($NCSession.Connection.TimeOut/1000)
		}
		End{}
	}
	
	Function Get-NCServiceOrganizationList{
	<#
	.Synopsis
	Returns a list of all ServiceOrganizations and their data.
	
	.Description
	Returns a list of all ServiceOrganizations and their data.
	
	#>
		[CmdletBinding()]
	
		Param(
			[Parameter(Mandatory=$false,
					HelpMessage = 'Existing NCentral_Connection')]
			$NcSession
		)
		
		Begin{
			#check parameters. Use defaults if needed/available
			If (!$NcSession){
				If (-not (NcConnected)){
					Break
				}
				$NcSession = $Global:_NCSession
			}
		}	
		Process{
	
		}
		End{
			Write-Output $NcSession.CustomerList($true)
		}
	}
	
	Function Get-NCCustomerList{
	<#
	.Synopsis
	Returns a list of all customers and their data. ChildrenOnly when CustomerID is specified.
	
	.Description
	Returns a list of all customers and their data.
	ChildrenOnly when CustomerID is specified.
	
	
	## TODO - Integrate Custom-properties
	#>
		[CmdletBinding()]
	
		Param(
			[Parameter(Mandatory=$false,
	#               ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 0,
				   HelpMessage = 'Existing Customer ID')]
			## Default-value is essential for output-selection.
			$CustomerID = 0,
			
			[Parameter(Mandatory=$false,
					HelpMessage = 'Existing NCentral_Connection')]
			$NcSession
		)
		
		Begin{
			#check parameters. Use defaults if needed/available
			If (!$NcSession){
				If (-not (NcConnected)){
					Break
				}
				$NcSession = $Global:_NCSession
			}
		}	
		Process{
	
		}
		End{
			Write-Debug "CustomerID: $CustomerID"
			If ($CustomerID -eq 0){
				## Return all Customers
				Write-Output $NcSession.CustomerList()
			}
			Else{
				## Return direct children only.
				Write-Output $NcSession.CustomerListChildren($CustomerID)
			}
		}
	}
	
	Function Get-NCCustomerPropertyList{
	<#
	.Synopsis
	Returns a list of all Custom-Properties for the selected CustomerID(s).
	
	.Description
	Returns a list of all Custom-Properties for the selected customers.
	If no customerIDs are supplied, data for all customers will be returned.
	
	## TODO - Integrate this in the default NCCustomerList.
	#>
		[CmdletBinding()]
	
		Param(
			[Parameter(Mandatory=$false,
	#               ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 0,
				   HelpMessage = 'Array of Existing Customer IDs')]
				[Alias("CustomerID")]
			[Array]$CustomerIDs,
			
			[Parameter(Mandatory=$false)]$NcSession
		)
		
		Begin{
			#check parameters. Use defaults if needed/available
		
			If (!$NcSession){
				If (-not (NcConnected)){
					Break
				}
				$NcSession = $Global:_NCSession
			}
		
		}
		Process{
	
		}
		End{
			If ($CustomerIDs){
				Write-Output $NcSession.OrganizationPropertyList($CustomerIDs)
			}
			Else{
				Write-Output $NcSession.OrganizationPropertyList()
			}
		
		}
	}
	
	Function Set-NCCustomerProperty{
	<#
	.Synopsis
	Fills the specified property(name) for the given CustomerID(s).
	
	.Description
	Fills the specified property(name) for the given CustomerID(s).
	This can be a default or custom property.
	CustomerID(s) must be supplied.
	Properties are cleared if no Value is supplied.
	
	#>
		[CmdletBinding()]
	
		Param(
			[Parameter(Mandatory=$true,
	#               ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 0,
				   HelpMessage = 'Array of Existing Customer IDs')]
				[Alias("CustomerID")]
			[Array]$CustomerIDs,
	
			[Parameter(Mandatory=$true,
	#               ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 1,
				   HelpMessage = 'Name of the Customer Custom-Property')]
				[Alias("PropertyName")]
			[String]$PropertyLabel,
	
			[Parameter(Mandatory=$false,
	#               ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 2,
				   HelpMessage = 'Value for the Customer Property')]
			[String]$PropertyValue = '',
			
			[Parameter(Mandatory=$false)]$NcSession
		)
		
		Begin{
			#check parameters. Use defaults if needed/available
			$CustomerProperty = $false
			If (!$NcSession){
				If (-not (NcConnected)){
					Break
				}
				$NcSession = $Global:_NCSession
			}
	#		If (!$CustomerIDs){
	#			## Issue when value comes from pipeline. Use Parameter-validation.
	#			If ($_NCSession.DefaultCustomerID){
	#				$CustomerID = $_NCSession.DefaultCustomerID
	#			}Else{
	#				Write-Host "No CustomerID specified."
	#				Break
	#			}
	#		}
			If (!$PropertyLabel){
				Write-Host "No Property-name specified."
				Break
			}
			If (!$PropertyValue){
				Write-Host "CustomerProperty '$PropertyLabel' will be cleared."
			}
			If ($NcSession.CustomerValidation -contains $PropertyLabel){
				## This is a standard CustomerProperty.
				$CustomerProperty = $true
			}
		}
		Process{
			ForEach($CustomerID in $CustomerIDs ){
				## Differentiate between Standard(Customer) and Custom(Organization) properties.
				If ($CustomerProperty){
					$NcSession.CustomerModify($CustomerID, $PropertyLabel, $PropertyValue)
				}
				Else{
					$NcSession.OrganizationPropertyModify($CustomerID, $PropertyLabel, $PropertyValue)
				}
			}
		}
		End{
		}
	}
	
	Function Get-NCProbeList{
	<#
	.Synopsis
	Returns the Probes for the given CustomerID(s).
	
	.Description
	Returns the Probes for the given CustomerID(s).
	If no customerIDs are supplied, all probes will be returned.
	
	#>
		[CmdletBinding()]
	
		Param(
			[Parameter(Mandatory=$false,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 0,
				   HelpMessage = 'Existing Customer ID')]
				[Alias("CustomerID")]
			[Array]$CustomerIDs,
	
			[Parameter(Mandatory=$false)]$NcSession
		)
		Begin{
			#check parameters. Use defaults if needed/available
			If (!$NcSession){
				If (-not (NcConnected)){
					Break
				}
				$NcSession = $Global:_NCSession
			}
			If (!$CustomerIDs){
				If (!$_NCSession.DefaultCustomerID){
					Write-Host "No CustomerID given."
					Break
				}
				$CustomerIDs = $_NCSession.DefaultCustomerID
			}
		}
		Process{
			ForEach ($CustomerID in $CustomerIDs){
				$NcSession.DeviceList($CustomerID,'false','true')|
				Select-Object deviceid,longname,customername,* -ErrorAction SilentlyContinue |
				Write-Output 
			}
		}
		End{
		}
	
	}
	
	Function Get-NCDeviceList{
	<#
	.Synopsis
	Returns the Managed Devices for the given CustomerID(s) and Sites below.
	
	.Description
	Returns the Managed Devices for the given CustomerID(s) and Sites below.
	If no customerIDs are supplied, all managed devices will be returned.
	
	## TODO - Confirmation if no CustomerID(s) are supplied (Full List).
	#>
		[CmdletBinding()]
	
		Param(
			[Parameter(Mandatory=$false,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 0,
				   HelpMessage = 'Existing Customer ID')]
				[Alias("CustomerID")]
			[Array]$CustomerIDs,
	
			[Parameter(Mandatory=$false)]$NcSession
		)
		Begin{
			#check parameters. Use defaults if needed/available
			If (!$NcSession){
				If (-not (NcConnected)){
					Break
				}
				$NcSession = $Global:_NCSession
			}
			If (!$CustomerIDs){
				If ($_NCSession.DefaultCustomerID){
					$CustomerID = $_NCSession.DefaultCustomerID
				}Else{
					Write-Host "No CustomerID specified."
					Break
				}
			}
		}
		Process{
			ForEach ($CustomerID in $CustomerIDs){
				$NcSession.DeviceList($CustomerID)|
				## CustomerID is not returned, only name. Pipeline to Get-NCDeviceInfo for CustomerID.
				#Select-Object customerid,customername,deviceid,longname,* -ErrorAction SilentlyContinue |
				Select-Object customername,deviceid,longname,* -ErrorAction SilentlyContinue |
				Write-Output 
			}
		}
		End{
		}
	}
	
	Function Get-NCDeviceID{
		<#
		.Synopsis
		Returns the DeviceID(s) for the given DeviceName(s). Case Sensitive, No Wildcards.
	
		.Description
		The returned objects contain extra information for verification.
		The supplied name(s) are Case Sensitive, No Wildcards allowed. 
		Also not-managed devices are returned.
		Nothing is returned for names not found.
		
		#>
		
		[CmdletBinding()]
	
		Param(
			[Parameter(Mandatory=$true,
				   ValueFromPipeline = $true,
	#               ValueFromPipelineByPropertyName = $true,
				   Position = 0,
				   HelpMessage = 'Array of existing Filter IDs')]
	#			[Alias("Name")]
			[Array]$DeviceNames,
			
			[Parameter(Mandatory=$false)]$NcSession
		)
		
		Begin{
			#check parameters. Use defaults if needed/available
			If (!$NcSession){
				If (-not (NcConnected)){
					Break
				}
				$NcSession = $Global:_NCSession
			}
			If (!$DeviceNames){
				Write-Host "No DeviceName(s) given."
				Break
			}
		}
		Process{
			## Collect the data for all Names. Case Sensitive, No Wildcards.
			## Only Returns found devices.
					
			ForEach ($DeviceName in $DeviceNames){
				## Use the NameFilter of the DevicePropertyList to find the DeviceID for now.
				## Limited Filter-options, but fast.
				$NcSession.DevicePropertyList($null,$DeviceName,$null,$null) |
				## Add additional Info and return only selected fields/Columns
				Get-NCDeviceInfo |
				Select-Object DeviceID,LongName,DeviceClass,CustomerID,CustomerName,IsManagedAsset |
				Write-Output 
			}
		
		}
		End{
		}
	}
	
	Function Get-NCDeviceLocal{
		Get-NCDeviceLocal -IsProbe $false
	}
	
	Function Get-NCDeviceLocal ($IsProbe){
		<#
		.Synopsis
		Returns the DeviceID, CustomerID and some more Info for the Local Computer.
	
		.Description
		Queries the local ApplicationID and returns the NCentral DeviceID.
		No Parameters recquired.
		
		#>
	
		Begin{
			#check parameters. Use defaults if needed/available
			If ($IsProbe) {
				$ApplianceConfig = ("{0}\N-able Technologies\Windows Software Probe\config\ApplianceConfig.xml" -f ${Env:ProgramFiles(x86)})
				$ServerConfig = ("{0}\N-able Technologies\Windows Software Probe\config\ServerConfig.xml" -f ${Env:ProgramFiles(x86)})
			}
			else {
				$ApplianceConfig = ("{0}\N-able Technologies\Windows Agent\config\ApplianceConfig.xml" -f ${Env:ProgramFiles(x86)})
				$ServerConfig = ("{0}\N-able Technologies\Windows Agent\config\ServerConfig.xml" -f ${Env:ProgramFiles(x86)})
			}
			
	
			If (-not (Test-Path $ApplianceConfig -PathType leaf)){
				Write-Host "No Local NCentral-agent Configuration found."
				Write-Host "Try using 'Get-NCDeviceID $Env:ComputerName'."
				Break
			}
			If (!$NcSession){
				If (-not (NcConnected)){
					Break
				}
				$NcSession = $Global:_NCSession
			}
		}
		Process{
			# Get appliance id
			$ApplianceXML = [xml](Get-Content -Path $ApplianceConfig)
			$ApplianceID = $ApplianceXML.ApplianceConfig.ApplianceID
			# Get management Info.
			$ServerXML = [xml](Get-Content -Path $ServerConfig)
			$ServerIP = $ServerXML.ServerConfig.ServerIP
			$ConnectIP = $NCsession.ConnectionURL
	
			If($ServerIP -ne $ConnectIP){
				Write-Host "The Local Device is Managed by $ServerIP. You are connected to $ConnectIP."
			}
			
			$NcSession.DeviceGetAppliance($ApplianceID)|
			## Return all Info, since already collected.
			Select-Object deviceid,longname,@{Name="managedby"; Expression={$ServerIP}},customerid,customername,deviceclass,licensemode,* -ErrorAction SilentlyContinue |
			Write-Output
		}
		End{
		}
	}
	
	Function Get-NCDevicePropertyList{
	<#
	.Synopsis
	Returns the Custom Properties of the DeviceID(s).
	
	.Description
	Returns the Custom Properties of the DeviceID(s).
	If no devviceIDs are supplied, all managed devices
	and their Custom Properties will be returned.
	
	## TODO - Confirmation if no DeviceID(s) are supplied (Full List).
	#>
		[CmdletBinding()]
	
		Param(
			[Parameter(Mandatory=$false,
	#               ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 0,
				   HelpMessage = 'Existing Device ID')]
				[Alias("DeviceID")]
			[Array]$DeviceIDs,
				
			[Parameter(Mandatory=$false)]$NcSession
		)
		
		Begin{
			#check parameters. Use defaults if needed/available
			If (!$NcSession){
				If (-not (NcConnected)){
					Break
				}
				$NcSession = $Global:_NCSession
			}
		}
		Process{
	
			If ($DeviceIDs){
				$NcSession.DevicePropertyList($DeviceIDs,$null,$null,$null)|
				## Make DeviceID the first column.
				Select-Object deviceid,* -ErrorAction SilentlyContinue |
				Write-Output
			}
			Else{
				Write-Host "Generating a full DevicePropertyList may take some time."
				
				$NcSession.DevicePropertyList($null,$null,$null,$null)|
				## Make DeviceID the first column.
				Select-Object deviceid,* -ErrorAction SilentlyContinue |
				Write-Output 
	
				Write-Host "Done."
			}
		}
		End{
		}
	}
	
	Function Get-NCDevicePropertyListFilter{
	<#
	.Synopsis
	Returns the Custom Properties of the Devices within the Filter(s).
	
	.Description
	Returns the Custom Properties of the Devices within the Filter(s).
	A filterID must be supplied. Hoover over the filter in the GUI to reveal its ID.
	
	#>
		[CmdletBinding()]
	
		Param(
			[Parameter(Mandatory=$true,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 0,
				   HelpMessage = 'Array of existing Filter IDs')]
				[Alias("FilterID")]
			[Array]$FilterIDs,
			
			[Parameter(Mandatory=$false)]$NcSession
		)
		
		Begin{
			#check parameters. Use defaults if needed/available
			If (!$NcSession){
				If (-not (NcConnected)){
					Break
				}
				$NcSession = $Global:_NCSession
			}
			If (!$FilterIDs){
				Write-Host "No FilterIDs given."
				Break
			}
		}
		Process{
			#Collect the data for all IDs.
			
			ForEach ($FilterID in $FilterIDs){
				#$NcSession.DevicePropertyListFilter($FilterID) |
				$NcSession.DevicePropertyList($null,$null,$FilterID,$null) |
				Write-Output 
			}
		
		}
		End{
		}
	}
	
	Function Set-NCDeviceProperty{
	<#
	.Synopsis
	Fills the Custom Property for the DeviceID(s).
	
	.Description
	Fills the Custom Property for the DeviceID(s).
	Properties are cleared if no Value is supplied.
	
	#>
		[CmdletBinding()]
	
		Param(
			[Parameter(Mandatory=$true,
	#               ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 0,
				   HelpMessage = 'Existing Device IDs')]
				[Alias("DeviceID")]
			[Array]$DeviceIDs,
	
			[Parameter(Mandatory=$true,
	#               ValueFromPipeline = $true,
	#               ValueFromPipelineByPropertyName = $true,
				   Position = 1,
				   HelpMessage = 'Name of the Device Custom-Property')]
				[Alias("PropertyName")]
			[String]$PropertyLabel,
	
			[Parameter(Mandatory=$true,
	#               ValueFromPipeline = $true,
	#               ValueFromPipelineByPropertyName = $true,
				   Position = 2,
				   HelpMessage = 'Value of the Device Custom-Property')]
			[String]$PropertyValue,
			
			[Parameter(Mandatory=$false)]$NcSession
		)
		
		Begin{
			#check parameters. Use defaults if needed/available
			If (!$NcSession){
				If (-not (NcConnected)){
					Break
				}
				$NcSession = $Global:_NCSession
			}
	#		If (!$DeviceIDs){
	#			## Issue when value comes from pipeline. Use Parameter-validation.
	#			Write-Host "No DeviceID specified."
	#			Break
	#		}
			If (!$PropertyLabel){
				Write-Host "No Property-name specified."
				Break
			}
			If (!$PropertyValue){
				Write-Host "DeviceProperty '$PropertyLabel' will be cleared."
			}
		}
		Process{
			ForEach($DeviceID in $DeviceIDs ){
				$NcSession.DevicePropertyModify($DeviceID, $PropertyLabel, $PropertyValue)
			}
		}
		End{
		}
	}
	
	Function Get-NCActiveIssuesList{
	<#
	.Synopsis
	Returns the Active Issues on the CustomerID-level and below.
	
	.Description
	Returns the Active Issues on the CustomerID-level and below.
	An additional Search/Filter-string can be supplied.
	
	If no customerID is supplied, Default Customer is used.
	The SiteID of the devices is returned (Not CustomerID).
	
	#>
		[CmdletBinding()]
	
		Param(
			[Parameter(Mandatory=$false,
				   #ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 0,
				   HelpMessage = 'Existing Customer ID')]
			[Int]$CustomerID,
	
			[Parameter(Mandatory=$false,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 1,
				   HelpMessage = 'Text to look for')]
			[String]$IssueSearchBy = "",
			
			[Parameter(Mandatory=$false)]$NcSession
		)
		
		Begin{
			#check parameters. Use defaults if needed/available
			If (!$NcSession){
				If (-not (NcConnected)){
					Break
				}
				$NcSession = $Global:_NCSession
			}
			If (!$CustomerID){
				If ($_NCSession.DefaultCustomerID){
					$CustomerID = $_NCSession.DefaultCustomerID
				}Else{
					Write-Host "No CustomerID specified."
					Break
				}
			}
		}
		Process{
			$NcSession.ActiveIssuesList($CustomerID, $IssueSearchBy)|
			Select-Object CustomerID,CustomerName,DeviceID,DeviceName,DeviceClass,ServiceName,TransitionTime,* -ErrorAction SilentlyContinue |
	#		Sort-Object TransitionTime -Descending | Select-Object @{n="SiteID"; e={$_.CustomerID}},CustomerName,DeviceID,DeviceName,DeviceClass,ServiceName,TransitionTime,NotifState,* -ErrorAction SilentlyContinue |
			Write-Output
		}
		End{
		}
	}
	
	Function Get-NCJobStatusList{
		<#
		.Synopsis
		Returns the Scheduled Jobs on the CustomerID-level and below.
		
		.Description
		Returns the Scheduled Jobs on the CustomerID-level and below.
		Including Discovery Jobs
			
		If no customerID is supplied, all Jobs are returned.
		The SiteID of the devices is returned (Not CustomerID).
		
		#>
			[CmdletBinding()]
		
			Param(
				[Parameter(Mandatory=$false,
					   #ValueFromPipeline = $true,
					   ValueFromPipelineByPropertyName = $true,
					   Position = 0,
					   HelpMessage = 'Existing Customer ID')]
				[Int]$CustomerID
			)
			
			Begin{
				#check parameters. Use defaults if needed/available
				If (!$NcSession){
					If (-not (NcConnected)){
						Break
					}
					$NcSession = $Global:_NCSession
				}
				If (!$CustomerID){
					If ($_NCSession.DefaultCustomerID){
						$CustomerID = $_NCSession.DefaultCustomerID
					}Else{
						Write-Host "No CustomerID specified."
						Break
					}
				}
			}
			Process{
				$NcSession.JobStatusList($CustomerID)|
				Select-Object CustomerID,CustomerName,DeviceID,DeviceName,DeviceClass,JobName,ScheduledTime,* -ErrorAction SilentlyContinue |
		#		Sort-Object ScheduledTime -Descending | Select-Object @{n="SiteID"; e={$_.CustomerID}},CustomerName,DeviceID,DeviceName,DeviceClass,ServiceName,TransitionTime,NotifState,* -ErrorAction SilentlyContinue |
				Write-Output
			}
			End{
			}
	}
		
	Function Get-NCDeviceInfo{
	<#
	.Synopsis
	Returns the General details for the DeviceID(s).
	
	.Description
	Returns the General details for the DeviceID(s).
	DeviceID(s) must be supplied, as a parameter or by PipeLine.
	
	#>
		[CmdletBinding()]
	
		Param(
			[Parameter(Mandatory=$true,
	#               ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 0,
				   HelpMessage = 'Existing Device IDs')]
	#			[ValidateScript({ $_ | ForEach-Object {(Get-Item $_).PSIsContainer}})]
				[Alias("DeviceID")]
			[Array]$DeviceIDs,
			
			[Parameter(Mandatory=$false)]$NcSession
		)
		
		Begin{
			#check parameters. Use defaults if needed/available
			If (!$NcSession){
				If (-not (NcConnected)){
					Break
				}
				$NcSession = $Global:_NCSession
			}
		}
		Process{
			#Collect the data for all IDs.
			ForEach ($DeviceID in $DeviceIDs){
				$NcSession.DeviceGet($DeviceID)|
				Select-Object deviceid,longname,customerid,customername,deviceclass,licensemode,* -ErrorAction SilentlyContinue |
				Write-Output
			}
		}
		End{
		}
	}
	
	Function Get-NCDeviceObject{
	<#
	.Synopsis
	Returns a Device and all asset-properties as an object.
	
	.Description
	Returns a Device and all asset-properties as an object.
	The asset-properties may contain multiple entries.
	
	#>
	
	<#
	Work in Progress. Calls Ncentral_Connection.DeviceAssetInfoExportWithSettings
	Returns information as an [Array of] Multi-dimentional object(s) with array Properties.
	
	ToDo: Options to Include/Exclude properties from the N-Central query.
			Needed for Speed/Performance improvement.
		
	#>
		[CmdletBinding()]
	
		Param(
			[Parameter(Mandatory=$true,
	#               ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 0,
				   HelpMessage = 'Existing Device IDs')]
	#			[ValidateScript({ $_ | ForEach-Object {(Get-Item $_).PSIsContainer}})]
				[Alias("DeviceID")]
			[Array]$DeviceIDs,
			
			[Parameter(Mandatory=$false)]$NcSession
		)
		
		Begin{
			#check parameters. Use defaults if needed/available
			If (!$NcSession){
				If (-not (NcConnected)){
					Break
				}
				$NcSession = $Global:_NCSession
			}
		}
		Process{
			#Collect the data for all IDs.
			ForEach ($DeviceID in $DeviceIDs){
				$NcSession.DeviceAssetInfoExportDeviceWithSettings($DeviceID)|	
				# Put General properties in front.
	#			Select-Object deviceid,longname,customerid,deviceclass,* -ErrorAction SilentlyContinue |
				Write-Output
			}
		}
		End{
	
		}
	}
	
	Function Get-NCDeviceStatus{
	<#
	.Synopsis
	Returns the Services for the DeviceID(s).
	
	.Description
	Returns the Services for the DeviceID(s).
	DeviceID(s) must be supplied, as a parameter or by PipeLine.
	
	#>
		[CmdletBinding()]
	
		Param(
			[Parameter(Mandatory=$true,
	#               ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 0,
				   HelpMessage = 'Existing Device IDs')]
				[Alias("DeviceID")]
			[Array]$DeviceIDs,
			
			[Parameter(Mandatory=$false)]$NcSession
		)
		
		Begin{
			#check parameters. Use defaults if needed/available
			If (!$NcSession){
				If (-not (NcConnected)){
					Break
				}
				$NcSession = $Global:_NCSession
			}
		}
		Process{
			ForEach($DeviceID in $DeviceIDs){
				$NcSession.DeviceGetStatus($DeviceID)|
				Select-Object deviceid,devicename,serviceid,modulename,statestatus,transitiontime,* -ErrorAction SilentlyContinue |
				Write-Output
			}
		}
		End{
		}
	}
	
	Function Get-NCAccessGroupList{
	<#
	.Synopsis
	Returns the list of AccessGroups at the specified CustomerID level.
	
	.Description
	Returns the list of AccessGroups at the specified CustomerID level.
	
	#>
		[CmdletBinding()]
	
		Param(
			[Parameter(Mandatory=$false,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 0,
				   HelpMessage = 'Existing Customer ID')]
			[Int]$CustomerID,
			
			[Parameter(Mandatory=$false)]$NcSession
		)
		
		Begin{
			#check parameters. Use defaults if needed/available
			If (!$NcSession){
				If (-not (NcConnected)){
					Break
				}
				$NcSession = $Global:_NCSession
			}
			If (!$CustomerID){
				If (!$_NCSession.DefaultCustomerID){
					Write-Host "No CustomerID given."
					Break
				}
				$CustomerID = $_NCSession.DefaultCustomerID
			}
		}
		Process{
		}
		End{
			Write-Output $NcSession.AccessGroupList($CustomerID)
		}
	}
	
	Function Get-NCUserRoleList{
	<#
	.Synopsis
	Returns the list of Roles at the specified CustomerID level.
	
	.Description
	Returns the list of Roles at the specified CustomerID level.
	
	#>
		[CmdletBinding()]
	
		Param(
			[Parameter(Mandatory=$false,
				   ValueFromPipeline = $true,
				   ValueFromPipelineByPropertyName = $true,
				   Position = 0,
				   HelpMessage = 'Existing Customer ID')]
			[Int]$CustomerID,
			
			[Parameter(Mandatory=$false)]$NcSession
		)
		
		Begin{
			#check parameters. Use defaults if needed/available
			If (!$NcSession){
				If (-not (NcConnected)){
					Break
				}
				$NcSession = $Global:_NCSession
			}
			If (!$CustomerID){
				If (!$_NCSession.DefaultCustomerID){
					Write-Host "No CustomerID given."
					Break
				}
				$CustomerID = $_NCSession.DefaultCustomerID
			}
		}
		Process{
		}
		End{
			Write-Output $NcSession.UserRoleList($CustomerID)
		}
	}
	
	#EndRegion
	
	#Region Module management
	# Best practice - Export the individual Module-commands.
	Export-ModuleMember -Function Get-NCHelp,
	NcConnected,
	New-NCentralConnection,
	Get-NCTimeOut,
	Set-NCTimeOut,
	Get-NCServiceOrganizationList,
	Get-NCCustomerList,
	Get-NCCustomerPropertyList,
	Set-NCCustomerProperty,
	Get-NCProbeList,
	Get-NCJobStatusList,
	Get-NCDeviceList,
	Get-NCDeviceID,
	Get-NCDeviceLocal,
	Get-NCDevicePropertyList,
	Get-NCDevicePropertyListFilter,
	Set-NCDeviceProperty,
	Get-NCActiveIssuesList,
	Get-NCDeviceInfo,
	Get-NCDeviceObject,
	Get-NCDeviceStatus,
	Get-NCAccessGroupList,
	Get-NCUserRoleList
	
	Write-Debug "Module PS-NCentral loaded"
	
	#EndRegion
	
