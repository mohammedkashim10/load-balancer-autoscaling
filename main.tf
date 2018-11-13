provider "aws" {
  region = "eu-west-1"
}

resource "aws_instance" "app_kashim" {
  ami           = "${var.app_ami_id}"
  instance_type = "t2.micro"
  subnet_id     = "${aws_subnet.kashim_subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.kashim_security_group.id}"]
  user_data = "${data.template_file.app_init.rendered}"
  key_name = "DevOpsStudents"

  tags {
    Name = "${var.appname}"
  }
}

resource "aws_instance" "db_kashim" {
  ami           = "${var.db_ami_id}"
  instance_type = "t2.micro"
  subnet_id     = "${aws_subnet.kashim-private.id}"
  vpc_security_group_ids = ["${aws_security_group.kashim_security_group.id}"]

  tags {
    Name = "${var.dbname}"
  }
}

resource "aws_subnet" "kashim_subnet" {
  vpc_id     = "${var.vpc_id}"
  cidr_block = "10.0.3.0/24"
  map_public_ip_on_launch = true

  tags {
    Name = "${var.appname}"
  }
}

resource "aws_subnet" "kashim-private" {
  vpc_id     = "${var.vpc_id}"
  cidr_block = "10.0.17.0/24"
  map_public_ip_on_launch = true

  tags {
    Name = "${var.dbname}"
  }
}

resource "aws_security_group" "kashim_security_group" {
  name        = "kashim-security-group"
  description = "Allow inbound traffic from anywhere on port 80"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port   = "80"
    to_port     = "80"
    protocol    = "6"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "6"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.appname}"
  }
}

resource "aws_security_group" "kashim-db" {
  name        = "kashim-db"
  description = "Allow inbound traffic from app on port 27017 (mongodb)"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port   = "27017"
    to_port     = "27017"
    protocol    = "6"
    cidr_blocks = ["10.0.3.0/24"]
  }

  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.dbname}"
  }
}

resource "aws_route_table" "kashim_route_table" {
  vpc_id = "${var.vpc_id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${data.aws_internet_gateway.default.id}"
  }

  tags {
    Name = "${var.appname}-public_route_table"
  }
}

resource "aws_route_table_association" "assoc" {
  subnet_id = "${aws_subnet.kashim_subnet.id}"
  route_table_id = "${aws_route_table.kashim_route_table.id}"
}

resource "aws_route_table_association" "assoc_priv" {
  subnet_id = "${aws_subnet.kashim-private.id}"
  route_table_id = "${aws_route_table.kashim_route_table.id}"
}

data "aws_internet_gateway" "default" {
  filter {
    name = "attachment.vpc-id"
    values = ["${var.vpc_id}"]
  }
}

data "template_file" "app_init" {
  template = "${file("./scripts/app/init.sh.tpl")}"
  vars {
    db_host="mongodb://${aws_instance.db_kashim.private_ip}:27017/posts"
  }
}

resource "aws_lb" "kashim_lb" {
  name               = "kashim-test-lb-tf"
  internal           = false
  load_balancer_type = "network"
  subnets            = ["subnet-0080335588841a3cd"]

  enable_deletion_protection = false

  tags {
    Environment = "production"
  }
}

resource "aws_launch_configuration" "kashim_config" {
  name          = "kashim-config"
  image_id      = "ami-055c1755b888344f7"
  instance_type = "t2.micro"
  user_data = "${data.template_file.app_init.rendered}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "kashim_group" {
  name                 = "kashim-autogroup"
  availability_zones   = ["eu-west-1a"]
  vpc_zone_identifier  = ["${aws_subnet.kashim_subnet.id}"]
  launch_configuration = "${aws_launch_configuration.kashim_config.name}"
  min_size             = 1
  max_size             = 2

  tags {
    key = "Name"
    value = "kashim"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}
