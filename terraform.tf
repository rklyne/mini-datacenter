
# DO ssh key id. Must already be uploaded
variable "ssh_key_id" {}
# Private key file on disk matching SSH key above
variable "private_key" {}
# DO API token
variable "do_token" {}

variable "consul_server_size" {
    default = "512mb"
}
variable "db_server_size" {
    default = "512mb"
}
variable "app_server_size" {
    default = "512mb"
}
variable "datacenter" {
    default = "dc1"
}
variable "domain" {
    default = "example.net"
}

provider "digitalocean" {
    token = "${var.do_token}"
}


module "consul-cluster" {
    source = "./consul-cluster"
    servers = 1
    ssh_key_id = "${var.ssh_key_id}"
    private_key = "${var.private_key}"
    size = "${var.consul_server_size}"
    domain = "${var.domain}"
}


module "vault-1" {
    servers = 1
    source = "./vault"
    prefix = "vault"
    ssh_key_id = "${var.ssh_key_id}"
    private_key = "${var.private_key}"
    size = "${var.consul_server_size}"
    domain = "${var.domain}"
    consul_ipv4_addresses = ["${module.consul-cluster.ip_addresses}"]
}

module "puppetmaster" {
    servers = 1
    source = "./puppetserver"
    prefix = "puppetmaster"
    ssh_key_id = "${var.ssh_key_id}"
    private_key = "${var.private_key}"
    size = "${var.consul_server_size}"
    domain = "${var.domain}"
    consul_ipv4_addresses = ["${module.consul-cluster.ip_addresses}"]
}

module "puppetagent" {
    servers = 1
    source = "./puppetagent"
    prefix = "agent"
    ssh_key_id = "${var.ssh_key_id}"
    private_key = "${var.private_key}"
    size = "${var.consul_server_size}"
    domain = "${var.domain}"
    consul_ipv4_addresses = ["${module.consul-cluster.ip_addresses}"]
    datacenter = "${var.datacenter}"
    puppetmaster = "${element(module.puppetmaster.ip_addresses, 0)}"
}

# module "spike" {
#     servers = 1
#     source = "./base"
#     prefix = "spike"
#     ssh_key_id = "${var.ssh_key_id}"
#     private_key = "${var.private_key}"
#     size = "${var.consul_server_size}"
#     domain = "${var.domain}"
#     consul_ipv4_addresses = ["${module.consul-cluster.ip_addresses}"]
# }
# 


# module "redis-test" {
#     servers = 1
#     source = "./redis"
#     prefix = "redistest"
#     ssh_key_id = "${var.ssh_key_id}"
#     private_key = "${var.private_key}"
#     size = "${var.consul_server_size}"
#     domain = "${var.domain}"
#     consul_ipv4_addresses = ["${module.consul-cluster.ip_addresses}"]
# }



# module "vault-2" {
#     source = "./vault"
#     prefix = "testvault"
#     ssh_key_id = "${var.ssh_key_id}"
#     private_key = "${var.private_key}"
#     size = "${var.consul_server_size}"
#     domain = "${var.domain}"
#     consul_ipv4_addresses = ["${module.consul-cluster.ip_addresses}"]
# }

