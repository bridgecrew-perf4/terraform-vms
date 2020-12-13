node_location      = "Korea Central"
resource_prefix    = "gluster"
environment        = "Production"
total_node_count   = 5
cluster_node_count = 3
#variable for network range
subnet_name    = ["snet_01", "snet_02"]
subnet_cidr    = ["192.168.1.0/24", "192.168.2.0/24"]
ilb_probe_port = 59998
admin_username = "pashim"
admin_password = ""
