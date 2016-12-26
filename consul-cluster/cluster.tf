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

output "ip_addresses" {
    value = ["${module.consul-server.ip_addresses}"]
}

module "consul-server" {
    servers = "${var.servers}"
    source = "../base"
    prefix = "consul"
    domain = "${var.domain}"
    ssh_key_id = "${var.ssh_key_id}"
    private_key = "${var.private_key}"
    size = "${var.size}"
    region = "${var.region}"
}

resource "null_resource" "server_config" {
    depends_on = ["module.consul-server"]

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
            "yum install -y dnsmasq",
            "echo 'server=/consul/127.0.0.1#8600' > /etc/dnsmasq.d/consul",
            "echo 'conf-dir=/etc/dnsmasq.d' >> /etc/dnsmasq.conf",
            "echo '{\"server\": true}' > /etc/consul.d/server.json",
            "echo '{\"bootstrap_expect\": ${var.servers}}' > /etc/consul.d/bootstrap.json",
            "service consul restart",
            "service dnsmasq restart",
            # "iptables -t nat -A PREROUTING -p udp -m udp --dport 53 -j REDIRECT --to-ports 8600",
            # "iptables -t nat -A PREROUTING -p tcp -m tcp --dport 53 -j REDIRECT --to-ports 8600",
            # "iptables -t nat -A OUTPUT -d localhost -p udp -m udp --dport 53 -j REDIRECT --to-ports 8600",
            # "iptables -t nat -A OUTPUT -d localhost -p tcp -m tcp --dport 53 -j REDIRECT --to-ports 8600",
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
            "/usr/local/bin/consul join ${join(" ", module.consul-server.ip_addresses)} || echo \"No nodes to join\""
        ]
    }
}

