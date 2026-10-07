packer {
  required_version = ">= 1.11.0, < 1.12.0"
  required_plugins {
    vsphere = {
      version = ">= 1.4.2"
      source  = "github.com/hashicorp/vsphere"
    }
  }
}

# Sysprep runs from a SYSTEM scheduled task started by the shutdown command,
# not as a provisioner. Started over WinRM, sysprep is a child of the WinRM
# shell: generalize removes the NIC, the session drops and Packer fails the
# provisioner ("dial tcp ...:5985: connect: no route to host", windows2022-bare
# run 37677411926 on 2026-10-07), and Windows can kill sysprep with the shell
# mid-generalize (the windows11 builds on 2026-10-01). The task outlives the
# session; Packer only waits for the power-off. sysprep/unattend-bare.xml
# deletes the task in the specialize pass. Same mechanism as windows11/.
locals {
  sysprep_shutdown_command = "schtasks /Create /F /TN packer-sysprep /RU SYSTEM /SC ONCE /ST 00:00 /TR \"C:\\Windows\\System32\\Sysprep\\sysprep.exe /generalize /oobe /shutdown /unattend:C:\\Windows\\Temp\\unattend.xml\" && schtasks /Run /TN packer-sysprep"
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
    "./autounattend/install-vmtools.ps1",
    "./autounattend/init-winrm.ps1",
  ]

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

  boot_order       = "disk,cdrom"
  boot_wait        = "2s"
  shutdown_timeout = "30m"
  shutdown_command = local.sysprep_shutdown_command

  configuration_parameters = {
    "disk.EnableUUID" = "true"
  }
}

source "vsphere-iso" "windows2022-bare" {

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
    name    = "windows2022-bare"
    ovf     = var.ovf
  }

  CPUs                 = var.cpu_num
  RAM                  = var.mem_size
  RAM_reserve_all      = true
  firmware             = "efi-secure"
  guest_os_type        = "windows2019srvNext_64Guest"
  disk_controller_type = ["pvscsi"]

  iso_paths = [
    "${var.content_library_destination}/server2022-remastered/${var.windows2022_remastered_iso_filename}",
    var.windows_tools_iso_path,
  ]
  reattach_cdroms = 2
  remove_cdrom    = "true"

  # Same CD layout as 2025; the 2022 answer file (no product key, eval
  # image name) is published at the CD root as autounattend.xml.
  cd_files = [
    "./autounattend/install-vmtools.ps1",
    "./autounattend/init-winrm.ps1",
  ]
  cd_content = {
    "autounattend.xml" = file("./autounattend/autounattend-2022.xml")
  }

  network_adapters {
    network      = var.vsphere_network
    network_card = "vmxnet3"
  }

  storage {
    disk_size             = var.disk_size
    disk_thin_provisioned = true
  }

  vm_name             = "windows2022-bare-template"
  convert_to_template = "true"

  communicator   = "winrm"
  winrm_username = var.winrm_username
  winrm_password = var.winrm_password
  winrm_port     = 5985
  winrm_timeout  = "60m"
  winrm_use_ssl  = false
  winrm_insecure = true

  boot_order       = "disk,cdrom"
  boot_wait        = "2s"
  shutdown_timeout = "30m"
  shutdown_command = local.sysprep_shutdown_command

  configuration_parameters = {
    "disk.EnableUUID" = "true"
  }
}

build {
  sources = [
    "source.vsphere-iso.windows2025-bare",
    "source.vsphere-iso.windows2022-bare",
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

  # Both sources build from evaluation media, so setup installs
  # ServerStandardEval. Convert to ServerStandard with the edition's KMS
  # client key, reboot to complete the change, then assert it took. Runs
  # before updates so they land on the final edition. 2022 from the start
  # (2026-10-07); 2025 added the same day after a deployed windows2025-bare
  # VM read ServerStandardEval (the GVLK in its answer file installs on eval
  # media but does not change the edition). See NOTES.md 2026-10-07.
  provisioner "powershell" {
    script            = "./setup/15-set-edition.ps1"
    elevated_user     = "labuser"
    elevated_password = "VMware123!VMware123!"
    environment_vars = [
      "TARGET_EDITION=ServerStandard",
      "PRODUCT_KEY=${source.name == "windows2025-bare" ? var.windows_product_key : var.windows2022_product_key}",
    ]
  }

  provisioner "windows-restart" {
    restart_timeout = "60m"
  }

  provisioner "powershell" {
    script            = "./setup/15-set-edition.ps1"
    elevated_user     = "labuser"
    elevated_password = "VMware123!VMware123!"
    environment_vars = [
      "TARGET_EDITION=ServerStandard",
      "EDITION_VERIFY_ONLY=1",
    ]
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
    valid_exit_codes  = [0, 267014]
  }

  provisioner "windows-restart" {
    restart_timeout = "30m"
  }

  provisioner "powershell" {
    script            = "./setup/30-apply-updates.ps1"
    timeout           = "2h"
    elevated_user     = "labuser"
    elevated_password = "VMware123!VMware123!"
    valid_exit_codes  = [0, 267014]
  }

  provisioner "windows-restart" {
    restart_timeout = "30m"
  }

  provisioner "file" {
    source      = "./sysprep/unattend-bare.xml"
    destination = "C:\\Windows\\Temp\\unattend.xml"
  }

  provisioner "powershell" {
    script = "./setup/80-cleanup.ps1"
  }
}
