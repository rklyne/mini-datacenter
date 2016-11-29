variable "servers" {
    default = 3
}
variable "domain" {}
variable "ssh_key_id" {}
variable "private_key" {}
variable "size" {
    default = "512mb"
}
variable "region" {
    default = "lon1"
}

module "consul-server" {
    servers = "${var.servers}"
    source = "../consul"
    prefix = "consul"
    domain = "${var.domain}"
    ssh_key_id = "${var.ssh_key_id}"
    private_key = "${var.private_key}"
    size = "${var.size}"
    region = "${var.region}"
}

resource "null_resource" "server_config" {
    count = "${var.servers}"

    connection {
        host = "${element(module.consul-server.ip_addresses, count.index)}"
        user = "root"
        type = "ssh"
        key_file = "${var.private_key}"
        timeout = "30s"
    }

    provisioner "remote-exec" {
        inline = [
            "echo '{\"server\": true}' > /etc/consul.d/server.json",
            "service consul restart",
        ]
    }
}

resource "null_resource" "cluster_init" {
    depends_on = ["null_resource.server_config"]

    connection {
        host = "${element(module.consul-server.ip_addresses, 0)}"
        user = "root"
        type = "ssh"
        key_file = "${var.private_key}"
        timeout = "30s"
    }

    provisioner "remote-exec" {
        inline = [
            "echo '{\"bootstrap_expect\": ${var.servers}}' > /etc/consul.d/bootstrap.json",
            "service consul restart",
            "/usr/local/bin/consul join ${join(" ", module.consul-server.ip_addresses)}"
        ]
    }
}

