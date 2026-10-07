vsphere_datacenter = "vcf-lab-mgmt-dc01"
vsphere_cluster    = "vcf-lab-mgmt-cl01"
vsphere_network    = "vcf-lab-mgmt-cl01-vds01-pg-vm-mgmt"
vsphere_datastore  = "vcf-lab-mgmt-cl01-vsan"

# labuser is created by the kickstart / Alpine bootstrap with the same
# password hash and RSA key as ubuntu/http/user-data. Lab default account,
# committed by design (docs/standards/secrets-policy.md).
ssh_username = "labuser"
ssh_password = "VMware123!"

ovf = true
