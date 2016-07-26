variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "security_group" {default = "ose-sg"}
variable "keypair" {default = "id_rsa"}
variable "master_instance_type" {default = "c3.large"}
variable "node_instance_type" {default = "c3.large"}
variable "aws_region" {default = "us-east-1"}
variable "ebs_root_block_size" {default = "100"}
variable "aws_ami" {default = "ami-12663b7a"} # RHEL 7.1=ami-12663b7a, RHEL 7.2=ami-2051294a
variable "num_nodes" { default = "2" }

provider "aws" {
    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
    region     = "${var.aws_region}"
}

resource "aws_instance" "ose-master" {
    ami               = "${var.aws_ami}"
    instance_type     = "${var.master_instance_type}"
    subnet_id         = "${aws_subnet.public.id}"
    key_name          = "${var.keypair}"
    security_groups   = [ "${aws_security_group.ose-sg.id}" ] 
	
    root_block_device = {
		volume_type   = "gp2"
		volume_size   = "${var.ebs_root_block_size}"
	}
    connection {
        user = "ec2-user"
        key_file = "id_rsa"
    }
    provisioner "file" {
        source = "id_rsa"
        #key in pwd
        destination = "~/.ssh/id_rsa"
    }
    provisioner "remote-exec" {
      inline = [
        "sudo chmod 400 ~/.ssh/id_rsa",
        "sudo echo -e 'preserve_hostname: true' | sudo tee --append /etc/cloud/cloud.cfg > /dev/null",
        "sudo echo -e 'master.ose.cloudworks.io' | sudo tee /etc/hostname > /dev/null",
        "sudo echo -e 'HOSTNAME=master.ose.cloudworks.io' | sudo tee --append  /etc/sysconfig/network > /dev/null",
        # "sudo echo -e '${aws_instance.ose-master.public_ip} master.ose.cloudworks.io' | sudo tee --append /etc/hosts > /dev/null",
        "sudo sed 's/127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4/127.0.0.1 master.ose.cloudworks.io localhost.localdomain localhost4 localhost4.localdomain4/w output' /etc/hosts"
        ]
    } 

    tags {
        Name    = "master"
        sshUser = "ec2-user"
        role    = "masters"
    }
}

resource "aws_instance" "ose-node" {
    count             = "${var.num_nodes}"
    ami               = "${var.aws_ami}"
    instance_type     = "${var.node_instance_type}"
    subnet_id         = "${aws_subnet.public.id}"
    key_name          = "${var.keypair}"
    security_groups   = [ "${aws_security_group.ose-sg.id}" ]

	root_block_device = {
		volume_type   = "gp2"
		volume_size   = "${var.ebs_root_block_size}"
	}
    connection {
        user = "ec2-user"
        key_file = "id_rsa"
    }
    provisioner "file" {
        source = "id_rsa"
        #key in pwd
        destination = "~/.ssh/id_rsa"
    }
    provisioner "remote-exec" {
      inline = [
        "sudo chmod 400 ~/.ssh/id_rsa",
        "sudo echo -e 'preserve_hostname: true' | sudo tee --append /etc/cloud/cloud.cfg > /dev/null",
        "sudo echo -e 'node.${count.index}.ose.cloudworks.io' | sudo tee /etc/hostname > /dev/null",
        "sudo echo -e 'HOSTNAME=node.${count.index}.ose.cloudworks.io' | sudo tee --append  /etc/sysconfig/network > /dev/null",
        # "sudo echo -e '${self.public_ip} node.${count.index}.ose.cloudworks.io' | sudo tee --append /etc/hosts > /dev/null",
        "sudo sed 's/127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4/127.0.0.1 node.${count.index}.ose.cloudworks.io localhost.localdomain localhost4 localhost4.localdomain4/w output' /etc/hosts"
        ]
    }

    tags {
        Name    = "${concat("node", count.index)}"
        sshUser = "ec2-user"
        role    = "nodes"
    }
}
