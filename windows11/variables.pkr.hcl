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
  description = "Unused by the Windows 11 build (it boots the remastered ISO); kept so the variable set matches windows/."
  default     = ""
}

variable "windows_remastered_iso_filename" {
  type        = string
  description = "Filename of the remastered Win2025 ISO inside the server2025-remastered content library item."
  default     = ""
}

variable "windows_tools_iso_path" {
  type        = string
  description = "Full datastore path to the VMware Tools ISO served by every ESXi host."
  default     = "[] /vmimages/tools-isoimages/windows.iso"
}

variable "windows_product_key" {
  type        = string
  description = "Microsoft-published GVLK for the target edition."
  default     = "W269N-WFGWX-YVC9B-4J6C9-T83GX"
}

variable "windows_image_name" {
  type        = string
  description = "Value for <InstallFrom>/IMAGE/NAME in autounattend.xml."
  default     = "Windows 11 Pro"
}

variable "organization_name" {
  type    = string
  default = "Sentania Lab"
}

variable "timezone" {
  type    = string
  default = "Central Standard Time"
}

variable "vsphere_host" {
  type        = string
  description = "Optional ESXi host for the build VM; empty lets DRS choose."
  default     = ""
}

variable "windows_iso_datastore_path" {
  type        = string
  description = "Optional datastore path of the install ISO, e.g. \"[datastore] folder/file.iso\". Overrides the content library item when set."
  default     = ""
}
