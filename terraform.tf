
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
variable "domain" {
    default = "example.net"
}

provider "digitalocean" {
    token = "${var.do_token}"
}


module "consul-cluster" {
    source = "./consul-cluster"
    servers = 3
    ssh_key_id = "${var.ssh_key_id}"
    private_key = "${var.private_key}"
    size = "${var.consul_server_size}"
    domain = "${var.domain}"
}


module "vault-1" {
    source = "./vault"
    prefix = "vault"
    ssh_key_id = "${var.ssh_key_id}"
    private_key = "${var.private_key}"
    size = "${var.consul_server_size}"
    domain = "${var.domain}"
    consul_ipv4_addresses = ["${module.consul-cluster.ip_addresses}"]
}

# module "vault-2" {
#     source = "./vault"
#     prefix = "testvault"
#     ssh_key_id = "${var.ssh_key_id}"
#     private_key = "${var.private_key}"
#     size = "${var.consul_server_size}"
#     domain = "${var.domain}"
#     consul_ipv4_addresses = ["${module.consul-cluster.ip_addresses}"]
# }

