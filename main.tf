#-------------------------------------------------
# Creating a Web Server with Zero
# DownTime and Green / Blue Deployment,
# Using Terraform.
# Create:
#    - Security Group for Web Server
#    - Launch Configuration with Auto AMI Lookup
#    - Auto Scaling Group using 2 availability Zones
#    - Classic Load Balancer in 2 availability Zones
# Made by Vova Verholyak
#-------------------------------------------------
provider "aws" {
  region = "eu-central-1"
}
data "aws_availability_zones" "available" {}
data "aws_ami" "latest_amazon_linux" {
  owners      = ["amazon"] //  go to AWS instance, AMIs
  most_recent = true
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

//  Security Group for Web Server
resource "aws_security_group" "web" {
  name = "Dynamic Security Group"
  dynamic "ingress" {
    for_each = ["80", "443"] //  cycle
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name  = "Dynamic SecurityGroup"
    Owner = "Vova Verholyak"
  }
}

//  Launch Configuration with Auto AMI Lookup
resource "aws_launch_configuration" "web" {
  //  name = "WebServer-Highly-Available-LC"         //  Static name
  name_prefix     = "WebServer-Highly-Available-LC-" //  Dynamic name
  image_id        = data.aws_ami.latest_amazon_linux.id
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.web.id]
  user_data       = file("user-data.sh")
  lifecycle {
    create_before_destroy = true
  }
}

// Auto Scaling Group using 2 availability Zones
resource "aws_autoscaling_group" "web" {
  //  name             = "WebServer-Highly-Available-ASG"           //  Static name
  name_prefix          = "ASG-${aws_launch_configuration.web.name}" //  Dynamic name
  launch_configuration = aws_launch_configuration.web.name
  min_size             = 2
  max_size             = 2
  min_elb_capacity     = 2
  health_check_type    = "ELB"
  vpc_zone_identifier  = [aws_default_subnet.default_az1.id, aws_default_subnet.default_az2.id]
  load_balancers       = [aws_elb.web.name]
  //  Dynamic tag
  dynamic "tag" {
    for_each = {
      Name   = "WebServer in ASG"
      Owner  = "Vova Verholyak"
      TAGKEY = "TAGVALUE"
    }
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
  lifecycle {
    create_before_destroy = true
  }
}

//  Classic Load Balancer in 2 availability Zones
resource "aws_elb" "web" {
  name               = "WebServer-HA-ELB"
  availability_zones = [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]
  security_groups    = [aws_security_group.web.id]
  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = 80
    instance_protocol = "http"
  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 10
  }
  tags = {
    Name = "WebServer-Highly-Available-ELB"
  }
}
//  Subnet id
resource "aws_default_subnet" "default_az1" {
  availability_zone = data.aws_availability_zones.available.names[0]
}
resource "aws_default_subnet" "default_az2" {
  availability_zone = data.aws_availability_zones.available.names[1]
}
//  Output Web URL
output "web_loadbalancer_url" {
  value = aws_elb.web.dns_name
}
