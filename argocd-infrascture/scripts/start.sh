export MINIO_ACCESS_KEY="your-key"
export MINIO_SECRET_KEY="your-secret"
export TF_VAR_git_token="your-git-token"

cd env/mgmt && terraform init && terraform apply
cd ../int && terraform init && terraform apply
cd ../prod && terraform init && terraform apply