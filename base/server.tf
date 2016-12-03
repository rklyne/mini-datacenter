output "ip_addresses" {
    value = ["${digitalocean_droplet.host.*.ipv4_address}"]
}
output "ids" {
    value = ["${digitalocean_droplet.host.*.id}"]
}
variable "prefix" {}
variable "domain" {}
variable "ssh_key_id" {}
variable "private_key" {}
variable "servers" {}
variable "size" {
    default = "512mb"
}
variable "region" {
    default = "lon1"
}
variable "consul_ipv4_addresses" {
    default = []
}

data "template_file" "config" {
    template = "${file("${path.module}/consul.conf")}"

    vars {
        node_name = "${uuid()}"
        datacenter = "dc1"
    }
}

resource "digitalocean_droplet" "host" {
    count = "${var.servers}"
    name = "${var.prefix}-${count.index + 1}.${var.domain}"
    size = "${var.size}"
    image = "centos-6-5-x64"
    region = "${var.region}"
    private_networking = true
    ssh_keys = [ "${var.ssh_key_id}" ]

    connection {
        user = "root"
        type = "ssh"
        key_file = "${var.private_key}"
        timeout = "30s"
    }

    provisioner "file" {
        source = "${path.module}/service.sh"
        destination = "/etc/init.d/consul"
    }

    provisioner "file" {
        destination = "/etc/consul.conf"
        content = "${data.template_file.config.rendered}"
    }

    provisioner "remote-exec" {
        inline = [
            "echo \"==> Starting to provision CentOS base.\"",
            "mkdir /root/.pip/",
            # Swap is necessary to build libs (e.g. lxml) on 512mb ram.
            # 4Gb.
            "echo makign swap file",
            "dd if=/dev/zero of=/swapfile bs=1M count=4096",
            "echo formattign swap file",
            "mkswap /swapfile",
            "echo activating swap",
            "swapon /swapfile",
            "echo swap ready",
        ]
    }

    provisioner "remote-exec" {
        inline = [
            "yum update -y",
            "yum install -y wget unzip bind-utils",
            "wget https://releases.hashicorp.com/consul/0.7.1/consul_0.7.1_linux_amd64.zip",
            "wget https://releases.hashicorp.com/consul-template/0.16.0/consul-template_0.16.0_linux_amd64.zip",
            "unzip consul_*.zip",
            "unzip consul-template_*.zip",
            "mv consul /usr/local/bin",
            "chmod +x /etc/init.d/consul",
            "useradd -m consul",
            "mkdir /etc/consul.d",
            "mkdir /opt/consul",
            "chown consul. /opt/consul",
        ]
    }

    provisioner "remote-exec" {
        inline = [
            "chmod +x /etc/init.d/consul",
            "echo '{\"advertise_addr\": \"${self.ipv4_address_private}\"}' > /etc/consul.d/private_address.json",
            "service consul start",
            "sleep 3",
            "consul join ${join(" ", var.consul_ipv4_addresses)}",
        ]
    }
}

resource "digitalocean_domain" "dns" {
    count = "${var.servers}"

    name = "${var.prefix}-${count.index + 1}.${var.domain}"
    ip_address = "${element(digitalocean_droplet.host.*.ipv4_address, count.index)}"
}


