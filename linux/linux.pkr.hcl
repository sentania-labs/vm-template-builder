packer {
  required_version = ">= 1.11.0, < 1.12.0"
  required_plugins {
    vsphere = {
      version = ">= 1.4.2"
      source  = "github.com/hashicorp/vsphere"
    }
  }
}

# Linux family beyond Ubuntu: RHEL 8/9/10, Rocky Linux 9, CentOS Stream 9 and
# Alpine. Same shape as ubuntu/: vsphere-iso from an ISO in the content
# library, unattended install answered from a small second CD (cd_content),
# SSH as labuser, lab Root CA, cleanup, convert to template, OVF to the
# content library under the source name.
#
# Two base sources ("el" and "alpine") carry everything the variants share.
# The build blocks below instantiate them per distro, setting only the name,
# ISO, guest type, answer files and library item name. Build one source with
# -only, for example: packer build -only='el.vsphere-iso.rhel9' .
#
# The answer files ride on a CD instead of packer's HTTP server because CI
# runs in the ARC runner pool: the build VM cannot reach a runner pod's
# ephemeral HTTP port, which is why ubuntu/ uses a cidata CD as well.

locals {
  # Content library path of each source's ISO, or the datastore override.
  iso_path = {
    for name, item in var.iso_items :
    name => lookup(var.iso_datastore_paths, name, "") != "" ? var.iso_datastore_paths[name] : "${var.content_library_destination}/${item}/${item}.iso"
  }

  # Anaconda: pick "Install ..." (one up from the default "Test this media &
  # install"), edit it, append text mode and the kickstart location to the
  # kernel line, boot with Ctrl-X. Same menu layout on RHEL 8/9/10, Rocky 9
  # and CentOS Stream 9 under UEFI. If the keystrokes miss, Anaconda still
  # finds ks.cfg on the OEMDRV-labelled CD by itself (graphical, but unattended).
  el_boot_command = [
    "<up>",
    "e",
    "<down><down><end>",
    " inst.text inst.ks=hd:LABEL=OEMDRV:/ks.cfg",
    "<leftCtrlOn>x<leftCtrlOff>",
  ]

  # Alpine: log in as root on the live console (no password), find the CD
  # that carries bootstrap.sh, run it. bootstrap.sh drives setup-alpine with
  # the answer file and reboots into the installed system.
  alpine_boot_command = [
    "root<enter><wait5>",
    "mkdir -p /media/ks; for d in /dev/sr*; do mount -r $d /media/ks 2>/dev/null && [ -f /media/ks/bootstrap.sh ] && break; umount /media/ks 2>/dev/null; done; sh /media/ks/bootstrap.sh<enter>",
  ]
}

# Shared settings for the Anaconda-installed distros (RHEL, Rocky, CentOS).
source "vsphere-iso" "el" {
  vcenter_server      = var.vsphere_server
  cluster             = var.vsphere_cluster
  username            = var.vsphere_username
  password            = var.vsphere_password
  insecure_connection = "true"
  datacenter          = var.vsphere_datacenter
  datastore           = var.vsphere_datastore
  remove_cdrom        = "true"

  CPUs                 = var.cpu_num
  RAM                  = var.mem_size
  RAM_reserve_all      = true
  firmware             = "efi"
  disk_controller_type = ["pvscsi"]

  # Kickstart lives on this CD as /ks.cfg. The OEMDRV label is the one
  # Anaconda searches automatically.
  cd_label = "OEMDRV"

  network_adapters {
    network      = var.vsphere_network
    network_card = "vmxnet3"
  }

  storage {
    disk_size             = var.disk_size
    disk_thin_provisioned = true
  }

  convert_to_template    = "true"
  communicator           = "ssh"
  ssh_username           = var.ssh_username
  ssh_password           = var.ssh_password
  ssh_timeout            = "45m"
  ssh_handshake_attempts = "100000"

  boot_order       = "disk,cdrom"
  boot_wait        = "10s"
  boot_command     = local.el_boot_command
  shutdown_command = "echo '${var.ssh_password}' | sudo -S -E shutdown -P now"
  shutdown_timeout = "15m"

  configuration_parameters = {
    "disk.EnableUUID" = "true"
  }
}

