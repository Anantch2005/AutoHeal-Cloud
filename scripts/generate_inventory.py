#!/usr/bin/env python3
import json
import subprocess
import os

# Auto-detect terraform directory
terraform_dir = os.path.join(os.getcwd(), "terraform")

print("🔍 Fetching Terraform outputs...")
try:
    tf_output = subprocess.check_output(["terraform", "output", "-json"], cwd=terraform_dir)
    data = json.loads(tf_output)
except subprocess.CalledProcessError as e:
    print("❌ Failed to fetch Terraform output:", e)
    exit(1)

# Extract IPs
primary_ips = data.get("primary_ec2_public_ips", {}).get("value", [])
secondary_ips = data.get("secondary_ec2_public_ips", {}).get("value", [])

# Write inventory
inventory_path = os.path.join(os.getcwd(), "ansible", "inventory.ini")
os.makedirs(os.path.dirname(inventory_path), exist_ok=True)

with open(inventory_path, "w") as f:
    f.write("[primary]\n")
    for ip in primary_ips:
        f.write(f"{ip}\n")
    f.write("\n[secondary]\n")
    for ip in secondary_ips:
        f.write(f"{ip}\n")

print(f"✅ Inventory file generated successfully at: {inventory_path}")
