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
variable "region" {
    default = "lon1"
}

variable "consul_ipv4_addresses" {
    type = "list"
}
variable "puppetmaster" {
}
variable "datacenter" {
}

output "ip_addresses" {
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
        puppetmaster = "${var.puppetmaster}"
        datacenter = "${var.datacenter}"
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
            "yum install -y puppet-agent",
            "/opt/puppetlabs/bin/puppet resource package puppet ensure=latest",
            "chkconfig puppet on",
            "echo -e '[main]\nserver = puppetmaster.service.${var.datacenter}.consul\nruninterval = 30s' >> /etc/puppetlabs/puppet/puppet.conf",
            "/opt/puppetlabs/bin/puppet agent --test",
            "( D='/tmp/${uuid()}' && mkdir $D && cd $D && cp /tmp/*.sh . )",
        ]
    }
}

resource "null_resource" "sign_cert_on_master" {
    depends_on = ["null_resource.server_config"]

    count = "${var.servers}"
    triggers = {
        hosts = "${var.puppetmaster}"
    }

    connection {
        host = "${var.puppetmaster}"
        user = "root"
        type = "ssh"
        private_key = "${var.private_key}"
        timeout = "30s"
    }


    provisioner "remote-exec" {
        inline = [
            "puppet cert sign ${element(module.consul-base.hostnames, count.index)}",
            "( D='/tmp/${uuid()}' && mkdir $D && cd $D && cp /tmp/*.sh . )",
        ]
    }
}

resource "null_resource" "fetch_signed_cert_and_start" {
    depends_on = ["null_resource.sign_cert_on_master"]

    count = "${var.servers}"
    triggers = {
        hosts = "${var.puppetmaster}"
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
            "/opt/puppetlabs/bin/puppet resource service puppet ensure=running enable=true",
            "puppet agent --test",
            "service puppet restart",
            "( D='/tmp/${uuid()}' && mkdir $D && cd $D && cp /tmp/*.sh . )",
        ]
    }
}

