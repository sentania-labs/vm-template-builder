# Configure Cloudbase-Init for VMware guestinfo metadata (VCF Automation 9 /
# VKS guest customization path). Only runs on the cloudbase-init variant.

$ErrorActionPreference = 'Stop'

$confDir = 'C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf'
if (-not (Test-Path $confDir)) {
    throw "Cloudbase-Init conf dir not found at $confDir"
}

$common = @'
[DEFAULT]
username=Admin
groups=Administrators
inject_user_password=true
first_logon_behaviour=no
config_drive_raw_hhd=true
config_drive_cdrom=true
config_drive_vfat=true
bsdtar_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\bin\bsdtar.exe
mtools_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\bin\
verbose=true
debug=true
logdir=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\
logfile=cloudbase-init.log
default_log_levels=comtypes=INFO,suds=INFO,iso8601=WARN,requests=WARN
logging_serial_port_settings=
mtu_use_dhcp_config=true
ntp_use_dhcp_config=true
local_scripts_path=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\LocalScripts\
metadata_services=cloudbaseinit.metadata.services.vmwareguestinfoservice.VMwareGuestInfoService,cloudbaseinit.metadata.services.configdrive.ConfigDriveService,cloudbaseinit.metadata.services.nocloudservice.NoCloudConfigDriveService
plugins=cloudbaseinit.plugins.common.mtu.MTUPlugin,cloudbaseinit.plugins.windows.ntpclient.NTPClientPlugin,cloudbaseinit.plugins.windows.createuser.CreateUserPlugin,cloudbaseinit.plugins.common.setuserpassword.SetUserPasswordPlugin,cloudbaseinit.plugins.common.sshpublickeys.SetUserSSHPublicKeysPlugin,cloudbaseinit.plugins.windows.extendvolumes.ExtendVolumesPlugin,cloudbaseinit.plugins.common.sethostname.SetHostNamePlugin,cloudbaseinit.plugins.common.networkconfig.NetworkConfigPlugin,cloudbaseinit.plugins.common.userdata.UserDataPlugin,cloudbaseinit.plugins.common.localscripts.LocalScriptsPlugin
allow_reboot=false
stop_service_on_exit=false
'@

# Main config — runs on every cloudbase-init invocation.
Set-Content -Path (Join-Path $confDir 'cloudbase-init.conf') -Value $common -Encoding ASCII

# Unattend config — runs once during sysprep specialize on first boot. Same
# plugin/metadata set so VCF guest customization data (hostname, network, user
# password) is applied before the machine reaches the login screen.
Set-Content -Path (Join-Path $confDir 'cloudbase-init-unattend.conf') -Value $common -Encoding ASCII

Write-Host "Cloudbase-Init configs written."
