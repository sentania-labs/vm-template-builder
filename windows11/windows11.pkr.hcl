packer {
  required_version = ">= 1.11.0, < 1.12.0"
  required_plugins {
    vsphere = {
      version = ">= 1.4.2"
      source  = "github.com/hashicorp/vsphere"
    }
  }
}

# Windows 11 Pro test-desktop template. Same build chain as windows/ (Server
# 2025): unattended install, VMware Tools, lab Root CA, two update passes,
# cleanup, sysprep, OVF to the content library. Shared scripts are used from
# ../windows; only the answer files and the client prep step differ.
#
# No vTPM at build time: a VM with a vTPM is encrypted and cannot be exported
# as an OVF, so setup's TPM/Secure Boot/RAM/CPU checks are bypassed in the
# answer file (LabConfig) and the vTPM is added when a VM is deployed.
source "vsphere-iso" "windows11-pro-bare" {

  vcenter_server = var.vsphere_server
  cluster        = var.vsphere_cluster
  # Optional: pin the build VM to one host. Empty lets DRS place it. Needed
  # while some cluster hosts cannot reach the NFS datastore that holds the
  # content library ISOs ("Invalid configuration for device '0'" on mount).
  host                = var.vsphere_host
  username            = var.vsphere_username
  password            = var.vsphere_password
  insecure_connection = "true"
  datacenter          = var.vsphere_datacenter
  datastore           = var.vsphere_datastore

  content_library_destination {
    destroy = var.library_vm_destroy
    library = var.content_library_destination
    name    = "windows11-pro-bare"
    ovf     = var.ovf
  }

  CPUs                 = var.cpu_num
  RAM                  = var.mem_size
  RAM_reserve_all      = true
  firmware             = "efi-secure"
  guest_os_type        = "windows11_64Guest"
  disk_controller_type = ["pvscsi"]

  iso_paths = [
    var.windows_iso_datastore_path != "" ? var.windows_iso_datastore_path : "${var.content_library_destination}/win11-pro-26300-remastered/${var.windows_remastered_iso_filename}",
    var.windows_tools_iso_path,
  ]
  reattach_cdroms = 2
  remove_cdrom    = "true"

  cd_files = [
    "./autounattend/autounattend.xml",
    "../windows/autounattend/install-vmtools.ps1",
    "../windows/autounattend/init-winrm.ps1",
  ]

  network_adapters {
    network      = var.vsphere_network
    network_card = "vmxnet3"
  }

  storage {
    disk_size             = var.disk_size
    disk_thin_provisioned = true
  }

  vm_name             = "windows11-pro-bare-template"
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
  # Sysprep runs from a SYSTEM scheduled task started by the shutdown command.
  # Run directly over WinRM (as a provisioner or as the shutdown command), sysprep
  # is a child of the WinRM shell: generalize deletes the NIC, the shell dies, and
  # Windows kills sysprep with it mid-generalize (setupact.log stops at the
  # iphlpsvc step; seen on 2026-10-01 builds 1 to 4). The task outlives the
  # session; Packer only waits for the power-off. sysprep/unattend-bare.xml
  # deletes the task in the specialize pass.
  shutdown_command = "schtasks /Create /F /TN packer-sysprep /RU SYSTEM /SC ONCE /ST 00:00 /TR \"C:\\Windows\\System32\\Sysprep\\sysprep.exe /generalize /oobe /shutdown /unattend:C:\\Windows\\Temp\\unattend.xml\" && schtasks /Run /TN packer-sysprep"

  configuration_parameters = {
    "disk.EnableUUID" = "true"
  }
}

build {
  sources = [
    "source.vsphere-iso.windows11-pro-bare",
  ]

  provisioner "powershell" {
    script = "../windows/setup/00-wait-specialize.ps1"
  }

  provisioner "powershell" {
    script = "../windows/setup/10-install-vmtools.ps1"
  }

  provisioner "windows-restart" {
    restart_timeout = "30m"
  }

  provisioner "file" {
    source      = "../files/sentania Lab Root 2.crt"
    destination = "C:\\Windows\\Temp\\sentania-lab-root-2.crt"
  }

  provisioner "powershell" {
    script = "../windows/setup/20-import-ca.ps1"
  }

  provisioner "powershell" {
    script            = "../windows/setup/30-apply-updates.ps1"
    timeout           = "2h"
    elevated_user     = "labuser"
    elevated_password = "VMware123!VMware123!"
    valid_exit_codes  = [0, 267014]
  }

  provisioner "windows-restart" {
    restart_timeout = "30m"
  }

  provisioner "powershell" {
    script            = "../windows/setup/30-apply-updates.ps1"
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
    script = "../windows/setup/80-cleanup.ps1"
  }

  provisioner "powershell" {
    script = "./setup/85-client-prep.ps1"
  }
}
