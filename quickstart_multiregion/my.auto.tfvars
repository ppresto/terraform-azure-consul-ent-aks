# The first region defined will host the primary consul cluster
regions              = ["eastus", "westus2"]
region_cidr_list     = ["172.16.0.0/16", "172.17.0.0/16"]
resource_name_prefix = "dmed"
consul_version       = "1.14.3-ent"
enable_cluster_peering = true
consul_helm_chart_version = "1.0.2"
consul_helm_chart_template = "values-peer-mesh.yaml"
consul_client_helm_chart_template = "values-client-agentless-mesh.yaml"