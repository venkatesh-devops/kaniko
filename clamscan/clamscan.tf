
resource "aws_ecr_repository" "clamscan_lambda_repository" {
  name = var.clamscan_lambda_repository 
}


resource "null_resource" "clamscan_docker_build_and_push" {
  provisioner "local-exec" {
    command = <<EOT
      aws ecr get-login-password --region ${var.aws_region_primary} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${aws_region_primary}.amazonaws.com
      docker build -t clamscan_lambda_repository .
      docker tag clamscan_lambda_repository:latest ${aws_ecr_repository.lambda_repo.repository_url}:latest
      docker push ${aws_ecr_repository.lambda_repo.repository_url}:latest
    EOT
  }
  triggers = {
    always_run = "${timestamp()}"
  }

  depends_on = [aws_ecr_repository.clamscan_lambda_repository]
}


resource "aws_iam_role" "clamscan_lambda_execution_role" {
  name = var.clamscan_lambda_execution_role 
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
      },
    ],
  })
  inline_policy {
    name = "lambda_policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "s3:DeleteObject",
            "s3:DeleteObjectTagging",
            "s3:GetObject",
            "s3:GetObjectTagging",
            "s3:ListBucket",
            "s3:ListTagsForResource",
            "s3:PutObject",
            "s3:PutObjectTagging",
            "s3:TagResource"
      ]
          Effect   = "Allow"
          Resource = "*"
        }
      ]
    })
  }
}


resource "aws_iam_role_policy_attachment" "intents_lambda_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.clamscan_lambda_execution_role.name
}

resource "aws_lambda_function" "clamscan_lambda_function" {
  function_name = var.clamscan_lambda_function #"clamscan_lambda_function"
  role          = aws_iam_role.clamscan_lambda_execution_role.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.lambda_repo.repository_url}:latest"

  environment {
    variables = {
      EFS_MOUNT_PATH = "/clamscan_lambda"
      EFS_DEF_PATH = "clamscan_def_data"
    }
  }

  file_system_config {
    arn = aws_efs_access_point.access_point_for_clamscan_lambda.arn

    # Local mount path inside the lambda function. Must start with '/mnt/'
    local_mount_path = "/mnt/efs"
  }

  vpc_config {
    subnet_ids         = var.clamscan_lambda_subnet_id
    security_group_ids = [aws_security_group.clamscan_efs_sg.id]
  }


  depends_on = [null_resource.clamscan_docker_build_and_push, aws_efs_mount_target.alpha]
}

resource "aws_efs_mount_target" "efs_mount_target" {
  for_each = toset(var.clamscan_lambda_subnet_id) 
  file_system_id = aws_efs_file_system.clamscan_lambda_efs.id
  subnet_id      = each.value
  security_groups = [aws_security_group.clamscan_efs_sg.id]
}


resource "aws_security_group" "clamscan_efs_sg" {
  name   = var.clamscan_efs_sg 
  vpc_id = var.clamscan_vpc_id 

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = [var.clamscan_vpc_id_cidr] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "clamScan EFS Security Group"
  }
}


resource "aws_efs_file_system" "clamscan_lambda_efs" {
  creation_token = var.clamscan_efs_token
  tags = {
    Name = "ClamScanLambdaEFS"
  }
}

resource "aws_efs_access_point" "access_point_for_clamscan_lambda" {
  file_system_id = aws_efs_file_system.clamscan_lambda_efs.id

  root_directory {
    path = "/clamscan_lambda"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "777"
    }
  }

  posix_user {
    gid = 1000
    uid = 1000
  }
}

resource "aws_lambda_permission" "allow_clamscan_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.clamscan_lambda_function.arn
  principal     = "s3.amazonaws.com"
  source_arn    = "*"
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = var.clamscan_bucket_name

  lambda_function {
    lambda_function_arn = aws_lambda_function.clamscan_lambda_function.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_clamscan_bucket]
}


variable "clamscan_lambda_repository" {
  type = string
  default = ""
  
}

variable "clamscan_lambda_execution_role" {
  type = string
  default = ""
  
}

variable "clamscan_lambda_function" {
  type = string
  default = ""
  
}

variable "clamscan_lambda_subnet_id" {
  type = list(string)
  default = [ "" ]
}
variable "clamscan_vpc_id" {
  type = string
  default = ""
  
}

variable "clamscan_efs_sg" {
  type = string
  default = ""
  
}

variable "clamscan_vpc_id_cidr" {
  type = string
  default = ""
  
}

variable "clamscan_efs_token" {
  type = string
  default = ""
  
}

variable "clamscan_bucket_name" {
  type = string
  default = ""
  
}