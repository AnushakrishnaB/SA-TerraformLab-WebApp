variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
}

variable "admin_username" {
  type    = string
  default = "labadmin"
}

variable "admin_ssh_public_key" {
  type        = string
  description = "Contents of your SSH public key file"
}

variable "admin_source_ip" {
  type        = string
  description = "Your public IP in CIDR format, for example 203.0.113.10/32"
}

variable "location" {
  type    = string
  default = "canadacentral"
}

variable "target_location" {
  type    = string
  default = "canadaeast"
}
variable "cache_storage_account_name" {
  description = "Globally unique lowercase storage account name"
  type        = string
}
