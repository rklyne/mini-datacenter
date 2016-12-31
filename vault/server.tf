variable "domain" {}
variable "ssh_key_id" {}
variable "private_key" {}
variable "size" {
    default = "512mb"
}
variable "region" {
    default = "lon1"
}
variable "servers" {
    default = 1
}
variable "prefix" {
    default = "vault"
}

variable "consul_ipv4_addresses" {
    type = "list"
    default = []
}
variable "key_shares" {
    default = 5
}
variable "key_threshold" {
    default = 2
}

module "hosts" {
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

resource "null_resource" "vault_install" {
    triggers = {
        host_ips = "${join(",", module.hosts.ip_addresses)}"
    }
    count = "${var.servers}"

    connection {
        host = "${element(module.hosts.ip_addresses, count.index)}"
        user = "root"
        type = "ssh"
        private_key = "${var.private_key}"
        timeout = "30s"
    }

    provisioner "file" {
        source = "${path.module}/service.sh"
        destination = "/etc/init.d/vault"
    }

    provisioner "remote-exec" {
        inline = [
            "wget https://releases.hashicorp.com/vault/0.6.2/vault_0.6.2_linux_amd64.zip",
            "unzip vault_*.zip",
            "mv vault /usr/local/sbin/",
            "chmod +x /etc/init.d/vault",
            "mkdir -p /etc/vault.d",
            "consul join ${join(" ", var.consul_ipv4_addresses)}",
            ]
    }

    provisioner "file" {
        source = "${path.module}/server.hcl"
        destination = "/etc/vault.d/server.hcl"
    }

    provisioner "remote-exec" {
        inline = [
            "service vault start",
            "echo 'export VAULT_ADDR=\"http://127.0.0.1:8200/\"' > vault-addr.sh",
            ". ./vault-addr.sh",
            "vault init -key-shares=${var.key_shares} -key-threshold=${var.key_threshold} | tee -a vault-init",
            "for k in `cat vault-init  | grep \"Unseal Key\" | awk -F: '{print $2}'`; do vault unseal $k; done",
            "cp vault-init vault-keys-`uuidgen`",
            "cat vault-init  | grep \"Root Token\" | awk -F: '{print $2}' | xargs vault auth",
            ]
    }
}


