terraform {
    required_providers {
        azurerm = {
        source  = "hashicorp/azurerm"
        version = "2.46.0"
        }
    }
}

provider "azurerm" {
    features {}
}

# SSH Public Key for Linux VMs
variable "ssh_public_key" {
  default = "C:\\Users\\Youssef\\.ssh\\id_rsa.pub"
  description = "This variable defines the SSH Public Key for Linux k8s Worker nodes"  
}

resource "azurerm_resource_group" "acr-pfe-rg" {
  name     = "acr-pfe-rg"
  location = "France Central"
  tags = {
    environment = "dev"
  }
}
  
resource "azurerm_resource_group" "aks-pfe-rg" {
  name     = "aks-pfe-rg"
  location = "France Central"
  tags = {
    environment = "dev"
  }
}

resource "azurerm_container_registry" "acrpfe" {
  name                     = "acrpfe"
  resource_group_name      = azurerm_resource_group.acr-pfe-rg.name
  location                 = azurerm_resource_group.acr-pfe-rg.location
  sku                      = "Basic"
  admin_enabled            = true
  tags = {
    environment = "dev"
  }
}

# Authenticate Docker to the ACR
resource "null_resource" "docker_login" {
  provisioner "local-exec" {
    command = "az acr login --name acrpfe"
  }
}

# Push the Docker image shoppingapi to ACR
resource "null_resource" "push_images_shoppingapi" {
  provisioner "local-exec" {
    command = <<-EOT
      docker push acrpfe.azurecr.io/shoppingapi:v1
    EOT
  }
  depends_on = [null_resource.docker_login]
}

# Push the Docker image shoppingclient to ACR
resource "null_resource" "push_images_shoppingclient" {
  provisioner "local-exec" {
    command = <<-EOT
      docker push acrpfe.azurecr.io/shoppingclient:v1
    EOT
  }
  depends_on = [null_resource.docker_login]
}
resource "azurerm_kubernetes_cluster" "akspfe" {
  name                      = "akspfe"
  location                  = azurerm_resource_group.aks-pfe-rg.location
  resource_group_name       = azurerm_resource_group.aks-pfe-rg.name
  dns_prefix                = "aks-pfe"
  kubernetes_version        = "1.27.1"
  node_resource_group       = "aks-pfe-rg-nodes"
  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "standard_a2_v2"
  }

  linux_profile {
    admin_username = "azureuser"
    ssh_key {
      key_data =  file(var.ssh_public_key)
    }
  }

  identity {
    type = "SystemAssigned"
  }
}
