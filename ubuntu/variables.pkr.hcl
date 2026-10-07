variable "content_library_destination" {
  type    = string
  default = "vcf-lab-vcenter-mgmt.int.sentania.net"
}

variable "library_vm_destroy" {
  type    = bool
  default = true
}
variable "ovf" {
  type    = bool
  default = true
}

variable "cpu_num" {
  type    = number
  default = 2
}

variable "disk_size" {
  type    = number
  default = 51200
}

variable "mem_size" {
  type    = number
  default = 2048
}

variable "os_iso_checksum" {
  type    = string
  default = ""
}

variable "os_iso_url" {
  type    = string
  default = ""
}

variable "vsphere_datastore" {
  type    = string
  default = ""
}

variable "vsphere_datacenter" {
  type    = string
  default = ""
}

variable "vsphere_cluster" {
  type    = string
  default = ""
}

variable "vsphere_password" {
  type      = string
  default   = ""
  sensitive = true
}

variable "vsphere_network" {
  type    = string
  default = ""
}

variable "vsphere_server" {
  type    = string
  default = ""
}

variable "vsphere_username" {
  type    = string
  default = ""
}

variable "ssh_password" {
  type      = string
  default   = ""
  sensitive = true
}

variable "ssh_username" {
  type    = string
  default = ""
}

variable "cloudinit_userdata" {
  type = string
  default = ""
}

variable "cloudinit_metadata" {
  type = string
  default = ""
}

variable "shell_scripts" {
  type = list(string)
  description = "A list of scripts."
  default = []
}

variable "boot_command" {
  type = list(string)
  description = "Ubuntu boot command"
  default = []
}

# Optional per-source override: a datastore path such as
# "[vcf-lab-mgmt-cl01-vsan] iso/ubuntu-24.04.3-live-server-amd64.iso". Same
# escape hatch as linux/iso_datastore_paths and windows11's
# windows_iso_datastore_path. Empty or absent means use the library item.
variable "iso_datastore_paths" {
  type        = map(string)
  description = "Per-source datastore ISO path that overrides the library item."
  default     = {}
}
