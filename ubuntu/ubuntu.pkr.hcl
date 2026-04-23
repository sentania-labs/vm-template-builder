packer {
  required_plugins {
    vsphere = {
      version = ">= 0.0.1"
      source = "github.com/hashicorp/vsphere"
    }
  }
}

source "vsphere-iso" "ubuntu22" {

  vcenter_server        = var.vsphere_server
  cluster                  = var.vsphere_cluster 
  username              = var.vsphere_username
  password              = var.vsphere_password
  insecure_connection   = "true"
  datacenter            = var.vsphere_datacenter
  datastore             = var.vsphere_datastore
  remove_cdrom          = "true"

  content_library_destination {
    destroy = var.library_vm_destroy
    library = var.content_library_destination
    name    = "ubuntu22"
    ovf     = var.ovf
  }

  CPUs                  = var.cpu_num
  RAM                   = var.mem_size
  RAM_reserve_all       = true
  disk_controller_type  = ["pvscsi"]
  guest_os_type         = "ubuntu64Guest"
  iso_paths             = ["${var.content_library_destination}/ubuntu-22.04.5-live-server-amd64/ubuntu-22.04.5-live-server-amd64.iso"]
  cd_content        = {
    "/meta-data" = file("${var.cloudinit_metadata}")
    "/user-data" = file("${var.cloudinit_userdata}")
  }
  cd_label              = "cidata"

  network_adapters {
    network             = var.vsphere_network
    network_card        = "vmxnet3"
  }

  storage {
    disk_size             = var.disk_size
    disk_thin_provisioned = true
  }

  vm_name               = "ubuntu22-template"
  convert_to_template   = "true"
  communicator          = "ssh"
  ssh_username          = var.ssh_username
  ssh_password          = var.ssh_password
  ssh_timeout           = "30m"
  ssh_handshake_attempts = "100000"

  boot_order            = "disk,cdrom,floppy"
  boot_wait             = "5s"
  boot_command          = var.boot_command
  shutdown_command      = "echo '${var.ssh_password}' | sudo -S -E shutdown -P now"
  shutdown_timeout      = "15m"

  configuration_parameters = {
    "disk.EnableUUID" = "true"
  }
}

source "vsphere-iso" "ubuntu24" {

  vcenter_server        = var.vsphere_server
  cluster               = var.vsphere_cluster 
  username              = var.vsphere_username
  password              = var.vsphere_password
  insecure_connection   = "true"
  datacenter            = var.vsphere_datacenter
  datastore             = var.vsphere_datastore
  remove_cdrom          = "true"

  content_library_destination {
    destroy = var.library_vm_destroy
    library = var.content_library_destination
    name    = "ubuntu24"    
    ovf     = var.ovf
  }

  CPUs                  = var.cpu_num
  RAM                   = var.mem_size
  RAM_reserve_all       = true
  disk_controller_type  = ["pvscsi"]
  guest_os_type         = "ubuntu64Guest"
  iso_paths             = ["${var.content_library_destination}/ubuntu-24.04.3-live-server-amd64/ubuntu-24.04.3-live-server-amd64.iso"]
  cd_content        = {
    "/meta-data" = file("${var.cloudinit_metadata}")
    "/user-data" = file("${var.cloudinit_userdata}")
  }
  cd_label              = "cidata"

  network_adapters {
    network             = var.vsphere_network
    network_card        = "vmxnet3"
  }

  storage {
    disk_size             = var.disk_size
    disk_thin_provisioned = true
  }

  vm_name               = "ubuntu24-template"
  convert_to_template   = "true"
  communicator          = "ssh"
  ssh_username          = var.ssh_username
  ssh_password          = var.ssh_password
  ssh_timeout           = "30m"
  ssh_handshake_attempts = "100000"

  boot_order            = "disk,cdrom,floppy"
  boot_wait             = "5s"
  boot_command          = var.boot_command
  shutdown_command      = "echo '${var.ssh_password}' | sudo -S -E shutdown -P now"
  shutdown_timeout      = "15m"

  configuration_parameters = {
    "disk.EnableUUID" = "true"
  }
}
build {
  sources = ["source.vsphere-iso.ubuntu22", "source.vsphere-iso.ubuntu24"]

  provisioner "shell" {
    execute_command = "echo '${var.ssh_password}' | {{.Vars}} sudo -S -E bash '{{.Path}}'"
    environment_vars = [
      "BUILD_USERNAME=${var.ssh_username}",
    ]
    scripts = var.shell_scripts
    expect_disconnect = true
  }

  # Copy the root CA into the VM (filename with spaces is fine when quoted)
  provisioner "file" {
    source      = "../files/sentania Lab Root 2.crt"
    destination = "/tmp/sentania Lab Root 2.crt"
  }

  # Trust the CA
  provisioner "shell" {
    inline = [
      "sudo apt-get update -y && sudo apt-get install -y --no-install-recommends ca-certificates || true",

      # install the cert and update trust
      "sudo install -m 0644 -o root -g root /tmp/sentania\\ Lab\\ Root\\ 2.crt /usr/local/share/ca-certificates/sentania-lab-root-2.crt",
      "sudo update-ca-certificates"
    ]
  }
}