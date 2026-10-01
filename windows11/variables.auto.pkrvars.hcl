vsphere_datacenter = "vcf-lab-mgmt-dc01"
vsphere_cluster    = "vcf-lab-mgmt-cl01"
vsphere_network    = "vcf-lab-mgmt-cl01-vds01-pg-vm-mgmt"
vsphere_datastore  = "vcf-lab-mgmt-cl01-vsan"

winrm_username = "labuser"
winrm_password = "VMware123!VMware123!"

# Windows 11 consumer multi-edition ISO, build 26300.9457 (Microsoft download,
# Windows11_Client_x64_en-us_26300_9457.iso, SHA-256 bd4307df...ea650),
# remastered with efisys_noprompt.bin by lab-admin scripts/remaster-windows-iso.ps1
# and uploaded as library item "win11-pro-26300-remastered" (SHA-256 b9db7550...38a24).
# The ISO carries Home, Education, Pro and Pro for Workstations; no Enterprise.
windows_remastered_iso_filename = "win11-26300-remastered.iso"

# The content library lives on the NFS datastore vcf-lab-mgmt01-nfs, and on
# 2026-10-01 no cluster host could mount an ISO from it ("Invalid configuration
# for device '0'"; esx01 shows All Paths Down, esx05 has no mount). The same
# ISO is therefore also on vSAN and the build uses that copy. Remove this line
# to go back to the library item once the NFS datastore is healthy.
windows_iso_datastore_path = "[vcf-lab-mgmt-cl01-vsan] iso/win11-26300-remastered.iso"
windows_tools_iso_path     = "[] /vmimages/tools-isoimages/windows.iso"

# Windows 11 Pro, Microsoft-published KMS client key; activates against the lab KMS.
windows_product_key = "W269N-WFGWX-YVC9B-4J6C9-T83GX"
windows_image_name  = "Windows 11 Pro"

organization_name = "Sentania Lab"
timezone          = "Central Standard Time"

# 100 GB disk; 2 vCPU / 4 GB at build time (Windows 11 minimum), resize at deploy.
disk_size = 102400

ovf = true
