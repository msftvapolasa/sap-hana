function New-Library {
    <#
    .SYNOPSIS
        Bootstrap a new SAP Library

    .DESCRIPTION
        Bootstrap a new SAP Library

    .PARAMETER Parameterfile
        This is the parameter file for the library

    .PARAMETER DeployerFolderRelativePath
        This is the relative folder path to the folder containing the deployerparameter terraform.tfstate file


    .EXAMPLE 

    #
    #
    # Import the module
    Import-Module "SAPDeploymentUtilities.psd1"
    New-Library -Parameterfile .\PROD-WEEU-SAP_LIBRARY.json -DeployerFolderRelativePath ..\..\DEPLOYER\PROD-WEEU-DEP00-INFRASTRUCTURE\

    
.LINK
    https://github.com/Azure/sap-hana

.NOTES
    v0.1 - Initial version

.

    #>
    <#
Copyright (c) Microsoft Corporation.
Licensed under the MIT license.
#>
    [cmdletbinding()]
    param(
        #Parameter file
        [Parameter(Mandatory = $true)][string]$Parameterfile,
        #Deployer parameterfile
        [Parameter(Mandatory = $true)][string]$DeployerFolderRelativePath
    )

    Write-Host -ForegroundColor green ""
    Write-Host -ForegroundColor green "Deploying the library"

    $mydocuments = [environment]::getfolderpath("mydocuments")
    $filePath = $mydocuments + "\sap_deployment_automation.ini"
    $iniContent = Get-IniContent $filePath

    [IO.FileInfo] $fInfo = $Parameterfile
    $environmentname = ($fInfo.Name -split "-")[0]

    # Subscription
    $sub = $iniContent[$environmentname]["subscription"] 
    $repo = $iniContent["Common"]["repo"]
    $changed = $false

    if ($null -eq $sub -or "" -eq $sub) {
        $sub = Read-Host -Prompt "Please enter the subscription"
        $iniContent[$environmentname]["subscription"] = $sub
        $changed = $true
    }

    if ($null -eq $repo -or "" -eq $repo) {
        $repo = Read-Host -Prompt "Please enter the sap-hana repository path"
        $iniContent["Common"]["repo"] = $repo
        $changed = $true
    }

    if ($changed) {
        $iniContent | Out-IniFile -Force $filePath
    }

    $terraform_module_directory = $repo + "\deploy\terraform\bootstrap\sap_library"

    Write-Host -ForegroundColor green "Initializing Terraform"

    if (Test-Path ".terraform" -PathType Container) {
        $ans = Read-Host -Prompt ".terraform already exists, do you want to continue Y/N?"

        if ("Y" -ne $ans) {
            exit 0
        }
        else {
            $Command = " init -upgrade=true -reconfigure " + $terraform_module_directory
        }

    }
    else {
        $Command = " init -upgrade=true " + $terraform_module_directory
    }

    $Cmd = "terraform $Command"
    & ([ScriptBlock]::Create($Cmd)) 
    if ($LASTEXITCODE -ne 0) {
        throw "Error executing command: $Cmd"
    }

    Write-Host -ForegroundColor green "Running plan"
    if ($DeployerFolderRelativePath -eq "") {
        $Command = " plan -var-file " + $Parameterfile + " " + $terraform_module_directory
    }
    else {
        $Command = " plan -var-file " + $Parameterfile + " -var deployer_statefile_foldername=" + $DeployerFolderRelativePath + " " + $terraform_module_directory
    }


    $Cmd = "terraform $Command"
    & ([ScriptBlock]::Create($Cmd)) 
    if ($LASTEXITCODE -ne 0) {
        throw "Error executing command: $Cmd"
    }

    Write-Host -ForegroundColor green "Running apply"
    if ($DeployerFolderRelativePath -eq "") {
        $Command = " apply -var-file " + $Parameterfile + " " + $terraform_module_directory
    }
    else {
        $Command = " apply -var-file " + $Parameterfile + " -var deployer_statefile_foldername=" + $DeployerFolderRelativePath + " " + $terraform_module_directory
    }

    $Cmd = "terraform $Command"
    & ([ScriptBlock]::Create($Cmd))  
    if ($LASTEXITCODE -ne 0) {
        throw "Error executing command: $Cmd"
    }

    New-Item -Path . -Name "backend.tf" -ItemType "file" -Value "terraform {`n  backend ""local"" {}`n}" -Force

    $Command = " output remote_state_resource_group_name"
    $Cmd = "terraform $Command"
    $rgName = & ([ScriptBlock]::Create($Cmd)) | Out-String 
    if ($LASTEXITCODE -ne 0) {
        throw "Error executing command: $Cmd"
    }
    $iniContent[$environmentname]["REMOTE_STATE_RG"] = $rgName

    $Command = " output remote_state_storage_account_name"
    $Cmd = "terraform $Command"
    $saName = & ([ScriptBlock]::Create($Cmd)) | Out-String 
    if ($LASTEXITCODE -ne 0) {
        throw "Error executing command: $Cmd"
    }
    $iniContent[$environmentname]["REMOTE_STATE_SA"] = $saName

    $Command = " output tfstate_resource_id"
    $Cmd = "terraform $Command"
    $tfstate_resource_id = & ([ScriptBlock]::Create($Cmd)) | Out-String 
    if ($LASTEXITCODE -ne 0) {
        throw "Error executing command: $Cmd"
    }
    $iniContent[$environmentname]["tfstate_resource_id"] = $tfstate_resource_id


    $iniContent | Out-IniFile -Force $filePath


}
