import os
import json
import subprocess

POLICY_DIR = os.environ.get("C7N_POLICY_DIR", "/var/task/policies")

def handler(event,context): 
    # policy files
    cmd = [
        "custodian", "run",
        "--region", os.environ["AWS_REGION"],
        "--output-dir", "/tmp/c7n-out",
        f"{POLICY_DIR}/s3-public.yml",
        f"{POLICY_DIR}/sg-open.yml",
        f"{POLICY_DIR}/ebs-unencrypted.yml"
    ]
    
    p = subprocess.run(cmd, capture_output=True, text=True)
    return {
        "statusCode": 200 if p.returncode == 0 else 500,
        "stdout": p.stdout[-4000:],
        "stderr": p.stderr[-4000:],
        "event": event
    }

