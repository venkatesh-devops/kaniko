
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}
resource "aws_s3_bucket" "lambda_bucket" {
  bucket = var.lambda_artifats_bucket_name
}
