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

resource "aws_launch_configuration" "example"
{
	image_id	= "ami-15e9c770"
 # took the first default ami that aws pops up in the console when starting to create an instance manually

	instance_type = "t2.micro"

	key_name = "deployer-key"
 # this is the key pair and refers to the public key that needs to be attached to the instance at creation.

	security_groups = ["${aws_security_group.instance.id}"]
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

lifecycle {
  create_before_destroy = true
  #creates a new launch config resource before destroying the old one
}
#tags {
#    Name = "terra-launch"
#  }
}

resource "aws_security_group" "instance" {
	name = "terra-2ex1"
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
		cidr_blocks = ["0.0.0.0/0"]
	}
	egress {
		from_port = 0 # the from and to ports need to be 0 to use -1 as protocol ie allow all
		to_port = 0
		protocol = -1
		cidr_blocks = ["0.0.0.0/0"]
}
lifecycle {
  create_before_destroy = true
  #creates a new security group before destroying the old one
}
}

data "aws_availability_zones" "all" {}
#data source that is used to query the availability zones

resource "aws_autoscaling_group" "example" {
  launch_configuration = "${aws_launch_configuration.example.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  #uses the availability zones from the data source

load_balancers =
["${aws_elb.example.name}"]
health_check_type = "ELB"
#the above registers each instance in the ASG to register with the ELB

    min_size = 2
    max_size = 10
#number of instances that is minimum and maximum

    tag {
      key = "Name"
      value = "terraform-asg-example"
        propagate_at_launch = true
    }
}

resource "aws_elb" "example" {
  name = "terraform-asg-example"
  availability_zones = ["${data.aws_availability_zones.all.names}"]

  security_groups = ["${aws_security_group.elb.id}"]
  #uses the security group for the elb that is written further down

  listener {
    #the listener of the elb forwards requests from 80 to 8080 or any configured port
    lb_port = 80
    lb_protocol = "http"
    instance_port = "${var.server_port}"
    instance_protocol = "http"
  }

  health_check {
    #checks is instances are healthy
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    target = "HTTP:${var.server_port}/"
    interval = 30
  }
}

resource "aws_security_group" "elb" {
  name = "terraform-example-elb"
#this is the security group that is exclusive to the elb
  ingress {
    #it accepts requests on port 80
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

    }
    egress {
      #egress is configured for the health checks to work
      from_port = 0
      to_port = 0
      protocol = "-1"
      cidr_blocks = ["0.0.0.0/0"]
  }
}


output "elb_dns_name" {
	value = "${aws_elb.example.dns_name}"
  #provides the output which is the dns name of the elb
}
