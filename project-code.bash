#!/bin/bash

# Set the project root directory
# PROJECT_ROOT="project-root"

# Create directory structure
echo "Creating project structure..."
mkdir -p .github/workflows
mkdir -p lambda
mkdir -p terraform

# Create files
echo "Creating files..."

# GitHub Actions Workflow
cat <<EOL > .github/workflows/terraform-deploy.yml
name: Deploy Terraform

on:
  pull_request:
    branches:
      - main

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Code
        uses: actions/checkout@v2

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.5.0

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v3
        with:
          aws-access-key-id: \${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: \${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Terraform Init
        run: terraform init

      - name: Terraform Plan
        run: terraform plan

      - name: Terraform Apply
        if: github.event.pull_request.merged == true
        run: terraform apply -auto-approve
EOL

# Lambda Function
cat <<EOL > lambda/replicate_files.py
import boto3
import os

s3_client = boto3.client('s3')

# Buckets configurados via variáveis de ambiente
SOURCE_BUCKET = os.environ['SOURCE_BUCKET']
DESTINATION_BUCKET = os.environ['DESTINATION_BUCKET']
FILES_TO_REPLICATE = ["users.json", "dashboards.json"]

def handler(event, context):
    try:
        print("Hello Wolrd")
    except Exception as e:
        print(f"Error processing event: {e}")
        raise e
EOL

# Terraform Main File
cat <<EOL > terraform/main.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  required_version = ">= 1.5.0"
}

provider "aws" {
  region = var.aws_region
}

resource "aws_s3_bucket" "source_bucket" {
  bucket = var.source_bucket
  acl    = "private"
}

resource "aws_s3_bucket" "destination_bucket" {
  bucket = var.destination_bucket
  acl    = "private"
}

resource "aws_lambda_function" "replicate_files" {
  function_name = var.lambda_name
  runtime       = "python3.9"
  handler       = "replicate_files.handler"
  filename      = "\${path.module}/../lambda/replicate_files.zip"

  environment {
    variables = {
      SOURCE_BUCKET      = var.source_bucket
      DESTINATION_BUCKET = var.destination_bucket
    }
  }

  role = aws_iam_role.lambda_role.arn
}

resource "aws_iam_role" "lambda_role" {
  name = "lambda_eventbridge_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  inline_policy {
    name   = "lambda-s3-policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject"
          ]
          Resource = [
            "arn:aws:s3:::\${var.source_bucket}/*",
            "arn:aws:s3:::\${var.destination_bucket}/*"
          ]
        }
      ]
    })
  }
}

resource "aws_cloudwatch_event_rule" "s3_eventbridge_rule" {
  name        = var.eventbridge_rule_name
  description = var.eventbridge_description

  event_pattern = jsonencode({
    "source": ["aws.s3"],
    "detail-type": ["Object Created", "Object Updated"],
    "detail": {
      "bucket": {
        "name": [var.source_bucket]
      },
      "object": {
        "key": ["users.json", "dashboards.json"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "eventbridge_to_lambda" {
  rule      = aws_cloudwatch_event_rule.s3_eventbridge_rule.name
  target_id = "replicate-files-lambda"
  arn       = aws_lambda_function.replicate_files.arn
}

resource "aws_lambda_permission" "eventbridge_invoke" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.replicate_files.arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_eventbridge_rule.arn
}
EOL

# Terraform Variables
cat <<EOL > terraform/variables.tf
variable "aws_region" {
  description = "AWS Region"
  default     = "us-east-1"
}

variable "source_bucket" {
  description = "Source bucket name"
}

variable "destination_bucket" {
  description = "Destination bucket name"
}

variable "lambda_name" {
  description = "Name of the Lambda function"
}

variable "eventbridge_rule_name" {
  description = "Name of the EventBridge rule"
  default     = "s3-object-modification"
}

variable "eventbridge_description" {
  description = "Description of the EventBridge rule"
  default     = "Triggers on new versions of specific files in the source bucket"
}
EOL

# README File
cat <<EOL > README.md
# AWS Lambda and Terraform Project

This project replicates specific files between S3 buckets using an AWS Lambda function and infrastructure managed by Terraform.

## Project Structure
- \`.github/workflows\`: GitHub Actions workflow for CI/CD.
- \`lambda\`: Contains the Lambda function code.
- \`terraform\`: Terraform configuration for deploying AWS infrastructure.

## Usage
1. Set up AWS credentials.
2. Deploy the infrastructure using Terraform.
3. Modify the source files in the source bucket to trigger replication.
EOL

echo "Project structure created successfully!"
