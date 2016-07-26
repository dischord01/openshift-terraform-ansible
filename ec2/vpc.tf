#----------------------------------------------
# VPC
#----------------------------------------------
# Main VPC that will contain everything.
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
 
  tags { 
  	Name = "ose-vpc" 
  }
}

# The public subnet is where resources connected to the internet will go
resource "aws_subnet" "public" {
    vpc_id                  = "${aws_vpc.main.id}"
    cidr_block              = "10.0.2.0/24"
    map_public_ip_on_launch = true
    tags { Name = "ose-public-subnet" }
}

# Internet accessible route table + gateway for the public subnet
resource "aws_internet_gateway" "public" {
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.main.id}"
  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = "${aws_internet_gateway.public.id}"
  }
  tags { Name = "ose-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = "${aws_subnet.public.id}"
  route_table_id = "${aws_route_table.public.id}"
}

#----------------------------------------------
# Security Group
#----------------------------------------------
resource "aws_security_group" "ose-sg" {
  name   = "ose-sg"
  vpc_id = "${aws_vpc.main.id}"

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["10.0.0.0/16"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# TCP/22 - ssh
# TCP/80 - Web Apps
# TCP/443 - Web Apps (https)
# UDP/4789 - SDN / VXLAN
# TCP/8443 - Openshift Console
# TCP/10250 - kubelet

#----------------------------------------------
# DNS
#----------------------------------------------
resource "aws_route53_record" "master" {
  zone_id = "Z17WRPJRU4K2P"
  name = "master.ose.cloudworks.io"
  type = "A"
  ttl = "300"
  records = ["${aws_instance.ose-master.public_ip}"]
}

resource "aws_route53_record" "nodes" {
  # same number of records as instances
  count = "${var.num_nodes}"
  zone_id = "Z17WRPJRU4K2P"                       
  name = "node.${count.index}.ose.cloudworks.io"
  type = "A"
  ttl = "300"
  # matches up record N to instance N
  records = ["${element(aws_instance.ose-node.*.public_ip, count.index)}"]
}

resource "aws_route53_record" "wildcard" {
  zone_id = "Z17WRPJRU4K2P"
  type = "A"
  ttl = "300"
  name = "*.apps.ose.cloudworks.io"
  records = ["${aws_instance.ose-master.public_ip}"]
}

#zone_id = "${aws_route53_zone.cloudworks.zone_id}"






