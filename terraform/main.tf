terraform {
	required_version = ">=1.4.0"
	required_providers {
		aws = {
			source = "hashicorp/aws"
			version = ">= 5.0"
		}
		archive = {
			source = "hashicorp/archive"
			version = ">=2.4"
		}
	}
}

provider "aws" {
	region = var.region
}

data "archive_file" "lambda_zip" {
	type = "zip"
	source_dir = "${path.module}/lambda_src"
	output_path = "${path.module}/build/${var.function_name}.zip"
}

data "aws_iam_policy_document" "lambda_assume" {
	statement {
		effect = "Allow"
		principals {
			type = "Service"
			identifiers = ["lambda.amazonaws.com"]
		}
		actions = ["sts:AssumeRole"]
	}
}

resource "aws_iam_role" "lambda_role" {
	name = "${var.function_name}-role"
	assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

data "aws_iam_policy_document" "lambda_policy" {

	statement {
		effect = "Allow"
		actions = [
			"logs:CreateLogGroup",
			"logs:CreateLogStream",
			"logs:PutLogEvents"
		]
		resources = ["*"]
	}


	#s3 audit + remediation
	statement {
		effect = "Allow"
		actions = [
			"s3:ListAllMyBuckets",
			"s3:GetBucketLocation",
			"s3:GetBucketAcl",
			"s3:GetBucketPolicy",
			"s3:GetPublicAccessBlock",
			"s3:GetEncryptionConfiguration",
			"s3:PutPublicAccessBlock"
			"s3:PutBucketPolicy",
			"s3:DeleteBucketPolicy",
			"s3:PutEncryptionConfiguration"
		]
		resources = ["*"]
	}

	# ec2 sg audit + revoke ingress
	statement {
		effect = "Allow"
		actions = [
			"ec2:DescribeSecurityGroup",
			"ec2:RevokeSecurityGroupEgress",
			"ec2:RevokeSecurityGroupIngress",
			"ec2:CreateTags"
		]
		resources = ["*"]
	}

	# ebc audit / tagging

	statement {
		effect = "Allow"
		actions = [
			"ec2:DescribeVolumes",
			"ec2:DescribeSnapshots",
			"ec2:DescribeInstances",
			"ec2:DescribeRegions",
			"ec2:CreateTags"
		]
		resources = ["*"]
	}

}