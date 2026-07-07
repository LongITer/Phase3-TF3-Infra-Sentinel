# Infra - VPC + EKS (Terraform)

Dựng VPC + EKS cluster cho TF3 bằng Terraform, theo kiến trúc đã chốt (1 VPC/3AZ,
1 NAT Gateway, VPC endpoint ECR/S3, EKS managed node group 3x t3.large,
IRSA cho cluster-autoscaler + aws-load-balancer-controller).

## 0. Bootstrap remote state (chỉ làm 1 lần cho cả TF3)

Terraform không thể tự tạo backend nó sắp dùng - tạo tay trước:

```sh
aws s3 mb s3://techx-corp-tf3-terraform-state --region ap-southeast-1
aws s3api put-bucket-versioning --bucket techx-corp-tf3-terraform-state \
  --versioning-configuration Status=Enabled

aws dynamodb create-table \
  --table-name techx-corp-tf3-terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-southeast-1
```

Sau đó:
```sh
cp backend.hcl.example backend.hcl   # backend.hcl không commit giá trị thật khác nhau theo account
cp terraform.tfvars.example terraform.tfvars
```
Điền `allowed_admin_cidrs` (IP thật của từng thành viên TF3) và
`eks_admin_principal_arns` (ARN IAM user/role cần truy cập cluster) vào
`terraform.tfvars` trước khi apply.

## 1. Init / Plan / Apply

```sh
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply tfplan
```

`apply` mất khoảng 15-20 phút (EKS control plane + node group).

## 2. Sau khi apply xong

```sh
aws eks update-kubeconfig --name techx-corp-tf3 --region ap-southeast-1
kubectl get nodes
```

Từ đây tiếp tục theo [`GETTING_STARTED.md`](../phase3%20-%20information/GETTING_STARTED.md)
mục 2-5 (helm repo add, dependency build, `helm upgrade --install`).

## Chưa nằm trong phạm vi apply này (cố ý)

- Chart `aws-load-balancer-controller` / `cluster-autoscaler` - IAM role (IRSA) đã
  chuẩn bị sẵn (xem output `cluster_autoscaler_role_arn` / `lb_controller_role_arn`),
  nhưng việc `helm install` 2 add-on này làm riêng sau, không phải lúc apply Terraform.
- Migrate Postgres/Valkey/Kafka sang managed (RDS/ElastiCache/MSK) - nằm ngoài baseline,
  chỉ làm khi có mandate hoặc backlog ưu tiên tới lượt.

## Đổi số NAT Gateway / node sau này

Nếu backlog quyết định cần thêm NAT (1-per-AZ) hoặc đổi instance type, chỉ cần sửa
biến trong `terraform.tfvars` rồi `terraform plan`/`apply` lại - nhớ ghi ADR kèm lý do
đổi vì đây là thay đổi tốn tiền, đúng RULES.md mục ngân sách.
