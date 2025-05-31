output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "aks_cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "aks_kube_config" {
  description = "AKS cluster kubeconfig (use az cli to fetch credentials)"
  value       = azurerm_kubernetes_cluster.aks.kube_admin_config_raw
  sensitive   = true
}

output "acr_login_server" {
  description = "ACR login server (use for Docker images)"
  value       = azurerm_container_registry.acr.login_server
}

output "sql_server_fqdn" {
  description = "Fully qualified domain name of the Azure SQL server"
  value       = azurerm_mssql_server.sql.fully_qualified_domain_name
}

output "sql_database_name" {
  description = "Name of the SQL database"
  value       = azurerm_mssql_database.sqldb.name
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.kv.vault_uri
}

output "function_app_default_hostname" {
  description = "Azure Function App default hostname"
  value       = azurerm_function_app.function.default_hostname
}

output "app_gateway_public_ip" {
  description = "Public IP address of Application Gateway"
  value       = azurerm_public_ip.appgw_ip.ip_address
}

output "frontdoor_endpoint_hostname" {
  description = "Front Door endpoint hostname"
  value       = azurerm_cdn_frontdoor_endpoint.afd_endpoint.host_name
}

output "app_insights_instrumentation_key" {
  value     = azurerm_application_insights.app_insights.instrumentation_key
  sensitive = true  # ✅ Required to avoid error
}



