# PowerShell script to synchronize code from the nested course folder to the root-level folder.
# Run this script before committing to keep both folders identical.

# Clean existing root directories
if (Test-Path "1click") { Remove-Item -Recurse -Force "1click" }
if (Test-Path "capstone_w8_final") { Remove-Item -Recurse -Force "capstone_w8_final" }

# Recreate and copy K8s Lab
New-Item -ItemType Directory -Path "1click" -Force | Out-Null
Copy-Item -Path "cloud/w8/1click/*" -Destination "1click" -Exclude ".terraform", "terraform.tfstate*", "generated-key.pem" -Recurse -Force

# Recreate and copy Capstone Final Project
New-Item -ItemType Directory -Path "capstone_w8_final" -Force | Out-Null
Copy-Item -Path "cloud/w8/capstone_w8_final/*" -Destination "capstone_w8_final" -Exclude ".terraform", "terraform.tfstate*", "generated-key.pem" -Recurse -Force

Write-Host "Sync complete! Code synchronized from 'cloud/w8/1click' -> '1click' and 'cloud/w8/capstone_w8_final' -> 'capstone_w8_final' successfully." -ForegroundColor Green
