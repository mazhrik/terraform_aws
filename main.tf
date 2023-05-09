# Define the provider
provider "aws" {
  region = "us-west-2"
}

# Create a VPC using the terraform-aws-modules/vpc/aws module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.0.0"

  name                 = "my-vpc"
  cidr                 = "10.0.0.0/16"
  azs                  = ["us-west-2a", "us-west-2b"]
  private_subnets      = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets       = ["10.0.3.0/24", "10.0.4.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
}

# Create a security group for the RDS instance
resource "aws_security_group" "rds_sg" {
  name_prefix = "rds_sg_"
  

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  vpc_id = module.vpc.vpc_id
}

# Create a subnet group for the RDS instance
resource "aws_db_subnet_group" "rds_subnet_group_3" {
  name       = "rds_subnet_group_3"
  subnet_ids = module.vpc.private_subnets
}

# Create the RDS instance
resource "aws_db_instance" "mydb" {
  allocated_storage    = 20
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  name                 = "mydb"
  username             = "myuser"
  password             = "mypassword"
  publicly_accessible    = true
  db_subnet_group_name = aws_db_subnet_group.rds_subnet_group_3.name
  vpc_security_group_ids = [
    aws_security_group.rds_sg.id,
  ]

  depends_on = [
    aws_security_group.rds_sg,
    aws_db_subnet_group.rds_subnet_group_3,
  ]
}







# Create EKS cluster and worker nodes using terraform-aws-modules/eks/aws module
module "eks_cluster" {
  source = "terraform-aws-modules/eks/aws"
  version = "17.0.0"
  vpc_id=module.vpc.vpc_id

  cluster_name = "my-eks-cluster"
  subnets = module.vpc.private_subnets
  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
   cluster_version = "1.26"
  # Worker nodes configuration
  
  worker_groups_launch_template = [
    {
      instance_type = "t2.micro"
      asg_desired_capacity = 2
      additional_security_group_ids = [
        aws_security_group.rds_sg.id,
      ]
      
      additional_security_group_names = []
    }
  ]
 
}


provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

data "aws_eks_cluster" "cluster" {
  name = module.eks_cluster.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks_cluster.cluster_id
}


terraform {
  required_providers {
    kubectl = {
      source = "gavinbunney/kubectl"
    }
  }
}

provider "kubectl" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
}


locals {
  deployment_template = templatefile("./deployement.yaml", {
    PMA_HOST_VALUE = aws_db_instance.mydb.endpoint
  })
}

resource "kubectl_manifest" "phpmyadmin_deployment" {
  yaml_body = local.deployment_template
}

resource "kubectl_manifest" "phpmyadmin_service" {
  yaml_body = file("./service.yaml")
}
