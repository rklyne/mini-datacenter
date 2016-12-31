variable "servers" {
    default = 3
}
variable "domain" {}
variable "prefix" {}
variable "ssh_key_id" {}
variable "private_key" {}
variable "size" {
    default = "512mb"
}
variable "service_name" {
    default = "puppetmaster"
}

variable "region" {
    default = "lon1"
}

variable "consul_ipv4_addresses" {
    type = "list"
}

output "hostnames" {
    depends_on = ["null_resource.server_config"]
    value = ["${module.consul-base.hostnames}"]
}

output "ip_addresses" {
    depends_on = ["null_resource.server_config"]
    value = ["${module.consul-base.ip_addresses}"]
}

module "consul-base" {
    servers = "${var.servers}"
    source = "../base"
    prefix = "${var.prefix}"
    domain = "${var.domain}"
    ssh_key_id = "${var.ssh_key_id}"
    private_key = "${var.private_key}"
    size = "${var.size}"
    region = "${var.region}"
    consul_ipv4_addresses = ["${var.consul_ipv4_addresses}"]
}

resource "null_resource" "server_config" {
    depends_on = ["module.consul-base"]

    count = "${var.servers}"
    triggers = {
        hosts = "${element(module.consul-base.ip_addresses, count.index)}"
    }

    connection {
        host = "${element(module.consul-base.ip_addresses, count.index)}"
        user = "root"
        type = "ssh"
        private_key = "${var.private_key}"
        timeout = "30s"
    }

    provisioner "remote-exec" {
        inline = [
            "rpm -Uvh https://yum.puppetlabs.com/puppetlabs-release-pc1-el-6.noarch.rpm",
            "yum install -y puppetserver puppet",
            "sed -i 's/2g/300m/g' /etc/sysconfig/puppetserver",
            "echo -e '\n[main]\ndns_alt_names = ${var.service_name}.service.dc1.consul' >> /etc/puppetlabs/puppet/puppet.conf",
            "echo -e '{\"service\": {\"name\": \"${var.service_name}\", \"tags\": [\"master\"]}}' > /etc/consul.d/service-puppetmaster.json",
            "consul reload",
            "chkconfig puppetserver on",
            "/opt/puppetlabs/bin/puppet cert list",
        ]
    }

    provisioner "file" {
        source = "${path.module}/manifests/"
        destination = "/etc/puppetlabs/code/environments/production/manifests/"
    }

    provisioner "file" {
        source = "${path.module}/modules/"
        destination = "/etc/puppetlabs/code/environments/production/modules/"
    }

    provisioner "remote-exec" {
        inline = [
            "service puppetserver restart",
        ]
    }
}

