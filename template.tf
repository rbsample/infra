provider "aws" {
  profile = "rbsample"
  region  = "eu-west-1"
}

resource "aws_key_pair" "key_rbsample" {
  key_name   = "terraform"
  public_key = file("key_rbsample.pub")
}

resource "aws_security_group" "sg_rbsample" {
  name        = "rbsample-security-group"
  description = "Allow HTTP, HTTPS and SSH traffic"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["YOUR_PUBLIC_IP/32"]
  }


  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rbsample-security-group"
  }
}

resource "aws_iam_policy" "policy" {
  name        = "test_policy"
  path        = "/"
  description = "My ECR policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "ecr:*",
      "Effect": "Allow",
      "Resource": "arn:aws:ecr:*:*:repository/rbsample*"
    },
    {
      "Action": "ecr:GetAuthorizationToken",
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = "rbsample_profile"
  role = aws_iam_role.role.name
}

resource "aws_iam_role" "role" {
  name = "rbsample_role"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": "EC2"
        }
    ]
}
EOF
}

resource "aws_iam_policy_attachment" "attach" {
  name       = "attachment"
  roles      = [aws_iam_role.role.name]
  policy_arn = aws_iam_policy.policy.arn
}
resource "aws_instance" "master" {
  key_name      = aws_key_pair.key_rbsample.key_name
  ami           = "ami-06fd8a495a537da8b"
  instance_type = "t2.medium"
  iam_instance_profile = "${aws_iam_instance_profile.instance_profile.name}"

  tags = {
    Name = "jenkins_master"
    Environment = "rbsample"
    Role = "master"
  }

  vpc_security_group_ids = [
    aws_security_group.sg_rbsample.id
  ]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file("key_rbsample.pem")
    host        = self.public_ip
  }

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_type = "gp2"
    volume_size = 30
  }
}

resource "aws_eip" "eip1" {
  vpc      = true
  instance = aws_instance.master.id
}


resource "aws_ecr_repository" "rbsample_repo" {
  name                 = "rbsample"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
