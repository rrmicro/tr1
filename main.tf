terraform {
  required_version = ">= 0.11"
}
provider "aws" {
	region = "us-east-2"
}
resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
        public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDXFLlm0W2/Sm1TFN5WjJKyjUvkjowqLo0QBkMJX5KQioFRRrs5EEm+b7vBDXiCIL26UV/gTsctmWXXmIImWWbakNd26mmHdOmR2j3+SWGfBGAoiBHYMzfIfoCcqzCxZMi3zttte2FHHyLywMXdUuwkRZugjomM9FVojIOXBu8zo+ix9Zww/d2enmvy2KfB+TiaQ0xpiwb/fc4BiE088piF4ZzKBzvrR4i2u/xsFphBk3UuJXrH0h77vU7B2wjPHYm5UHHzjIVGqKMK6+vi3o1WB6Yv25jxcG+aYrgm+kCUKR/egsifITjOw6N0VcTCRYC4GS383D0qH9exu9nN2u/P ramyUSC@Rams-Mac-mini.local"
}

variable "server_port" {
	description = "the port the server will use for HTTP requests"
	default = 8080
}

resource "aws_instance" "example"
{
	ami	= "ami-15e9c770"
 # took the first default ami that aws pops up in the console when starting to create an instance manually

	instance_type = "t2.micro"

	key_name = "deployer-key"
 # this is the key pair and refers to the public key that needs to be attached to the instance at creation. 

	vpc_security_group_ids = ["${aws_security_group.instance.id}"]
	user_data = <<-EOF
		#!/bin/bash
		sudo yum update -y
 # updates the box with all patches

		sudo yum install busybox -y
 #busybox needs to be installed - it does not come pre-installed in this ami

		./busybox # start busybox

		echo "Hello, World" > index.html
 # the single page that will be served by the busybox web server

		nohup busybox httpd -f -p "${var.server_port}" &
 # starting the web server on a port other than por 80 and picking up the variable declared earlier using interpolation syntax
		EOF

tags {
    Name = "terra-1ex1"
  }
}

resource "aws_security_group" "instance" {
	name = "terra-1ex1"
	ingress {
		from_port = "${var.server_port}"
		to_port	= "${var.server_port}"
		protocol = "tcp"
		cidr_blocks = ["0.0.0.0/0"]
	}
	ingress {
		from_port = 22
		to_port = 22
		protocol = "tcp"
		cidr_blocks = ["76.184.239.30/32"]
	}
	egress {
		from_port = 0 # the from and to ports need to be 0 to use -1 as protocol ie allow all
		to_port = 0
		protocol = -1
		cidr_blocks = ["0.0.0.0/0"]
}
}

output "public_ip" {
	value = "${aws_instance.example.public_ip}"
}
