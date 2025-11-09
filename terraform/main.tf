
# =============================
# Auto-generate SSH Key Pairs
# =============================
resource "tls_private_key" "primary_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "primary_key" {
  key_name   = "autoheal-key-primary"
  public_key = tls_private_key.primary_key.public_key_openssh
}

resource "tls_private_key" "secondary_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "secondary_key" {
  provider   = aws.secondary
  key_name   = "autoheal-key-secondary"
  public_key = tls_private_key.secondary_key.public_key_openssh
}

# =============================
# Primary Network
# =============================
resource "aws_vpc" "primary_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "primary-vpc" }
}

resource "aws_subnet" "primary_subnet_a" {
  vpc_id                  = aws_vpc.primary_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.region_primary}a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "primary_subnet_b" {
  vpc_id                  = aws_vpc.primary_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.region_primary}b"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "primary_igw" {
  vpc_id = aws_vpc.primary_vpc.id
  tags = { Name = "primary-igw" }
}

resource "aws_route_table" "primary_rt" {
  vpc_id = aws_vpc.primary_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.primary_igw.id
  }

  tags = { Name = "primary-rt" }
}

resource "aws_route_table_association" "primary_assoc_a" {
  subnet_id      = aws_subnet.primary_subnet_a.id
  route_table_id = aws_route_table.primary_rt.id
}

resource "aws_route_table_association" "primary_assoc_b" {
  subnet_id      = aws_subnet.primary_subnet_b.id
  route_table_id = aws_route_table.primary_rt.id
}

# =============================
# Secondary Network
# =============================
resource "aws_vpc" "secondary_vpc" {
  provider   = aws.secondary
  cidr_block = "10.1.0.0/16"
  tags = { Name = "secondary-vpc" }
}

resource "aws_subnet" "secondary_subnet_a" {
  provider                = aws.secondary
  vpc_id                  = aws_vpc.secondary_vpc.id
  cidr_block              = "10.1.1.0/24"
  availability_zone       = "${var.region_secondary}a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "secondary_subnet_b" {
  provider                = aws.secondary
  vpc_id                  = aws_vpc.secondary_vpc.id
  cidr_block              = "10.1.2.0/24"
  availability_zone       = "${var.region_secondary}b"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "secondary_igw" {
  provider = aws.secondary
  vpc_id   = aws_vpc.secondary_vpc.id
  tags = { Name = "secondary-igw" }
}

resource "aws_route_table" "secondary_rt" {
  provider = aws.secondary
  vpc_id   = aws_vpc.secondary_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.secondary_igw.id
  }

  tags = { Name = "secondary-rt" }
}

resource "aws_route_table_association" "secondary_assoc_a" {
  provider       = aws.secondary
  subnet_id      = aws_subnet.secondary_subnet_a.id
  route_table_id = aws_route_table.secondary_rt.id
}

resource "aws_route_table_association" "secondary_assoc_b" {
  provider       = aws.secondary
  subnet_id      = aws_subnet.secondary_subnet_b.id
  route_table_id = aws_route_table.secondary_rt.id
}

# =============================
# Security Groups
# =============================
resource "aws_security_group" "primary_sg" {
  name        = "autoheal-sg-primary"
  description = "Allow HTTP and SSH"
  vpc_id      = aws_vpc.primary_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
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
}

resource "aws_security_group" "secondary_sg" {
  provider    = aws.secondary
  name        = "autoheal-sg-secondary"
  description = "Allow HTTP and SSH"
  vpc_id      = aws_vpc.secondary_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
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
}
# =============================
# Launch Templates
# =============================
resource "aws_launch_template" "primary_lt" {
  name_prefix             = "primary-lt-"
  image_id                = var.ami_id_primary
  instance_type           = var.instance_type
  key_name                = aws_key_pair.primary_key.key_name
  vpc_security_group_ids  = [aws_security_group.primary_sg.id]
}

resource "aws_launch_template" "secondary_lt" {
  provider                = aws.secondary
  name_prefix             = "secondary-lt-"
  image_id                = var.ami_id_secondary
  instance_type           = var.instance_type
  key_name                = aws_key_pair.secondary_key.key_name
  vpc_security_group_ids  = [aws_security_group.secondary_sg.id]
}

