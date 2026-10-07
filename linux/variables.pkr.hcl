# Variables for the linux/ family (RHEL, Rocky, CentOS Stream, Alpine).
# Lab-specific values live in variables.auto.pkrvars.hcl; vCenter
# credentials come from CI (-var) or a local gitignored linux.pkrvars.hcl.

variable "vsphere_server" {
  type    = string
  default = ""
}

variable "vsphere_username" {
  type    = string
  default = ""
}

variable "vsphere_password" {
  type      = string
  default   = ""
  sensitive = true
}

variable "vsphere_datacenter" {
  type    = string
  default = ""
}

variable "vsphere_cluster" {
  type    = string
  default = ""
}

variable "vsphere_datastore" {
  type    = string
  default = ""
}

variable "vsphere_network" {
  type    = string
  default = ""
}

variable "content_library_destination" {
  type        = string
  description = "Content library that holds the install ISOs and receives the finished OVFs."
  default     = "vcf-lab-mgmt-contentlibrary"
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

variable "mem_size" {
  type    = number
  default = 2048
}

variable "disk_size" {
  type    = number
  default = 51200
}

# Library item name per source. The ISO file inside each item is expected to
# be "<item>.iso" (what the library keeps when the ISO is imported under its
# own name). Change a value here when a newer point release is staged.
variable "iso_items" {
  type        = map(string)
  description = "Content library ISO item name per source."
  default = {
    rocky9         = "Rocky-9.8-x86_64-dvd"
    centos-stream9 = "CentOS-Stream-9-20261006.0-x86_64-dvd1"
    alpine324      = "alpine-standard-3.24.2-x86_64"
    rhel8          = "rhel-8.10-x86_64-dvd"
    rhel9          = "rhel-9.8-x86_64-dvd"
    rhel10         = "rhel-10.2-x86_64-dvd"
  }
}

# Optional per-source override: a datastore path such as
# "[vcf-lab-mgmt-cl01-vsan] iso/rhel-9.8-x86_64-dvd.iso". Same escape hatch as
# windows11's windows_iso_datastore_path, for when the NFS datastore behind the
# content library cannot mount ISOs. Empty or absent means use the library item.
variable "iso_datastore_paths" {
  type        = map(string)
  description = "Per-source datastore ISO path that overrides the library item."
  default     = {}
}

variable "ssh_username" {
  type    = string
  default = "labuser"
}

variable "ssh_password" {
  type      = string
  default   = ""
  sensitive = true
}
