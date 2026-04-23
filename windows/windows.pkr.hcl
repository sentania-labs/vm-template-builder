packer {
  required_version = ">= 1.11.0, < 1.12.0"
  required_plugins {
    vsphere = {
      version = ">= 1.4.2"
      source  = "github.com/hashicorp/vsphere"
    }
  }
}

locals {
  iso_paths = [
    "${var.content_library_destination}/${var.windows_iso_path}",
    var.windows_tools_iso_path,
  ]
}

source "vsphere-iso" "windows2025-bare" {

  vcenter_server      = var.vsphere_server
  cluster             = var.vsphere_cluster
  username            = var.vsphere_username
  password            = var.vsphere_password
  insecure_connection = "true"
  datacenter          = var.vsphere_datacenter
  datastore           = var.vsphere_datastore

  content_library_destination {
    destroy = var.library_vm_destroy
    library = var.content_library_destination
    name    = "windows2025-bare"
    ovf     = var.ovf
  }

  CPUs                 = var.cpu_num
  RAM                  = var.mem_size
  RAM_reserve_all      = true
  firmware             = "efi-secure"
  guest_os_type        = "windows2019srv_64Guest"
  disk_controller_type = ["pvscsi"]

  iso_paths = [
    "${var.content_library_destination}/server2025-remastered/${var.windows_remastered_iso_filename}",
    var.windows_tools_iso_path,
  ]
  reattach_cdroms = 2
  remove_cdrom    = "true"

  cd_files = [
    "./autounattend/autounattend.xml",
    "./autounattend/bootstrap.ps1",
  ]
  cd_label = "PACKER"

  network_adapters {
    network      = var.vsphere_network
    network_card = "vmxnet3"
  }

  storage {
    disk_size             = var.disk_size
    disk_thin_provisioned = true
  }

  vm_name             = "windows2025-bare-template"
  convert_to_template = "true"

  communicator   = "winrm"
  winrm_username = var.winrm_username
  winrm_password = var.winrm_password
  winrm_port     = 5985
  winrm_timeout  = "60m"
  winrm_use_ssl  = false
  winrm_insecure = true

  boot_order        = "disk,cdrom"
  boot_wait         = "2s"
  shutdown_timeout  = "30m"

  configuration_parameters = {
    "disk.EnableUUID" = "true"
  }
}

source "vsphere-iso" "windows2025-cbinit" {

  vcenter_server      = var.vsphere_server
  cluster             = var.vsphere_cluster
  username            = var.vsphere_username
  password            = var.vsphere_password
  insecure_connection = "true"
  datacenter          = var.vsphere_datacenter
  datastore           = var.vsphere_datastore

  content_library_destination {
    destroy = var.library_vm_destroy
    library = var.content_library_destination
    name    = "windows2025-cbinit"
    ovf     = var.ovf
  }

  CPUs                 = var.cpu_num
  RAM                  = var.mem_size
  RAM_reserve_all      = true
  firmware             = "efi-secure"
  guest_os_type        = "windows2019srv_64Guest"
  disk_controller_type = ["pvscsi"]

  iso_paths       = local.iso_paths
  reattach_cdroms = 2
  remove_cdrom    = "true"

  cd_files = [
    "./autounattend/autounattend.xml",
    "./autounattend/bootstrap.ps1",
  ]
  cd_label = "PACKER"

  network_adapters {
    network      = var.vsphere_network
    network_card = "vmxnet3"
  }

  storage {
    disk_size             = var.disk_size
    disk_thin_provisioned = true
  }

  vm_name             = "windows2025-cbinit-template"
  convert_to_template = "true"

  communicator   = "winrm"
  winrm_username = var.winrm_username
  winrm_password = var.winrm_password
  winrm_port     = 5985
  winrm_timeout  = "60m"
  winrm_use_ssl  = false
  winrm_insecure = true

  boot_order        = "disk,cdrom"
  boot_wait         = "2s"
  shutdown_timeout  = "30m"

  configuration_parameters = {
    "disk.EnableUUID" = "true"
  }
}

build {
  # cbinit is parked — source block retained but not in active sources.
  # See windows/NOTES.md.
  sources = [
    "source.vsphere-iso.windows2025-bare",
  ]

  provisioner "powershell" {
    script = "./setup/00-wait-specialize.ps1"
  }

  provisioner "powershell" {
    script = "./setup/10-install-vmtools.ps1"
  }

  provisioner "windows-restart" {
    restart_timeout = "30m"
  }

  provisioner "file" {
    source      = "../files/sentania Lab Root 2.crt"
    destination = "C:\\Windows\\Temp\\sentania-lab-root-2.crt"
  }

  provisioner "powershell" {
    script = "./setup/20-import-ca.ps1"
  }

  provisioner "powershell" {
    script            = "./setup/30-apply-updates.ps1"
    timeout           = "2h"
    elevated_user     = "labuser"
    elevated_password = "VMware123!VMware123!"
  }

  provisioner "windows-restart" {
    restart_timeout = "30m"
  }

  provisioner "powershell" {
    script            = "./setup/30-apply-updates.ps1"
    timeout           = "2h"
    elevated_user     = "labuser"
    elevated_password = "VMware123!VMware123!"
  }

  provisioner "windows-restart" {
    restart_timeout = "30m"
  }

  # cbinit-only: install cloudbase-init and stage its configs.
  provisioner "powershell" {
    only   = ["vsphere-iso.windows2025-cbinit"]
    script = "./setup/40-install-cbinit.ps1"
  }

  provisioner "powershell" {
    only   = ["vsphere-iso.windows2025-cbinit"]
    script = "./setup/45-configure-cbinit.ps1"
  }

  # Upload the per-variant sysprep unattend that 90-sysprep.ps1 hands to sysprep.
  provisioner "file" {
    only        = ["vsphere-iso.windows2025-bare"]
    source      = "./sysprep/unattend-bare.xml"
    destination = "C:\\Windows\\Temp\\unattend.xml"
  }

  provisioner "file" {
    only        = ["vsphere-iso.windows2025-cbinit"]
    source      = "./sysprep/unattend-cbinit.xml"
    destination = "C:\\Windows\\Temp\\unattend.xml"
  }

  provisioner "powershell" {
    script = "./setup/80-cleanup.ps1"
  }

  provisioner "powershell" {
    script           = "./setup/90-sysprep.ps1"
    valid_exit_codes = [0, 2300218]
  }
}
