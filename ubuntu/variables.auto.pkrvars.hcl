# vsphere datacenter name
vsphere_datacenter      = "vcf-lab-mgmt-dc01"

# name or IP of the ESXi host
vsphere_cluster            = "vcf-lab-mgmt-cl01"

# vsphere network
vsphere_network         = "vcf-lab-mgmt-cl01-vds01-pg-vm-mgmt"

# vsphere datastore
vsphere_datastore       = "vcf-lab-mgmt-cl01-vsan"

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