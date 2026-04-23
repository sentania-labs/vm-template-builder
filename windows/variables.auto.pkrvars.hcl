vsphere_datacenter = "vcf-lab-mgmt-dc01"
vsphere_cluster    = "vcf-lab-mgmt-cl01"
vsphere_network    = "vcf-lab-mgmt-cl01-vds01-pg-vm-mgmt"
vsphere_datastore  = "vcf-lab-mgmt-cl01-vsan"

winrm_username = "labuser"
winrm_password = "VMware123!VMware123!"

# ISO inside vcf-lab-mgmt-contentlibrary, library item "server2025-iso".
windows_iso_path       = "server2025-iso/file.iso"
windows_tools_iso_path = "[] /vmimages/tools-isoimages/windows.iso"

# Server 2025 Standard Desktop Experience (Microsoft-published GVLK).
windows_product_key = "TVRH6-WHNXV-R9WG3-9XRFY-MY832"
windows_image_name  = "Windows Server 2025 SERVERSTANDARD"

organization_name = "Sentania Lab"
timezone          = "Eastern Standard Time"

ovf = true
