locals {
  name = "${var.name}-${var.environment}"

  common_tags = {
    Application = var.name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
