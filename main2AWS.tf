variable "access_key1"  {}
variable "secret_key1"  {}
variable "region1"  {}
variable "subnet" {}

provider "aws" {
  region     = var.region1
  access_key = var.access_key1
  secret_key = var.secret_key1
}

 # 1. Create vpc
 resource "aws_vpc" "prod-vpc" {
   cidr_block = "10.0.0.0/16"
   tags = {
     Name = "production"
   }
 }

# 2.creating 2 subnets 10.0.3.0/24 & 10.0.4.0/24
resource  "aws_subnet" "subnet-1" {
   vpc_id            = aws_vpc.prod-vpc.id
   cidr_block        = var.subnet[0].cidr_block
   availability_zone = "us-east-1a"

   tags = {
     Name = var.subnet[0].name
   }
 }

 resource  "aws_subnet" "subnet-2"{
   vpc_id            = aws_vpc.prod-vpc.id
   cidr_block        = var.subnet[1].cidr_block
   availability_zone = "us-east-1a"

   tags = {
     Name = var.subnet[1].name
   }
 }
 

# 3. Create Internet Gateway

 resource "aws_internet_gateway" "gw" {
   vpc_id = aws_vpc.prod-vpc.id
 }

# 4. Create Custom Route Table

 resource "aws_route_table" "prod-route-table" {
   vpc_id = aws_vpc.prod-vpc.id

   route {
     cidr_block = "0.0.0.0/0"
     gateway_id = aws_internet_gateway.gw.id
   }

   route {
     ipv6_cidr_block = "::/0"
     gateway_id      = aws_internet_gateway.gw.id
   }

   tags = {
     Name = "Prod"
   }
 }

# 5. Associate subnet with Route Table
 resource "aws_route_table_association" "a" {
   subnet_id      = aws_subnet.subnet-1.id
   route_table_id = aws_route_table.prod-route-table.id
 }




# 6. Create Security Group to allow port 22,80,443
 resource "aws_security_group" "allow_web" {
   name        = "allow_web_traffic"
   description = "Allow Web inbound traffic"
   vpc_id      = aws_vpc.prod-vpc.id

   ingress {
     description = "HTTPS"
     from_port   = 443
     to_port     = 443
     protocol    = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
   }
   ingress {
     description = "HTTP"
     from_port   = 80
     to_port     = 80
     protocol    = "tcp"
     cidr_blocks = ["0.0.0.0/0"]
   }
   ingress {
     description = "SSH"
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
     Name = "allow_web"
   }
 }


# 7. Create a network interface with an ip in the subnet1

 resource "aws_network_interface" "web-server-nic" {
   subnet_id       = aws_subnet.subnet-1.id
   private_ips     = ["10.0.3.50"]
   security_groups = [aws_security_group.allow_web.id]
 }


# 8. Assign an elastic IP to the network interface created in step 7
 resource "aws_eip" "EIP" {
   vpc                       = true
   network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.3.50"
   depends_on                = [aws_internet_gateway.gw]
 }


 
output "server_public_ip" {
  value = aws_eip.EIP.public_ip
}

# 9. Create Ubuntu server and install/enable apache2

 resource "aws_instance" "web-server-instance" {
   ami               = "ami-085925f297f89fce1"
   instance_type     = "t2.micro"
   availability_zone = "us-east-1a"
   key_name          = "main-key"
    #subnet_id           = aws_subnet.subnet-1.id
    #vpc_security_group_ids      = [aws_security_group.allow_web.id]
    #aws_eip =   aws_eip.example.id
    #allocation_id = aws_eip.example.id

   network_interface {
     device_index         = 0
     network_interface_id = aws_network_interface.web-server-nic.id
   }


   user_data = <<-EOF
                 #!/bin/bash
                 sudo apt update -y
                 sudo apt install apache2 -y
                 sudo systemctl start apache2
                 sudo bash -c 'echo hello this is my terraform project > /var/www/html/index.html'
                 EOF
   tags = {
     Name = "web-server"
   }
 }
