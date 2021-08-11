#terraform file
provider "aws" {
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    s3_force_path_style         = true
    access_key                  = "test"
    secret_key                  = "test"
    region = "us-east-1"

    endpoints {
        dynamodb        = "http://localhost:4566"
        s3              = "http://localhost:4566"
        ec2             = "http://localhost:4566"
        glue            = "http://localhost:4566"
        cloudwatch      = "http://localhost:4566"
        cloudwatchlogs  = "http://localhost:4566"
        sts             = "http://localhost:4566"
        iam             = "http://localhost:4566"
    }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

##s3 buckets
resource "aws_s3_bucket" "glue_bucket" {
  bucket = "glue"
  acl    = "private"
}

resource "aws_s3_bucket" "glue_script_bucket" {
  bucket = "glue-scripts"
  acl    = "private"
}

resource "aws_s3_bucket_object" "pyspark_script" {
  bucket = aws_s3_bucket.glue_script_bucket.bucket
  key    = "etl.py"
  source = "${path.module}/etl.py"

  # The filemd5() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the md5() function and the file() function:
  # etag = "${md5(file("path/to/file"))}"
  etag = filemd5("${path.module}/etl.py")
}

resource "aws_iam_role" "glue" {
  name = "MyAWSGlueServiceRoleDefault"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "glue.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "glue_service" {
    role = "${aws_iam_role.glue.id}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "my_s3_policy" {
  name = "my_s3_policy"
  role = "${aws_iam_role.glue.id}"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "${aws_s3_bucket.glue_bucket.arn}*",
        "${aws_s3_bucket.glue_script_bucket.arn}*"          
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetRecords",
        "dynamodb:DescribeTable",
        "dynamodb:Scan"        
      ],
      "Resource": "arn:aws:dynamodb:*:*:*"    
    }
  ]
}
EOF
}

resource "aws_glue_catalog_database" "example" {
  name = "test_catalog"
  catalog_id = data.aws_caller_identity.current.account_id
}

resource "aws_dynamodb_table" "test_table" {
  name             = "test_table"
  hash_key         = "id"
  billing_mode     = "PAY_PER_REQUEST"

  attribute {
    name = "id"
    type = "N"
  }
}

resource "aws_glue_job" "glue_job" {
 command {
   script_location = "s3://${aws_s3_bucket.glue_script_bucket.bucket}/${aws_s3_bucket_object.pyspark_script.id}"
   python_version = 3 
 }
 glue_version = "2.0"
 name = "python-job-cli"
 role_arn = aws_iam_role.glue.arn
}

module "glue_catalog_tables" {
  source = "./tables"
  glue_database_name = aws_glue_catalog_database.example.name
  glue_bucket = aws_s3_bucket.glue_bucket.bucket
  glue_bucket_id = aws_s3_bucket.glue_bucket.id
}
