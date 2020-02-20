This script is used to perform functionalities on the VMs that are running on top of standalone ESXI hosts
1. Stop VM
2. Reboot VM
3. Start VM
4. Backup VM (OVF tool must be installed)
5. Restart stuck services in ESXI (Does not affect running VMs)

Dependencies -
1. OVF Tool 4.3
   
   link - https://code.vmware.com/web/tool/4.3.0/ovf

2. POSH
   
   command - Install-Module -Name Posh-SSH (Run as Administrator)
   
   link - https://github.com/darkoperator/Posh-SSH 
   
3. PowerCLI 
   
   command - Install-Module -Name VMware.PowerCLI (Run as Administrator)
   
   link - https://www.powershellgallery.com/packages/VMware.PowerCLI/11.5.0.14912921
   
4. WinRar [For compressing the folders]
   
   
Configurable parameters
---------------------------

$global:logfile -> Log file location folder 

$global:user_password_file -> Specify the encrypted password file location of the user connected to ESXI 

$global:email_password_file -> Specify the encrypted password file location of the Email

$global:email -> Email Address

$global:email_to -> Email Recipients

$global:user -> User name that's used to connect to ESXI 

$global:final_dest -> Backup storage path

$global:vm_name -> VM name that's going to be backup

$global:ovf_location -> OVF tool location

$global:esxi_server -> IP address of ESXI server

$global:win_rar -> Location of WinRAR software

Creating encrypted password [Please follow these steps before script execution]
---------------------------------------------------------------------------------
1. $credential = Get-Credential
2. $credential.Password | ConvertFrom-SecureString | Set-Content password.txt

P.S - Decrytion is only possible in the same machine where the encryption is done, because it utilized  Windows Data Protection API
