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


data "template_file" "debug_data" {
    template = "${v}"
    vars{v = "${var.domain}"}
}

module "consul-base" {
    source = "../base"
    servers = "${var.servers}",
    prefix = "redis"
    domain = "${var.domain}"
}

resource "null_resource" "redis_install" {
    count = "${var.servers}"

    connection {
        host = "${element(module.consul-base.ip_addresses, count.index)}"
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
            "yum update -y",
            "yum install -y wget unzip",
            "rpm -Uvh http://download.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm",
            "rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-6.rpm",
            "yum --enablerepo=remi,remi-test install redis",
            "echo 'never' > /sys/kernel/mm/redhat_transparent_hugepage/enabled", 
            "echo \"vm.overcommit_memory=1\" >> /etc/sysctl.conf",
            "sysctl vm.overcommit_memory=1",
            "echo \"net.core.somaxconn=65535\" >> /etc/sysctl.conf",
            "sysctl net.core.somaxconn=65535",
            "sysctl -w fs.file-max=100000",
            "chkconfig --add redis",
            "chkconfig --level 345 redis on",
            "service redis start",
        ]
    }
}

