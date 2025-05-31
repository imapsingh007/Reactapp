terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.50.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">=3.0.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
  subscription_id = "1b07d375-e28d-4dd8-9a73-6e18dd9f7b3c"
}



# Generate random passwords for SQL and Function Apps
resource "random_password" "sql_admin" {
  length           = 16
  special          = true
}
resource "random_password" "func_storage" {
  length  = 16
  special = true
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-rg"
  location = var.location
}

# Virtual Network and Subnets
resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "aks_subnet" {
  name                 = "${var.prefix}-subnet-aks"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]

  service_endpoints = ["Microsoft.Sql"]


}


resource "azurerm_subnet" "appgw_subnet" {
  name                 = "${var.prefix}-subnet-appgw"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Azure Container Registry
resource "azurerm_container_registry" "acr" {
  name                     = "${var.prefix}acr12356789"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  sku                      = "Standard"
  admin_enabled            = false
}

# Azure Log Analytics Workspace (for monitoring)
resource "azurerm_log_analytics_workspace" "loganalytics" {
  name                = "${var.prefix}-law"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# Azure Application Insights
resource "azurerm_application_insights" "app_insights" {
  name                = "${var.prefix}-appi"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  application_type    = "web"
}

# Azure Key Vault
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                        = "${var.prefix}-kv"
  resource_group_name         = azurerm_resource_group.main.name
  location                    = azurerm_resource_group.main.location
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  enable_rbac_authorization   = true
}

# Allow AKS cluster managed identity to get/list secrets
resource "azurerm_role_assignment" "kv_aks" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}

# Azure Storage Accounts (App, Data, Backup)
resource "azurerm_storage_account" "storage_app" {
  name                     = "${var.prefix}appsa"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  access_tier              = "Hot"
}

resource "azurerm_storage_account" "storage_data" {
  name                     = "${var.prefix}datsa"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  access_tier              = "Hot"
}

resource "azurerm_storage_account" "storage_backup" {
  name                     = "${var.prefix}baksa"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  access_tier              = "Hot"
}

# Azure SQL Server and Database
resource "azurerm_mssql_server" "sql" {
  name                         = "${var.prefix}-sqlserver"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = "sqladminuser"
  administrator_login_password = random_password.sql_admin.result
}

resource "azurerm_mssql_database" "sqldb" {
  name                = "${var.prefix}-sqldb"
  server_id           = azurerm_mssql_server.sql.id
  sku_name            = "S0"
  zone_redundant      = false
}

# SQL Firewall rule: allow Azure services
resource "azurerm_mssql_virtual_network_rule" "sql_allow_azure" {
  name      = "allow-vnet"
  server_id = azurerm_mssql_server.sql.id
  subnet_id = azurerm_subnet.aks_subnet.id
}


# Azure SignalR Service
resource "azurerm_signalr_service" "signalr" {
  name                = "${var.prefix}-signalr"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  sku {
    name     = "Standard_S1"
    capacity = 1
  }
}


# Azure Redis Cache
resource "azurerm_redis_cache" "redis" {
  name                = "${var.prefix}-redis"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  capacity            = 1
  family              = "C"
  sku_name            = "Standard"
}

# Azure Front Door (Standard/Premium)
resource "azurerm_cdn_frontdoor_profile" "afd_profile" {
  name                = "${var.prefix}-fdp"
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "Standard_AzureFrontDoor"
}


resource "azurerm_cdn_frontdoor_endpoint" "afd_endpoint" {
  name                        = "${var.prefix}-fde"
  cdn_frontdoor_profile_id    = azurerm_cdn_frontdoor_profile.afd_profile.id
}

resource "azurerm_cdn_frontdoor_origin_group" "afd_origin_group" {
  name                      = "${var.prefix}-fog"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.afd_profile.id

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }

  health_probe {
    interval_in_seconds = 240
    path                = "/"
    protocol            = "Https"
    request_type        = "GET"
  }
}



resource "azurerm_cdn_frontdoor_origin" "afd_origin" {
  name                           = "${var.prefix}-origin"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.afd_origin_group.id
  enabled                        = true
  host_name                      = azurerm_public_ip.appgw_ip.ip_address
  origin_host_header             = azurerm_public_ip.appgw_ip.ip_address
  certificate_name_check_enabled = false
  http_port                      = 80
  https_port                     = 443
  priority                       = 1
  weight                         = 100
}


