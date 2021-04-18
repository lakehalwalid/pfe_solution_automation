provider "azurerm" {
  features {}
}

#create a resource group
resource "azurerm_resource_group" "terra_rg" {
  name = var.resource_group_name
  location = var.location
}



#create virtual network
resource "azurerm_virtual_network" "terra_vnet"{
  name                = join("-", [var.prefix,"vnet"])
  location            = azurerm_resource_group.terra_rg.location
  resource_group_name = azurerm_resource_group.terra_rg.name
  address_space       = ["10.0.0.0/16"]
}

#create a subnet within vnet
resource "azurerm_subnet" "terra_subnet_public" {
  name                 = join("-", [var.prefix,"subnet-public"])
  resource_group_name  = azurerm_resource_group.terra_rg.name
  virtual_network_name = azurerm_virtual_network.terra_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

#create a 2nd subnet within vnet
resource "azurerm_subnet" "terra_subnet" {
  name                 = join("-", [var.prefix,"subnet"])
  resource_group_name  = azurerm_resource_group.terra_rg.name
  virtual_network_name = azurerm_virtual_network.terra_vnet.name
  address_prefixes     = ["10.0.5.0/24"]
}


# create public ip add
resource "azurerm_public_ip" "terra_public_ip" {
  count               = var.vm_count
  name                = join("-", [var.prefix,"PublicIp",count.index])
  location            = azurerm_resource_group.terra_rg.location
  resource_group_name = azurerm_resource_group.terra_rg.name
  allocation_method   = "Dynamic"
}


#create a nic
resource "azurerm_network_interface" "terra_nic" {
  count               = var.vm_count
  name                = join("-", [var.prefix,"nic",count.index])
  location            = azurerm_resource_group.terra_rg.location
  resource_group_name = azurerm_resource_group.terra_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.terra_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

#create a nic for public ip
resource "azurerm_network_interface" "terra_nic_public" {
  count               = var.vm_count
  name                = join("-", [var.prefix,"nic-public",count.index])
  location            = azurerm_resource_group.terra_rg.location
  resource_group_name = azurerm_resource_group.terra_rg.name

  ip_configuration {
    name                          = "external"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.terra_subnet_public.id
    primary                       = true
    public_ip_address_id          = element(azurerm_public_ip.terra_public_ip.*.id, count.index)
  }
}



#creat resource NSG
resource "azurerm_network_security_group" "terra_nsg" {
  name                = join("-", [var.prefix,"nsg"])
  location            = azurerm_resource_group.terra_rg.location
  resource_group_name = azurerm_resource_group.terra_rg.name
  security_rule       = [{
         description                                = "rule for nsg "
         name                                       = "Inbound"
         priority                                   = 100
         direction                                  = "Inbound"
         access                                     = "Allow"
         protocol                                   = "Tcp"
         source_port_range                          = "*"
         destination_port_range                     = "*"
         source_address_prefix                      = "*"
         destination_address_prefix                 = "*"
         destination_application_security_group_ids = null
         source_application_security_group_ids      = null
         source_port_ranges                         = null
         destination_port_ranges                    = null
         source_address_prefixes                    = null
         destination_address_prefixes               = null

  }]
}

# subnet and NSG association
resource "azurerm_subnet_network_security_group_association" "terra_subnet_nsg_association" {
  subnet_id                 = azurerm_subnet.terra_subnet.id
  network_security_group_id = azurerm_network_security_group.terra_nsg.id
}



# create linux vms
resource "azurerm_virtual_machine" "terra_linux_vms" {
  count                            = var.vm_count
  name                             = join("-", [var.prefix,"vm",count.index])
  location                         = azurerm_resource_group.terra_rg.location
  resource_group_name              = azurerm_resource_group.terra_rg.name
  network_interface_ids            = [element(azurerm_network_interface.terra_nic.*.id, count.index),element(azurerm_network_interface.terra_nic_public.*.id, count.index)]
  primary_network_interface_id     = element(azurerm_network_interface.terra_nic_public.*.id, count.index)
  vm_size                          = "Standard_B4ms"
  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  storage_os_disk {
    name              = join("-", ["myosdisk",count.index])
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  =  join("-", [var.prefix,"vm",count.index])
    admin_username = "horizon"
    admin_password = "Horizondocker31*"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
}


output "terra_ips"{
 value = azurerm_public_ip.terra_public_ip.*.ip_address
}

