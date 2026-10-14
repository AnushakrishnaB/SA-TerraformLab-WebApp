variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
}

variable "location" {
  type        = string
  description = "Primary Azure region"
}

variable "resource_group_name" {
  type    = string
  default = "rg-storage-replication-lab"
}

variable "storage_account_name" {
  type        = string
  description = "Globally unique lowercase alphanumeric name"

  validation {
    condition = (
      length(var.storage_account_name) >= 3 &&
      length(var.storage_account_name) <= 24 &&
      can(regex("^[a-z0-9]+$", var.storage_account_name))
    )
    error_message = "Use 3-24 lowercase letters or numbers only."
  }
}

variable "replication_type" {
  type        = string
  description = "Storage redundancy setting"
  default     = "RAGRS"

  validation {
    condition = contains(
      ["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"],
      var.replication_type
    )
    error_message = "Choose a supported replication type."
  }
}
