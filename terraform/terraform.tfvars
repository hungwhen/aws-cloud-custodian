region = "us-east-1"
function_name = "cloud-custodian-runner"
lambda_memory_size = 1024
lambda_timeout = 100
schedule_expression = "rate(1 hour)"
