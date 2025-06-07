terraform {
  backend "s3" {
    bucket         = "cadd-project"
    key            = "terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "eu-west-2" # Change this to your preferred region
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "main-vpc"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "main-route-table"
  }
}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-west-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "main-subnet"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "sg" {
  name        = "allow-ssh & HTTP"
  description = "Allow SSH & web traffic inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
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
    Name = "main-sg"
  }
}

resource "aws_instance" "web" {
  ami           = "ami-0bc8d5c547360e648" # replace with the Amazon Linux AMI value on your account
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.sg.id]
  user_data = base64encode(<<-EOF
              #!/bin/bash
              # Update the instance and install necessary packages
              yum update -y
              yum install -y httpd wget unzip
              
              # Start Apache and enable it to start on boot
              systemctl start httpd
              systemctl enable httpd
              
              # Navigate to the web root directory
              cd /var/www/html
              
              # Download a CSS template directly
              wget https://www.free-css.com/assets/files/free-css-templates/download/page284/built-better.zip
              
              # Unzip the template and move the files to the web root
              unzip built-better.zip -d /var/www/html/
              mv /var/www/html/html/* /var/www/html/
              
              # Clean up unnecessary files
              rm -r /var/www/html/html
              rm built-better.zip
              
              # Restart Apache to apply changes
              systemctl restart httpd
              EOF
  )

  tags = {
    Name = "main-instance"
  }
}