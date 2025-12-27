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
	source_dir = "${path.module}/lambda"
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
			"s3:PutPublicAccessBlock",
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
			"ec2:DescribeSecurityGroups",
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

	# key management system k m s
	statement {
		effect = "Allow"
		actions = [
			"kms:ListKeys",
			"kms:ListAliases",
			"kms:DescribeKey"
		]
		resources = ["*"]
	}
}

resource "aws_iam_policy" "lambda_policy" {
	name = "${var.function_name}-policy"
	policy = data.aws_iam_policy_document.lambda_policy.json
}

resource "aws_iam_role_policy_attachment" "attach" {
	role = aws_iam_role.lambda_role.name
	policy_arn = aws_iam_policy.lambda_policy.arn
}

#lambda func

resource "aws_lambda_function" "c7n_runner" {
	function_name = var.function_name
	role = aws_iam_role.lambda_role.arn

	runtime = "python3.11"
	handler = "app.handler"

	filename = data.archive_file.lambda_zip.output_path
	source_code_hash = data.archive_file.lambda_zip.output_base64sha256


	memory_size = var.lambda_memory_size
	timeout = var.lambda_timeout

	environment {
	  variables = {
		C7N_POLICY_DIR  = "/var/task/policies"
		HOME            = "/tmp"
		XDG_CACHE_HOME  = "/tmp"
	  }
	}



	layers = [aws_lambda_layer_version.c7n.arn]
}

#eventbridge

resource "aws_cloudwatch_event_rule" "schedule" {

	name = "${var.function_name}-schedule"
	description = "run the cloud custodian brother"
	schedule_expression = var.schedule_expression

}

resource "aws_cloudwatch_event_target" "lambda_target" {
	rule = aws_cloudwatch_event_rule.schedule.name
	target_id = "c7n-runner"
	arn = aws_lambda_function.c7n_runner.arn
}

resource "aws_lambda_permission" "allow_eventbridge"  {

	statement_id = "AllowExecutionFromEventBridge"
	action = "lambda:InvokeFunction"
	function_name = aws_lambda_function.c7n_runner.function_name
	principal = "events.amazonaws.com"
	source_arn  = aws_cloudwatch_event_rule.schedule.arn

}

output "lambda_name" {

	value = aws_lambda_function.c7n_runner.function_name

}

output "eventbridge_rule" {

	value = aws_cloudwatch_event_rule.schedule.name

}

resource "aws_lambda_layer_version" "c7n" {
  layer_name          = "cloud-custodian-py311"
  filename            = "${path.module}/c7n-layer.zip"
  compatible_runtimes = ["python3.11"]
}
