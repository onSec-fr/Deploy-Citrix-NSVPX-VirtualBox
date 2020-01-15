# Deploy-Citrix-NSVPX-VirtualBox
 
##### Forked from [dbroeglin](https://gist.github.com/dbroeglin/0c9e512fc4640f2ceda22005650cd417 "dbroeglin")

This script allows you to deploy Citrix/Netscaler gateway for ESX on VirtualBox. 
Only for testing purposes.

1-  Download your VPX version for ESX from https://www.citrix.com/downloads/citrix-gateway/.
![](https://github.com/onSec-fr/Deploy-Citrix-NSVPX-VirtualBox/blob/master/Resources/img_1.png?raw=true)

2-  Open Powershell as administrator and navigate to VirtualBox installation directory.

3-  It may be necessary to disabled execution policy first : 

`Set-ExecutionPolicy RemoteSigned`

4- Run the script :
` .\Deploy-NSVPX-Vbox.ps1 -Package [zip_file] -VMName [vm_name] -Force -Verbose -Start`
->[zip_file] is the location of downloaded NSVPX package and [vm_name] the name you want to give to the VM.

5- If everything goes well you should see *"VM "NSVPX-13.0" has been successfully started."*
![](https://github.com/onSec-fr/Deploy-Citrix-NSVPX-VirtualBox/blob/master/Resources/img_2.png?raw=true)

6- Open VirtualBox, the newly created VM should be there !
![](https://github.com/onSec-fr/Deploy-Citrix-NSVPX-VirtualBox/blob/master/Resources/img_3.png?raw=true)
