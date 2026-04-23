variable "content_library_destination" {
  type    = string
  default = "vcf-lab-mgmt-contentlibrary"
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
  default = 4096
}

variable "disk_size" {
  type    = number
  default = 92160
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

variable "vsphere_password" {
  type      = string
  default   = ""
  sensitive = true
}

variable "winrm_username" {
  type    = string
  default = "labuser"
}

variable "winrm_password" {
  type      = string
  default   = ""
  sensitive = true
}

variable "windows_iso_path" {
  type        = string
  description = "Path to the Server 2025 ISO inside the content library item (relative to content_library_destination)."
  default     = "server2025-iso/file.iso"
}

variable "windows_tools_iso_path" {
  type        = string
  description = "Full datastore path to the VMware Tools ISO served by every ESXi host."
  default     = "[] /vmimages/tools-isoimages/windows.iso"
}

variable "windows_product_key" {
  type        = string
  description = "Microsoft-published GVLK for the target edition."
  default     = "TVRH6-WHNXV-R9WG3-9XRFY-MY832"
}

variable "windows_image_name" {
  type        = string
  description = "Value for <InstallFrom>/IMAGE/NAME in autounattend.xml."
  default     = "Windows Server 2025 SERVERSTANDARD"
}

variable "organization_name" {
  type    = string
  default = "Sentania Lab"
}

variable "timezone" {
  type    = string
  default = "Eastern Standard Time"
}
