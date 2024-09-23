terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_security_group" "allow_http" {
  name        = "allow_http_traffic"
  description = "Allow HTTP traffic"

  # Reglas de entrada (Inbound rules)
  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Permite el tráfico desde cualquier IP
  }

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Permite el tráfico desde cualquier IP
  }

  # Reglas de salida (Outbound rules)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # -1 significa todo el tráfico
    cidr_blocks = ["0.0.0.0/0"]  # Permite el tráfico a cualquier IP
  }

  tags = {
    Name = "AllowHTTP"
  }
}

resource "aws_instance" "app_server" {
  ami           = "ami-0a0e5d9c7acc336f1"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.allow_http.id]
  key_name = "michael-key-pairs"
  associate_public_ip_address = true
  tags = {
    Name = "ExampleAppServerInstance"
  }
}
