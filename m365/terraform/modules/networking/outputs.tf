output "public_ip" {
  description = "The public IP of the firewall if it was created, else null"
  value       = var.firewall == null ? null : data.azurerm_public_ip.firewall_ip[0].ip_address
}

output "aci_subnet_id" {
  description = "The subnet to be used for the Azure Container Instances"
  value       = azurerm_subnet.aci-subnet.id
}