provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "app_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "app_vpc"
  }
}

resource "aws_subnet" "app_subnet_1" {
  vpc_id = aws_vpc.app_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "app_subnet_1"
  }
}

resource "aws_subnet" "app_subnet_2" {
  vpc_id = aws_vpc.app_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "app_subnet_2"
  }
}

resource "aws_security_group" "app_sg" {
  name_prefix = "app_sg_"
  vpc_id      = aws_vpc.app_vpc.id

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.ecs_task_execution_role.name
}

resource "aws_ecr_repository" "app" {
  name = "app"
}

resource "aws_ecs_task_definition" "app" {
  family                   = "app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name  = "app"
    image = "${aws_ecr_repository.app.repository_url}:latest"
    portMappings = [{
      containerPort = 3000
      hostPort      = 3000
    }]
    essential = true
  }])

  memory = 512
  cpu    = 256
}

resource "aws_ecs_service" "app" {
  name            = "app"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1

  network_configuration {
    subnets          = [aws_subnet.app_subnet_1.id, aws_subnet.app_subnet_2.id]
    security_groups  = [aws_security_group.app_sg.id]
  }
}

resource "aws_ecs_cluster" "app_cluster" {
  name = "app_cluster"
}
