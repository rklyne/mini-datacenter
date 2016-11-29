output "ip_addresses" {
    value = ["${digitalocean_droplet.host.*.ipv4_address}"]
}
output "id" {
    value = "${digitalocean_droplet.host.id}"
}
variable "domain" {}
variable "ssh_key_id" {}
variable "private_key" {}
variable "servers" {
    default = 3
}
variable "size" {
    default = "512mb"
}
variable "region" {
    default = "lon1"
}

data "template_file" "config" {
    template = "${file("${path.module}/consul.conf")}"

    vars {
        node_name = "consul-${count.index+1}"
        datacenter = "dc1"
    }
}

data "template_file" "debug_data" {
    template = "${v}"
    vars{v = "${var.domain}"}
}

resource "digitalocean_droplet" "host" {
    count = "${var.servers}"
    name = "consul-${count.index + 1}.${var.domain}"
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
            "yum install -y wget unzip",
            "wget https://releases.hashicorp.com/consul/0.7.1/consul_0.7.1_linux_amd64.zip",
            "unzip consul*.zip",
            "mv consul /usr/local/bin",
            "chmod +x /etc/init.d/consul",
            "useradd -m consul",
            "mkdir /etc/consul.d",
            "mkdir /opt/consul",
            "chown consul. /opt/consul",
        ]
    }

    provisioner "file" {
        destination = "/etc/consul.conf"
        content = "${data.template_file.config.rendered}"
    }

    provisioner "remote-exec" {
        inline = [
            "sed -i 's/99999/${var.servers}/g' /etc/consul.conf",
            "sed -i 's/consul-1/consul-${count.index+1}/g' /etc/consul.conf",
            "(hostname | grep -v \"consul-1\" > /dev/null) && sed -i 's/^.*bootstrap.*$//g' /etc/consul.conf",
            "echo '{\"advertise_addr\": \"${self.ipv4_address_private}\"}' > /etc/consul.d/private_address.json",
            "service consul start",
        ]
    }
}

resource "null_resource" "cluster_init" {
    depends_on = ["digitalocean_droplet.host"]

    connection {
        host = "${digitalocean_droplet.host.0.ipv4_address}"
        user = "root"
        type = "ssh"
        key_file = "${var.private_key}"
        timeout = "30s"
    }

    provisioner "remote-exec" {
        inline = [
            "/usr/local/bin/consul join ${join(" ", digitalocean_droplet.host.*.ipv4_address)}"
        ]
    }
}

resource "digitalocean_domain" "dns" {
    count = "${var.servers}"
    name = "consul-${count.index + 1}.${var.domain}"
    ip_address = "${element(digitalocean_droplet.host.*.ipv4_address, count.index)}"
}

