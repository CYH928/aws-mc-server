variable "aws_region" {
  description = "AWS region (ap-east-1 = Hong Kong)"
  default     = "ap-east-1"
}

variable "key_pair_name" {
  description = "EC2 Key Pair name for SSH access"
  type        = string
}

variable "duckdns_token" {
  description = "DuckDNS token from duckdns.org"
  type        = string
  sensitive   = true
}

variable "duckdns_subdomain" {
  description = "DuckDNS subdomain, e.g. 'mymc' for mymc.duckdns.org"
  type        = string
}

variable "admin_cidr" {
  description = "Your IP for SSH and Pterodactyl Panel access, e.g. '1.2.3.4/32'"
  type        = string
  default     = "0.0.0.0/0"
}

variable "mc_instance_type" {
  description = "Minecraft server instance type"
  default     = "t3.xlarge"
}

variable "watcher_instance_type" {
  description = "Watcher instance type (always on)"
  default     = "t4g.nano"
}

variable "backup_bucket_name" {
  description = "Globally unique S3 bucket name for world backups"
  type        = string
}

variable "mc_version" {
  description = "Minecraft version"
  default     = "1.21.4"
}

variable "rcon_password" {
  description = "RCON password for server console access"
  type        = string
  sensitive   = true
}

variable "alert_email" {
  description = "Email for billing alerts"
  type        = string
}

variable "billing_threshold_usd" {
  description = "Monthly billing alert threshold in USD"
  default     = 50
}
