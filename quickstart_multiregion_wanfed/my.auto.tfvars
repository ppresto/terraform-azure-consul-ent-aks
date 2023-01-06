# The first region defined will host the primary consul cluster
regions              = ["eastus", "westus2"]
region_cidr_list     = ["172.16.0.0/16", "172.17.0.0/16"]
resource_name_prefix = "presto"
create_consul_tf     = true
consul_node_count    = 3
consul_version       = "1.11.5"
enable_cluster_peering = false
consul_helm_chart_version  = "0.41.1"
consul_helm_chart_template = "0.41.1"  # WAN Fed uses only includes version to support both primary/secondary templates.