# =============================
# Auto Scaling Groups
# =============================
resource "aws_autoscaling_group" "primary_asg" {
  name                = "primary-asg"
  desired_capacity    = 2
  max_size            = 2
  min_size            = 1
  vpc_zone_identifier = [aws_subnet.primary_subnet_a.id, aws_subnet.primary_subnet_b.id]

  launch_template {
    id      = aws_launch_template.primary_lt.id
    version = "$Latest"
  }

  health_check_type = "EC2"
  force_delete      = true
}

resource "aws_autoscaling_group" "secondary_asg" {
  provider            = aws.secondary
  name                = "secondary-asg"
  desired_capacity    = 2
  max_size            = 2
  min_size            = 1
  vpc_zone_identifier = [aws_subnet.secondary_subnet_a.id, aws_subnet.secondary_subnet_b.id]

  launch_template {
    id      = aws_launch_template.secondary_lt.id
    version = "$Latest"
  }

  health_check_type = "EC2"
  force_delete      = true
}

# =============================
# Load Balancers + Target Groups + Listeners
# =============================
resource "aws_lb" "primary_alb" {
  name               = "primary-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.primary_subnet_a.id, aws_subnet.primary_subnet_b.id]
  security_groups    = [aws_security_group.primary_sg.id]
}

resource "aws_lb_target_group" "primary_tg" {
  name     = "primary-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.primary_vpc.id

  health_check {
    path = "/"
    port = "80"
  }
}

resource "aws_lb_listener" "primary_listener" {
  load_balancer_arn = aws_lb.primary_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.primary_tg.arn
  }
}

resource "aws_autoscaling_attachment" "primary_asg_attach" {
  autoscaling_group_name = aws_autoscaling_group.primary_asg.name
  lb_target_group_arn    = aws_lb_target_group.primary_tg.arn  
}

resource "aws_lb" "secondary_alb" {
  provider           = aws.secondary
  name               = "secondary-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.secondary_subnet_a.id, aws_subnet.secondary_subnet_b.id]
  security_groups    = [aws_security_group.secondary_sg.id]
}

resource "aws_lb_target_group" "secondary_tg" {
  provider = aws.secondary
  name     = "secondary-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.secondary_vpc.id

  health_check {
    path = "/"
    port = "80"
  }
}

resource "aws_lb_listener" "secondary_listener" {
  provider          = aws.secondary
  load_balancer_arn = aws_lb.secondary_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.secondary_tg.arn
  }
}

resource "aws_autoscaling_attachment" "secondary_asg_attach" {
  provider               = aws.secondary
  autoscaling_group_name = aws_autoscaling_group.secondary_asg.name
  lb_target_group_arn    = aws_lb_target_group.secondary_tg.arn  
}

# =============================
# Global Accelerator (Multi-Region HA)
# =============================
resource "aws_globalaccelerator_accelerator" "main" {
  name            = "autoheal-global-accelerator"
  enabled         = true
  ip_address_type = "IPV4"
}

resource "aws_globalaccelerator_listener" "http" {
  accelerator_arn = aws_globalaccelerator_accelerator.main.id
  client_affinity = "NONE"
  protocol        = "TCP"

  port_range {
    from_port = 80
    to_port   = 80
  }
}

resource "aws_globalaccelerator_endpoint_group" "primary" {
  listener_arn          = aws_globalaccelerator_listener.http.id
  endpoint_group_region = var.region_primary

  endpoint_configuration {
    endpoint_id = aws_lb.primary_alb.arn
    weight      = 100
  }
}

resource "aws_globalaccelerator_endpoint_group" "secondary" {
  provider              = aws.secondary
  listener_arn          = aws_globalaccelerator_listener.http.id
  endpoint_group_region = var.region_secondary

  endpoint_configuration {
    endpoint_id = aws_lb.secondary_alb.arn
    weight      = 50
  }
}
# =============================
# Save SSH Private Keys Locally (For Jenkins & Ansible)
# =============================

resource "local_file" "primary_private_key" {
  content  = tls_private_key.primary_key.private_key_pem
  filename = "${path.module}/autoheal-key-primary.pem"
}

resource "local_file" "secondary_private_key" {
  content  = tls_private_key.secondary_key.private_key_pem
  filename = "${path.module}/autoheal-key-secondary.pem"
}
