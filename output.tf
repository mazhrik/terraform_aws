output "rds_endpoint" {
  description = "The connection endpoint for the RDS instance"
  value       = aws_db_instance.mydb.endpoint
}

output "eks_cluster_id" {
  description = "The id of the EKS cluster"
  value       = module.eks_cluster.cluster_id
}

output "eks_cluster_endpoint" {
  description = "The endpoint of the EKS cluster"
  value       = data.aws_eks_cluster.cluster.endpoint
}

output "vpc_id" {
  description = "The ID of the VPC"
  value       = module.vpc.vpc_id
}
