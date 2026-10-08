variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
  sensitive   = true
}

variable "client_id" {
  description = "Service principal application/client ID"
  type        = string
  sensitive   = true
}

variable "client_secret" {
  description = "Service principal client secret"
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID"
  type        = string
  sensitive   = true
}

variable "location" {
  description = "Azure region where resources will be deployed"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "networks" {
  description = "A map of network configurations"
  type = map(object({
    name     = string
    addspace = list(string)
  }))
}



variable "webapp_plan" {
  description = "Name of the App Service Plan"
  type        = string
  sensitive   = true
}

variable "webapp_service" {
  description = "Name of the App Service"
  type        = string
  sensitive   = true
}

variable "app_service_sku" {
  description = "SKU for the App Service Plan"
  type        = string

}

variable "app_subnet_name" {
  description = "Subnet used for App Service VNet Integration"
  type        = string
  default     = "snet-app-prod"
}

variable "private_endpoint_subnet_name" {
  description = "Subnet used for the App Service Private Endpoint"
  type        = string
  default     = "snet-endpoint-prod"
}

variable "private_dns_zone_name" {
  description = "Private DNS zone for Azure App Service Private Endpoint"
  type        = string
  default     = "privatelink.azurewebsites.net"
}
