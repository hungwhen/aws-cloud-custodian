import os
import subprocess

# Make layer executables + modules visible to subprocesses
os.environ["PATH"] = "/opt/python/bin:" + os.environ.get("PATH", "")
os.environ["PYTHONPATH"] = (
    "/opt/python:"
    "/opt/python/lib/python3.11/site-packages:"
    + os.environ.get("PYTHONPATH", "")
)

POLICY_DIR = os.environ.get("C7N_POLICY_DIR", "/var/task/policies")

def handler(event, context):
    cmd = [
        "custodian", "run",
        "--region", os.environ.get("AWS_REGION", "us-east-1"),
        "--output-dir", "/tmp/c7n-out",
        f"{POLICY_DIR}/s3-public.yml",
        f"{POLICY_DIR}/sg-open.yml",
        f"{POLICY_DIR}/ebs-unencrypted.yml",
    ]

    r = subprocess.run(cmd, capture_output=True, text=True)

    return {
        "statusCode": 200 if r.returncode == 0 else 500,
        "stdout": r.stdout[-4000:],
        "stderr": r.stderr[-4000:],
    }
