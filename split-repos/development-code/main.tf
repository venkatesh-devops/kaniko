terraform {
  required_version = ">= 0.15"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {}
}

# used to get the account id
data "aws_caller_identity" "current" {}


# used to get the account id
data "aws_caller_identity" "current" {}

variable "lambda_functions_config_file" {
  type    = string
  default = "lambda_configuration.json"  
}

data "local_file" "lambda_config" {
  filename = "${path.module}/${var.lambda_functions_config_file}"
}

locals {
  lambda_functions = jsondecode(data.local_file.lambda_config.content)
}

# For each Lambda function, create a zip of the handler code
data "archive_file" "lambda_zip" {
  for_each = { for function in local.lambda_functions : function.function_name => function }

  type        = "zip"
  source_dir  = each.value.folder_path # Path to the folder containing Lambda handler code
  output_path = "${path.module}/${each.value.function_name}.zip" # Output zip file path
}

# Upload the zip file to S3
resource "aws_s3_object" "lambda_code" {
  for_each    = { for function in local.lambda_functions : function.function_name => function }

  bucket      = each.value.s3_bucket
  key         = each.value.s3_key
  source      = data.archive_file.lambda_zip[each.key].output_path # Reference the zipped file
  etag   = filemd5(data.archive_file.lambda_zip[each.key].output_path)
}
locals {
  updated_functions = jsonencode({
    for function_name, lambda_zip in data.archive_file.lambda_zip :
    function_name => filemd5(lambda_zip.output_path)
  })
}

resource "null_resource" "update_lambda_functions" {
  provisioner "local-exec" {
    command = "/usr/bin/python3 ${path.module}/update_lambda_functions.py --config ${lambda_functions_config_file} --updated-functions '${local.updated_functions}'"
  }
  triggers = {
    always_run = "${timestamp()}"
  }
  depends_on = [aws_s3_object.lambda_code]
}