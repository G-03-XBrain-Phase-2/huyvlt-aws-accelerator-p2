# PowerShell script to synchronize code from the nested course folder to the root-level folder.
# Run this script before committing to keep both folders identical.

Copy-Item -Path "cloud/w8/1click/*" -Destination "1click" -Exclude ".terraform", "terraform.tfstate*", "generated-key.pem" -Recurse -Force
Write-Host "Sync complete! Code synchronized from 'cloud/w8/1click' to '1click' successfully." -ForegroundColor Green
