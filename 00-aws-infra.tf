provider "aws" {
  region = "${var.aws_region}"
}

resource "aws_vpc" "main" {
  cidr_block           = "172.31.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_internet_gateway" "main" {
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_route_table" "main" {
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_route" "main" {
  route_table_id         = "${aws_vpc.main.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.main.id}"
}

resource "aws_subnet" "subnet1" {
  vpc_id                  = "${aws_vpc.main.id}"
  cidr_block              = "172.31.16.0/20"
  availability_zone       = "A"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet2" {
  vpc_id                  = "${aws_vpc.main.id}"
  cidr_block              = "172.31.32.0/20"
  availability_zone       = "B"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet3" {
  vpc_id                  = "${aws_vpc.main.id}"
  cidr_block              = "172.31.0.0/20"
  availability_zone       = "C"
  map_public_ip_on_launch = true
}

resource "aws_route_table_association" "subnet1" {
  subnet_id      = "${aws_subnet.subnet1.id}"
  route_table_id = "${aws_route_table.main.id}"
}

resource "aws_route_table_association" "subnet2" {
  subnet_id      = "${aws_subnet.subnet2.id}"
  route_table_id = "${aws_route_table.main.id}"
}

resource "aws_route_table_association" "subnet3" {
  subnet_id      = "${aws_subnet.subnet3.id}"
  route_table_id = "${aws_route_table.main.id}"
}

resource "aws_vpc_dhcp_options" "main" {
  domain_name = "ec2.internal"

  domain_name_servers = [
    "AmazonProvidedDNS",
  ]
}

resource "aws_vpc_dhcp_options_association" "main" {
  vpc_id          = "${aws_vpc.main.id}"
  dhcp_options_id = "${aws_vpc_dhcp_options.main.id}"
}

resource "aws_security_group" "main" {
  name        = "docker_swarm_sg"
  description = "Security Group for Docker Swarm by Terraform"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  ingress {
    description = "HTTP access from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  ingress {
    description = "HTTPS access from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    self        = true

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }

  ingress {
    description = "allow internal communication for docker swarm"
    from_port   = 2377
    to_port     = 2377
    protocol    = "tcp"
    self        = true
  }

  ingress {
    description = "allow internal communication for docker swarm"
    from_port   = 7946
    to_port     = 7946
    self        = true
    protocol    = "tcp"
  }

  ingress {
    description = "allow internal communication for docker swarm"
    from_port   = 7946
    to_port     = 7946
    protocol    = "udp"
    self        = true
  }

  ingress {
    description = "allow internal communication for docker swarm"
    from_port   = 4789
    to_port     = 4789
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "Allow all outgoing traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"

    cidr_blocks = [
      "0.0.0.0/0",
    ]
  }
}

##Find latest Ubuntu 16.04 AMI
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name = "name"

    values = [
      "ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*",
    ]
  }

  filter {
    name = "virtualization-type"

    values = [
      "hvm",
    ]
  }

  # Canonical
  owners = [
    "amazon",
  ]
}

resource "aws_instance" "swarm_master" {
  count = 1

  connection {
    user = "${var.ssh_user}"
  }

  depends_on = [
    "aws_security_group.main",
    "aws_internet_gateway.main",
  ]

  instance_type               = "${var.aws_instance_size}"
  associate_public_ip_address = true

  ami      = "${data.aws_ami.ubuntu.id}"
  key_name = "${var.aws_key_name}"

  vpc_security_group_ids = [
    "${aws_security_group.main.id}",
  ]

  tags {
    Name     = "tf-docker-swarm"
    Duration = -1
  }
}

output "instance_ips" {
  value = [
    "${aws_instance.swarm_master.*.public_ip}",
  ]
}
