<#
    .SYNOPSIS 

        Generates a new VirtualBox Netscaler instance from a Netscaler VPX ESX package.

    .PARAMETER Package

        Location of the VPX package to use.

    .PARAMETER VMName

        Name of the created VM.

    .PARAMETER MacAddress

        MAC address to set for the VM network interface.

        Defaults to: "00155D7E3100"

    .PARAMETER ForwardedPorts

        A list of ports forwarded from the host to the VM.

        Defaults to: @(
            @("ssh", 2022, 22),
            @("http", 2080, 80),
            @("https", 2443, 443)
        )
    .PARAMETER BridgedTo
    
        If not set, the network interface will be connected to NAT networking. If set
        create an interface bridged to the given network.

    .PARAMETER Force

        If the VM is already present destroy it and create a new one.

    .PARAMETER Start
        
        Automatically start the VM after creating it.

    .EXAMPLE

        ./New-NSVirtualBoxInstance.ps1 -Package $HOME/Downloads/NSVPX-ESX-11.1-49.16_nc.zip  -VMName NSVPX-11-1 -Force -Verbose -Start

    .NOTES

        Copyright 2017 Dominique Broeglin
		Forked : OnSec-fr

        MIT License

        Permission is hereby granted, free of charge, to any person obtaining a copy 
        of this software and associated documentation files (the ""Software""), to deal 
        in the Software without restriction, including without limitation the rights 
        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell 
        copies of the Software, and to permit persons to whom the Software is 
        furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in all 
        copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED *AS IS*, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
        OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE 
        SOFTWARE.

    .LINK

        http://dominique.broeglin.fr/2017/02/19/automated-netscaler-setup-on-virtualbox.html
#>
[CmdletBinding()]
Param (
    [Parameter(Mandatory=$True)]        
    [String]$Package,

    [Parameter(Mandatory=$True)]
    [String]$VMName,

    [String]$MacAddress = "00155D7E3100",

    [String[][]]$ForwardedPorts = @(
        @("ssh", 2022, 22),
        @("http", 2080, 80),
        @("https", 2443, 443)
    ),

    [String]$BridgedTo,

    [Switch]$Force,

    [Switch]$Start
)
$ErrorActionPreference = "Stop"

function New-TemporaryDirectory {
    $parent = [System.IO.Path]::GetTempPath()
    [string] $name = [System.Guid]::NewGuid()
    New-Item -ItemType Directory -Path (Join-Path $parent $name)
}

if($Force -and (
    (& ".\VBoxManage.exe" "list" "vms") | Select-String -Pattern "^`"$VMName`"")) {
    Write-Verbose "Removing existing VM '$VMName'..."
    & .\VBoxManage.exe "unregistervm" $VMName "--delete"
}

Write-Verbose "Expanding package $Package"
$TempDir = New-TemporaryDirectory

try {
    Expand-Archive -Path $Package -DestinationPath $TempDir
    $Ovf = Get-ChildItem -Recurse -Path $TempDir -Include *.ovf

    if (-not($Ovf)) {
        Write-Error "Unable to find OVF file in the expanded archive"
        return
    }

    Write-Verbose "Importing VM $Ovf..."
    & ".\VBoxManage.exe" import "`"$($Ovf.FullName)`"" "--vsys" "0" "--vmname" "$VMName"

    Write-Verbose "Setting MAC address to $MacAddress..."
    & .\VBoxManage.exe modifyvm $VMName "--macaddress1" $MacAddress 
    
    if (![String]::IsNullOrWhiteSpace($BridgedTo)) {
        Write-Verbose "Setting MAC address to $MacAddress..."
        & .\VBoxManage.exe modifyvm $VMName "--nic1" "bridged" "--bridgeadapter1" $BridgedTo 
    } else {
        Write-Verbose "Setting first interface to NAT network..."
        & .\VBoxManage.exe modifyvm $VMName "--nic1" "nat" 
    }

    Write-Verbose "Customizing BIOS..."
    & .\VBoxManage.exe setextradata $VMName "VBoxInternal/Devices/pcbios/0/Config/DmiBIOSVendor" "Phoenix Technologies LTD"
    & .\VBoxManage.exe setextradata $VMName "VBoxInternal/Devices/pcbios/0/Config/DmiBIOSVersion" "6.00"
    & .\VBoxManage.exe setextradata $VMName "VBoxInternal/Devices/pcbios/0/Config/DmiBIOSReleaseDate" "07/31/2013"
    & .\VBoxManage.exe setextradata $VMName "VBoxInternal/Devices/pcbios/0/Config/DmiBIOSReleaseMajor" 6
    & .\VBoxManage.exe setextradata $VMName "VBoxInternal/Devices/pcbios/0/Config/DmiBIOSReleaseMinor" 0
    & .\VBoxManage.exe setextradata $VMName "VBoxInternal/Devices/pcbios/0/Config/DmiBIOSFirmwareMajor" 6
    & .\VBoxManage.exe setextradata $VMName "VBoxInternal/Devices/pcbios/0/Config/DmiBIOSFirmwareMinor" 0
    & .\VBoxManage.exe setextradata $VMName "VBoxInternal/Devices/pcbios/0/Config/DmiSystemVendor" "VMware, Inc."
    & .\VBoxManage.exe setextradata $VMName "VBoxInternal/Devices/pcbios/0/Config/DmiSystemProduct" "VMware Virtual Platform"

    Write-Verbose "Setting up port forwarding for SSH, HTTP and HTTPS..."
    foreach($Forward in $ForwardedPorts) {
        & .\VBoxManage.exe modifyvm $VMName --natpf1 ("guest{0},tcp,,{1},,{2}" -f $Forward)
    }

    if ($Start) {
        Write-Verbose "Starting VM..."
        & .\VBoxManage.exe startvm $VMName
    }

} finally {
    if ($TempDir.Fullname.Length -gt 4) { 
        Remove-Item -Recurse $TempDir -Force
    } else {
        # Prevent full disk wipe out
        Write-Error "Refusing to delete directory '$TempDir' (too short)"
    } 
}