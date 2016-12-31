output "hostnames" {
    depends_on = ["digitalocean_domain.dns.*"]
    value = ["${digitalocean_domain.dns.*.name}"]
}
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
variable "datacenter" {
    default = "dc1"
}

data "template_file" "config" {
    template = "${file("${path.module}/consul.conf")}"

    vars {
        node_name = "NODE_NAME"
        datacenter = "${var.datacenter}"
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
            "echo making swap file",
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
            "mv consul-template /usr/local/bin",
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
            "sed -i 's/NODE_NAME/${uuid()}/' /etc/consul.conf",
            "echo '{\"advertise_addr\": \"${self.ipv4_address_private}\"}' > /etc/consul.d/private_address.json",
            "echo -e 'nameserver ${join("\nnameserver ", var.consul_ipv4_addresses)}' > /tmp/new-resolv.conf",
            "cat /tmp/new-resolv.conf | sort | uniq > /tmp/new-resolv2.conf",
            "cat /etc/resolv.conf >> /tmp/new-resolv2.conf",
            "cat /tmp/new-resolv2.conf > /etc/resolv.conf",
            "service consul start",
            "sleep 3",
            "for srv in ${join(" ", var.consul_ipv4_addresses)}; do consul join $srv; done",
        ]
    }
}

resource "digitalocean_domain" "dns" {
    depends_on = ["digitalocean_droplet.host"]

    count = "${var.servers}"

    name = "${var.prefix}-${count.index + 1}.${var.domain}"
    ip_address = "${element(digitalocean_droplet.host.*.ipv4_address, count.index)}"
}


