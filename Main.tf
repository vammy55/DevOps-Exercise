provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "ec2-server" {
  ami           = "ami-0323c3dd2da7fb37d"
  subnet_id = "${aws_subnet.devops-subnet.id}"
  vpc_security_group_ids = ["${aws_security_group.allow_http_ssh.id}"]
  instance_type = "t2.micro"
  key_name      = "${aws_key_pair.generated_key.key_name}"
  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = "${tls_private_key.example.private_key_pem}"
    host     = self.public_ip
    agent       = false
    timeout     = "30s"
  }
  provisioner "remote-exec" {
    inline = [
      //"sudo yum update -y",
      "sudo yum install httpd -y",
      "sudo systemctl start httpd",
      "echo hello from ${aws_instance.ec2-server.public_ip} | sudo tee /var/www/html/index.html"   
    ]
  }
  tags = {
    Name = "devops-Ec2"
  }
  
}

resource "aws_vpc" "devops-vpc" {
  cidr_block       = "10.0.0.0/16"

  tags = {
    Name = "devops-vpc"
  }
}

resource "aws_subnet" "devops-subnet" {
  vpc_id     = "${aws_vpc.devops-vpc.id}"
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = {
    Name = "devops-subnet"
  }
}

resource "aws_security_group" "allow_http_ssh" {
  name        = "allow_http_ssh"
  description = "Allow http,ssh inbound traffic"
  vpc_id      = "${aws_vpc.devops-vpc.id}"

  ingress {
    description = "Http from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ssh from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
   egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Allow http,ssh inbound traffic"
  }
}

resource "tls_private_key" "example" {
  algorithm   = "RSA"
  rsa_bits  = 4096
}
variable "key_name" {}
resource "aws_key_pair" "generated_key" {
  key_name   = "${var.key_name}"
  public_key = "${tls_private_key.example.public_key_openssh}"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.devops-vpc.id}"
  tags = {
    Name = "main"
  }
}
resource "aws_route_table" "r" {
  vpc_id = "${aws_vpc.devops-vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gw.id}"
  }
  tags = {
    Name = "main"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.devops-subnet.id
  route_table_id = aws_route_table.r.id
}