resource "azurerm_cdn_frontdoor_route" "afd_route" {
  name                                = "${var.prefix}-fdr"
  cdn_frontdoor_endpoint_id           = azurerm_cdn_frontdoor_endpoint.afd_endpoint.id
  cdn_frontdoor_origin_group_id       = azurerm_cdn_frontdoor_origin_group.afd_origin_group.id
  cdn_frontdoor_origin_ids            = [azurerm_cdn_frontdoor_origin.afd_origin.id]
  supported_protocols                 = ["Http", "Https"]
  patterns_to_match                   = ["/*"]
  forwarding_protocol                 = "MatchRequest"
  cache {
    query_string_caching_behavior = "IgnoreQueryString"
  }
}


# Azure Public IP for Application Gateway
resource "azurerm_public_ip" "appgw_ip" {
  name                = "${var.prefix}-appgw-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_application_gateway" "appgw" {
  name                = "${var.prefix}-appgw"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "appGatewayIpConfig"
    subnet_id = azurerm_subnet.appgw_subnet.id
  }

  frontend_ip_configuration {
    name                 = "appGatewayFrontendIP"
    public_ip_address_id = azurerm_public_ip.appgw_ip.id
  }

  frontend_port {
    name = "frontendPort80"
    port = 80
  }

  backend_address_pool {
    name = "reacttodo-backend"
    fqdns = ["reacttodo-ui-svc.default.svc.cluster.local"]  # ✅ Use fqdns list, NOT `backend_addresses` block
  }

  backend_http_settings {
    name                  = "reacttodo-http"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
  }

  http_listener {
    name                           = "reacttodo-listener"
    frontend_ip_configuration_name = "appGatewayFrontendIP"
    frontend_port_name             = "frontendPort80"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "reacttodo-route"
    rule_type                  = "Basic"
    http_listener_name         = "reacttodo-listener"
    backend_address_pool_name  = "reacttodo-backend"
    backend_http_settings_name = "reacttodo-http"
    priority                   = 110
  }

  waf_configuration {
    enabled          = true
    firewall_mode    = "Prevention"
    rule_set_type    = "OWASP"
    rule_set_version = "3.2"
  }

  depends_on = [azurerm_subnet.appgw_subnet]
}




# resource "azurerm_application_gateway_backend_address_pool" "reacttodo_backend" {
#   name                     = "reacttodo-backend"
#   resource_group_name      = azurerm_resource_group.main.name
#   application_gateway_name = azurerm_application_gateway.appgw.name
#
#   backend_addresses {
#     fqdn = "reacttodo-ui-svc.default.svc.cluster.local"
#   }
# }
#
# resource "azurerm_application_gateway_request_routing_rule" "reacttodo_rule" {
#   name                       = "reacttodo-route"
#   resource_group_name        = azurerm_resource_group.main.name
#   application_gateway_name   = azurerm_application_gateway.appgw.name
#   rule_type                  = "Basic"
#   http_listener_name         = "reacttodo-listener"
#   backend_address_pool_name  = azurerm_application_gateway_backend_address_pool.reacttodo_backend.name
#   backend_http_settings_name = "reacttodo-http"
#   priority                   = 110
# }



# AKS Cluster with Managed Identity and Azure AD integration
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.prefix}-aks"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${var.prefix}-aks"

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name           = "nodepool"
    node_count     = 2
    vm_size        = "Standard_DS2_v2"
    vnet_subnet_id = azurerm_subnet.aks_subnet.id
  }

  network_profile {
    network_plugin     = "azure"
    network_policy     = "azure"
    service_cidr       = "10.2.0.0/16"
    dns_service_ip     = "10.2.0.10"
  }

  depends_on = [
    azurerm_container_registry.acr
  ]
}



# Assign AKS cluster identity pull role on ACR
resource "azurerm_role_assignment" "acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}

# Durable Azure Function (Consumption Plan)
resource "azurerm_service_plan" "function_plan" {
  name                = "${var.prefix}-func-plan"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "Y1" # Consumption Plan
}



resource "azurerm_storage_account" "function_storage" {
  name                     = "${var.prefix}funcsa"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_function_app" "function" {
  name                       = "${var.prefix}-func"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  app_service_plan_id        = azurerm_service_plan.function_plan.id
  storage_account_name       = azurerm_storage_account.function_storage.name
  storage_account_access_key = azurerm_storage_account.function_storage.primary_access_key
  version                    = "~4"
  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"  = "dotnet"
    "WEBSITE_RUN_FROM_PACKAGE" = "1"
    "APPINSIGHTS_INSTRUMENTATIONKEY" = azurerm_application_insights.app_insights.instrumentation_key
  }
  identity {
    type = "SystemAssigned"
  }
  depends_on = [azurerm_service_plan.function_plan, azurerm_storage_account.function_storage]
}

# Grant Function App identity access to Key Vault (secrets)
resource "azurerm_role_assignment" "kv_func" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_function_app.function.identity[0].principal_id
}

