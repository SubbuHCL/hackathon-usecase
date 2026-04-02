# Local values for resource naming and tagging
locals {
  # Environment-specific configurations
  environments = {
    dev = {
      name        = "development"
      short_name  = "dev"
      description = "Development environment"
    }
    uat = {
      name        = "uat"
      short_name  = "uat"
      description = "User Acceptance Testing environment"
    }
    prod = {
      name        = "production"
      short_name  = "prod"
      description = "Production environment"
    }
  }

  # Current environment configuration
  current_env = local.environments[var.environment]

  # Common naming prefix
  name_prefix = "${var.project_name}-${local.current_env.short_name}"

  # Resource names
  vpc_name                = "${local.name_prefix}-vpc"
  eks_cluster_name        = "${local.name_prefix}-eks-cluster"
  eks_node_group_name     = "${local.name_prefix}-node-group"
  eks_cluster_role_name   = "${local.name_prefix}-eks-cluster-role"
  eks_node_group_role_name = "${local.name_prefix}-eks-node-group-role"
  
  # Common tags
  common_tags = merge(
    var.tags,
    {
      Environment        = local.current_env.name
      EnvironmentShort   = local.current_env.short_name
      Project            = var.project_name
      ManagedBy          = "Terraform"
      CreatedDate        = timestamp()
    }
  )

  # Kubernetes tags for VPC resources
  kubernetes_tags = {
    "kubernetes.io/cluster/${local.eks_cluster_name}" = "shared"
  }

  # Public subnet tags
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
    Type                     = "public"
  }

  # Private subnet tags
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    Type                              = "private"
  }
}