# Alpine. Same hardware contract; the controller is pvscsi too (vmw_pvscsi is
# a module in linux-lts and mkinitfs' default "scsi" feature includes it).
source "vsphere-iso" "alpine" {
  vcenter_server      = var.vsphere_server
  cluster             = var.vsphere_cluster
  username            = var.vsphere_username
  password            = var.vsphere_password
  insecure_connection = "true"
  datacenter          = var.vsphere_datacenter
  datastore           = var.vsphere_datastore
  remove_cdrom        = "true"

  CPUs                 = var.cpu_num
  RAM                  = var.mem_size
  RAM_reserve_all      = true
  firmware             = "efi"
  disk_controller_type = ["pvscsi"]

  cd_label = "ALPINEKS"

  network_adapters {
    network      = var.vsphere_network
    network_card = "vmxnet3"
  }

  storage {
    disk_size             = var.disk_size
    disk_thin_provisioned = true
  }

  convert_to_template    = "true"
  communicator           = "ssh"
  ssh_username           = var.ssh_username
  ssh_password           = var.ssh_password
  ssh_timeout            = "30m"
  ssh_handshake_attempts = "100000"

  # The live ISO boots to a login prompt that waits indefinitely, so a long
  # boot_wait only costs time; a short one loses the keystrokes.
  boot_order       = "disk,cdrom"
  boot_wait        = "60s"
  boot_command     = local.alpine_boot_command
  shutdown_command = "echo '${var.ssh_password}' | sudo -S poweroff"
  shutdown_timeout = "15m"

  configuration_parameters = {
    "disk.EnableUUID" = "true"
  }
}

build {
  name = "el"

  source "source.vsphere-iso.el" {
    name          = "rocky9"
    vm_name       = "rocky9-template"
    guest_os_type = "rockylinux_64Guest"
    iso_paths     = [local.iso_path["rocky9"]]
    cd_content    = { "/ks.cfg" = file("ks/el9.ks") }
    content_library_destination {
      destroy = var.library_vm_destroy
      library = var.content_library_destination
      name    = "rocky9"
      ovf     = var.ovf
    }
  }

  source "source.vsphere-iso.el" {
    name          = "centos-stream9"
    vm_name       = "centos-stream9-template"
    guest_os_type = "centos9_64Guest"
    iso_paths     = [local.iso_path["centos-stream9"]]
    cd_content    = { "/ks.cfg" = file("ks/el9.ks") }
    content_library_destination {
      destroy = var.library_vm_destroy
      library = var.content_library_destination
      name    = "centos-stream9"
      ovf     = var.ovf
    }
  }

  source "source.vsphere-iso.el" {
    name          = "rhel8"
    vm_name       = "rhel8-template"
    guest_os_type = "rhel8_64Guest"
    iso_paths     = [local.iso_path["rhel8"]]
    cd_content    = { "/ks.cfg" = file("ks/el8.ks") }
    content_library_destination {
      destroy = var.library_vm_destroy
      library = var.content_library_destination
      name    = "rhel8"
      ovf     = var.ovf
    }
  }

  source "source.vsphere-iso.el" {
    name          = "rhel9"
    vm_name       = "rhel9-template"
    guest_os_type = "rhel9_64Guest"
    iso_paths     = [local.iso_path["rhel9"]]
    cd_content    = { "/ks.cfg" = file("ks/el9.ks") }
    content_library_destination {
      destroy = var.library_vm_destroy
      library = var.content_library_destination
      name    = "rhel9"
      ovf     = var.ovf
    }
  }

  source "source.vsphere-iso.el" {
    name          = "rhel10"
    vm_name       = "rhel10-template"
    guest_os_type = "rhel10_64Guest"
    iso_paths     = [local.iso_path["rhel10"]]
    cd_content    = { "/ks.cfg" = file("ks/el10.ks") }
    content_library_destination {
      destroy = var.library_vm_destroy
      library = var.content_library_destination
      name    = "rhel10"
      ovf     = var.ovf
    }
  }

  provisioner "file" {
    source      = "../files/sentania Lab Root 2.crt"
    destination = "/tmp/sentania-lab-root-2.crt"
  }

  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | {{.Vars}} sudo -S -E bash '{{.Path}}'"
    scripts = [
      "./setup/el-ca-trust.sh",
      "./setup/el-cleanup.sh",
    ]
  }
}

build {
  name = "alpine"

  source "source.vsphere-iso.alpine" {
    name          = "alpine324"
    vm_name       = "alpine324-template"
    guest_os_type = "other6xLinux64Guest"
    iso_paths     = [local.iso_path["alpine324"]]
    cd_content = {
      "/bootstrap.sh"    = file("alpine/bootstrap.sh")
      "/answers"         = file("alpine/answers")
      "/authorized_keys" = file("alpine/authorized_keys")
    }
    content_library_destination {
      destroy = var.library_vm_destroy
      library = var.content_library_destination
      name    = "alpine324"
      ovf     = var.ovf
    }
  }

  provisioner "file" {
    source      = "../files/sentania Lab Root 2.crt"
    destination = "/tmp/sentania-lab-root-2.crt"
  }

  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | {{.Vars}} sudo -S -E sh '{{.Path}}'"
    scripts = [
      "./setup/alpine-ca-trust.sh",
      "./setup/alpine-cleanup.sh",
    ]
  }
}
