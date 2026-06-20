output "eni_id" {
  description = "ID del ENI"
  value       = aws_network_interface.this.id
}

output "private_ip" {
  description = "IP privada asignada al ENI — fija mientras el ENI exista"
  value       = aws_network_interface.this.private_ip
}

output "subnet_id" {
  description = "Subnet del ENI"
  value       = aws_network_interface.this.subnet_id
}

output "mac_address" {
  description = "MAC address del ENI"
  value       = aws_network_interface.this.mac_address
}