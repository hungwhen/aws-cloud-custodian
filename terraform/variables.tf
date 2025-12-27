variable "region" {

	type = string
	default = "us-central-1"

}

variable "function_name" {

	type = string
	default = "c7n-runner"

}

variable "schedule_expression" {

	type = string
	default = "rate(30 minutes)"

}

variable "lambda_memory_size" {
	type = number
	default = 1024
}

variable "lambda_timeout" {
	description = "Lambda timeout (seconds)"
	type = number
	default = 180
}