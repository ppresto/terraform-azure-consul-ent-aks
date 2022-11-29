# The first region defined will host the primary consul cluster
regions              = ["eastus", "westus2"]
region_cidr_list     = ["172.16.0.0/16", "172.17.0.0/16"]
resource_name_prefix = "dmed"
consul_version       = "1.14.0-ent"
#consul_chart_name         = "/Users/patrickpresto/Projects/consul/consul-k8s/charts/consul"