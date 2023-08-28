terraform {
  backend "s3" {
    bucket     = "arshad-bucket"
    key        = "key/terraform.tfstate"
    region     = "ap-south-1" # Mumbai Region
    profile    = "default"
    shared_credentials_file = "/c/Users/ArshX1/.aws/credentials"
  }
}

provider "aws" {
  region     = "ap-south-1"
  #shared_credentials_file = "/c/Users/ArshX1/.aws/credentials"
  #profile = "default"
}

resource "tls_private_key" "rsa" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "MYTF-key" {
  content  = tls_private_key.rsa.private_key_pem
  filename = "mytfkey"
}

resource "aws_key_pair" "MYTF_key" {
  key_name   = "MYTF_key"
  public_key = tls_private_key.rsa.public_key_openssh
}

resource "aws_security_group" "aws_sg" {
  name_prefix = "aws-sg-"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "aws_jen_instance" {
  ami                    = "ami-0f5ee92e2d63afc18" # Replace with desired AMI ID
  instance_type          = "t2.micro"
  key_name               = aws_key_pair.MYTF_key.key_name
  vpc_security_group_ids = [aws_security_group.aws_sg.id]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = tls_private_key.rsa.private_key_pem
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = tls_private_key.rsa.private_key_pem
      host        = self.public_ip
    }

    inline = [
      "sudo apt-get update",
      "sudo apt update",
      "sudo apt install -y openjdk-17-jre",
      "java -version",
      "curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null",
      "echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | sudo tee /etc/apt/sources.list.d/jenkins.list > /dev/null",
      "sudo apt-get update",
      "sudo apt-get install -y jenkins"
    ]
  }

  tags = {
    Name = "JenkinsOnAws"
  }
}
output "instance_ip" {
  value = aws_instance.aws_jen_instance.public_ip
}
