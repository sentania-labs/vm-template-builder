# vsphere datacenter name
vsphere_datacenter      = "vcf-lab-mgmt-dc01"

# name or IP of the ESXi host
vsphere_cluster            = "vcf-lab-mgmt-cl01"

# vsphere network
vsphere_network         = "vcf-lab-mgmt-cl01-vds01-pg-vm-mgmt"

# vsphere datastore
vsphere_datastore       = "vcf-lab-mgmt-cl01-vsan"

# The content library lives on the NFS datastore vcf-lab-mgmt01-nfs, which
# cluster host esx05 does not mount. A build VM that DRS places on esx05 cannot
# attach a library ISO ("Invalid configuration for device '0'"), so both
# sources use copies of the same ISOs on vSAN, which every cluster host sees.
# Remove these lines to go back to the library items once esx05 mounts the NFS
# datastore.
iso_datastore_paths = {
  ubuntu22 = "[vcf-lab-mgmt-cl01-vsan] iso/ubuntu-22.04.5-live-server-amd64.iso"
  ubuntu24 = "[vcf-lab-mgmt-cl01-vsan] iso/ubuntu-24.04.3-live-server-amd64.iso"
}

# cloud_init files for unattended configuration for Ubuntu
cloudinit_userdata      = "./http/user-data"
cloudinit_metadata      = "./http/meta-data"

# final clean up script
shell_scripts           = ["./setup/setup.sh"]

# SSH username (created in user-data. If you change it here the please also adjust in ./html/user-data)
ssh_username            = "labuser"

# SSH password (created in autounattend.xml. If you change it here the please also adjust in ./html/user-data)
ssh_password            = "VMware123!"

ovf = true