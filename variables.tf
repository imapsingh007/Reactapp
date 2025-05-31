variable "prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "aditya"
}

variable "location" {
  default = "westeurope"  # Or another region where SQL is allowed
}


variable "ssl_certificate_data" {
  description = "Base64-encoded PFX data for App Gateway SSL certificate"
  type        = string
  default     = ""   # supply certificate data if HTTPS is required
}

variable "ssl_certificate_password" {
  description = "Password for the PFX certificate (App Gateway SSL cert)"
  type        = string
  default     = ""
}

# (Optionally, you can override admin credentials by adding more variables)
