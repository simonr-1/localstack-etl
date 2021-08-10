provider "aws" {
    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    s3_force_path_style         = true
    access_key                  = "test"
    secret_key                  = "test"
    region = "us-east-1"
    
     endpoints {
        dynamodb          = "http://localhost:4566"
        s3                = "http://localhost:4566"
        ec2               = "http://localhost:4566"
        glue              = "http://localhost:4566"
        cloudwatch        = "http://localhost:4566"
        cloudwatchlogs    = "http://localhost:4566"
    }
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

##s3 buckets
resource "aws_s3_bucket" "glue_bucket" {
  bucket = "glue"
  acl    = "private"
}

resource "aws_iam_role" "glue" {
  name = "AWSGlueServiceRoleDefault"
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
        "${aws_s3_bucket.glue_bucket.arn}*"
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


module "glue_catalog_tables" {
  source = "./tables"
  glue_database_name = aws_glue_catalog_database.example.name
  glue_bucket = aws_s3_bucket.glue_bucket.bucket
  glue_bucket_id = aws_s3_bucket.glue_bucket.id
}
