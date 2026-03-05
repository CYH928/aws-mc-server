output "player_connect_address" {
  description = "Players connect to this address"
  value       = "${var.duckdns_subdomain}.duckdns.org"
}

output "watcher_public_ip" {
  description = "Watcher public IP (fallback if DuckDNS not updated yet)"
  value       = aws_instance.watcher.public_ip
}

output "mc_server_private_ip" {
  description = "MC server fixed private IP"
  value       = aws_instance.minecraft.private_ip
}

output "pterodactyl_panel_url" {
  description = "Pterodactyl Panel (only accessible when MC server is ON)"
  value       = "http://${aws_instance.minecraft.public_ip}:8080"
}

output "s3_backup_bucket" {
  value = aws_s3_bucket.backup.id
}
