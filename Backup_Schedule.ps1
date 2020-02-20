<#
This script is scheduled for taking backup on VM 
Developer - K.Janarthanan
Date - 6/2/2020


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

P.S - Decryption is only possible in the same machine where the encryption is done, because it utilized  Windows Data Protection API

#>

$global:logfile="C:\Backup\Logs\"
$global:user_password_file="C:\Backup\Secret\user_password.txt" 
$global:email_password_file="C:\Backup\Secret\email_password.txt"
$global:email="mail server address"
$global:email_to="mail address"
$global:user = "user name"
$global:final_dest="C:\Backup\VM_Backup"
$global:vm_name="bk-schedule"
$global:ovf_location='C:\Program Files\VMware\VMware OVF Tool'
$global:esxi_server="192.168.32.213"
$global:win_rar="C:\Program Files\WinRar"

#Scripts Starts

$bk_date=Get-Date -Format d
$global:logfile=$global:logfile+$bk_date+"-Log.txt"

#Remove the log file if its already present
if (Test-Path $global:logfile  -PathType Leaf)
    {
    Remove-Item -path $global:logfile 
    }

#Log function
    function log_file {
    param ($message)

    $time=Get-Date -Format G 
    "$time : $message" >> $global:logfile
}

#Mail Sending
function mail_log{

Start-Sleep -s 15 

$encrypted = Get-Content $global:email_password_file | ConvertTo-SecureString
$mail_credential = New-Object System.Management.Automation.PsCredential($global:email,$encrypted)

$Attachment = $global:logfile 
$Subject = "Logs of Backup"
$Body = "<h4>Hi, <br>Logs of the backup Git server is attached!</h4><br><br>------This is from automated script------"
$SMTPServer = "smtp.gmail.com"
$SMTPPort = "587"
Send-MailMessage -From $global:email -to $global:email_to -Subject $Subject -Body $Body -BodyAsHtml -SmtpServer $SMTPServer -Port $SMTPPort -UseSsl -Credential $mail_credential -Attachments $Attachment
}

log_file -message "Script is started"

#Checking whether ovftool is present in the provided location
log_file -message "Switched to ovftool location"
cd $global:ovf_location

if (Test-Path '.\ovftool.exe' -PathType Leaf){

    #Remote Login (SSH)
    try{
        #Connect SSH
        $secureStringPwd = Get-Content $global:user_password_file | ConvertTo-SecureString
        $Credent = New-Object System.Management.Automation.PsCredential($global:user,$secureStringPwd)

        $session_info=New-SSHSession -Computername $global:esxi_server -Credential $Credent -AcceptKey:$true
        $session_id=$session_info | select SessionID -ExpandProperty SessionID
        log_file -message "SSH into the server"
    }
    
    catch{
        log_file -message "Unable to SSH into Server"
        log_file -message "Exited from script"
        mail_log
        exit
    }

    try{

        $name=$global:vm_name

        #Below piece of code is written because most VM names have "[ ]" in it. 
        #In VMware these characters are excluded in the VM name. To filter use below code

        $list=($name | Select-String "\[" -AllMatches).Matches.Index
    
        $count=0
    
        foreach ($i in $list)
        {
        $name=$name.Insert(($i+$count),"\")
        $count+=1
        }
    
        $query="vim-cmd vmsvc/getallvms | grep"
        $final_query=$query+" '"+$name+"'"
    
        
        $data=(Invoke-SSHCommand -Index $session_id -Command $final_query).Output
        log_file -message  "Server Output -> $data"
    
        #Getting ID
        $final_query=$query+" '"+$name+"'"+" | cut -f 1 -d ' '"
    
        $vm_id=(Invoke-SSHCommand -Index $session_id -Command $final_query).Output
    
        log_file -message "VM ID of $name is : $vm_id"
    }
    
    catch{
        log_file -message "Something went wrong while getting the VM ID."
        log_file -message "Exited from script"
        mail_log
        exit
    }

    try{
    #Power off VM for taking backup
    log_file -message "Shutting down VM to take backup"
    $operation_query="vim-cmd vmsvc/power.off "+$vm_id

    $op_id=(Invoke-SSHCommand -Index $session_id -Command $operation_query).Output
                    
    log_file -message "VM $name status : $op_id"
    }

    catch{
        log_file -message "Something went wrong during Power operation of VM"
        mail_log
        exit
    }

    try{
    $secureStringPwd = Get-Content $global:user_password_file | ConvertTo-SecureString
    $plain=[System.Management.Automation.PSCredential]::new('plain',$secureStringPwd).GetNetworkCredential().Password
    
    $bk_query="vi://"+$global:user+":"+$plain+"@"+$global:esxi_server+"/"+$global:vm_name

    #Execute the command
    .\ovftool.exe --noSSLVerify  --X:logFile="$global:final_dest\ovflog.txt" --X:logLevel=error $bk_query $global:final_dest
    log_file -message "Backup is taken successfully"
    }

    catch{
        
        log_file -message "Something went wrong while doing backup. Please check for following, 1. Disconnect ISO device from VM (Change to Physical drive)"
        mail_log
        exit
    }

    try{
        #Power On VM
        log_file -message "Powering on VM after backup"
        $operation_query="vim-cmd vmsvc/power.on "+$vm_id
    
        $op_id=(Invoke-SSHCommand -Index $session_id -Command $operation_query).Output
                        
        log_file -message "VM $name status : $op_id"
        }
    
    catch{
        log_file -message "Something went wrong during Power operation of VM"
        mail_log
        exit
    }

    #Rebooting server to ensure all services are up
    try{
        log_file -message "Going to sleep for 10 minutes before giving reboot"

        Start-Sleep -s 600 
        $operation_query="vim-cmd vmsvc/power.reboot "+$vm_id
    
        $op_id=(Invoke-SSHCommand -Index $session_id -Command $operation_query).Output
                        
        log_file -message "VM $name status : $op_id"

    }

    catch{
        log_file -message "Something went wrong during reboot of VM"
        mail_log
        exit
    }

    #Compressing the backup into zip
    try{
        log_file -message "Going to zip backup folder"

        #Compressed the folder, if rar is found
        if (Test-Path "$global:win_rar\rar.exe" -PathType Leaf){

            $arc_date=Get-Date -Format d
            & "$global:win_rar\rar.exe" a "$global:final_dest\$name-$arc_date.rar" "$global:final_dest\$name"
            log_file -message "Zipped the folder"

            Remove-Item -path "$global:final_dest\$name" -Recurse

            log_file -m "Everything done successfully"
            mail_log
        }
        #Compression skipped
        else{
                log_file -m "Since rar.exe is not found, skipping the compression"
                log_file -m "Everything done successfully"
                mail_log
        }
    }
    
    catch{
        log_file -message "Something went wrong while zipping/cleaning the backup folder"
        mail_log
        exit
    }
}

else{
    log_file -message "ovftool.exe is not exist in the given location. Exiting from the script"
    mail_log
    exit
}
