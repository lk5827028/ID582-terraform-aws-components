module "label" {
  source     = "git::https://github.com/cloudposse/terraform-terraform-label.git?ref=tags/0.1.6"
  namespace  = var.namespace
  name       = var.name
  stage      = var.stage
  delimiter  = var.delimiter
  attributes = var.attributes
  tags       = var.tags
  enabled    = var.enabled
}

locals {
  # The usage of the specific kubernetes.io/cluster/* resource tags below are required
  # for EKS and Kubernetes to discover and manage networking resources
  # https://www.terraform.io/docs/providers/aws/guides/eks-getting-started.html#base-vpc-networking
  tags = merge(var.tags, map("kubernetes.io/cluster/${module.label.id}", "shared"))
}

data "aws_availability_zones" "available" {}

module "vpc" {
  source     = "git::https://github.com/cloudposse/terraform-aws-vpc.git?ref=tags/0.3.4"
  namespace  = var.namespace
  stage      = var.stage
  name       = var.name
  attributes = var.attributes
  tags       = local.tags
  cidr_block = var.vpc_cidr_block
}

module "subnets" {
  source              = "git::https://github.com/cloudposse/terraform-aws-dynamic-subnets.git?ref=tags/0.3.6"
  availability_zones  = ["${data.aws_availability_zones.available.names}"]
  namespace           = var.namespace
  stage               = var.stage
  name                = var.name
  attributes          = var.attributes
  tags                = local.tags
  region              = var.region
  vpc_id              = module.vpc.vpc_id
  igw_id              = module.vpc.igw_id
  cidr_block          = module.vpc.vpc_cidr_block
  nat_gateway_enabled = "true"
}

module "eks_cluster" {
  source                  = "git::https://github.com/cloudposse/terraform-aws-eks-cluster.git?ref=tags/0.1.1"
  namespace               = var.namespace
  stage                   = var.stage
  name                    = var.name
  attributes              = var.attributes
  tags                    = var.tags
  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = ["${module.subnets.public_subnet_ids}"]
  allowed_security_groups = ["${distinct(compact(concat(var.allowed_security_groups_cluster, list(module.eks_workers.security_group_id))))}"]
  allowed_cidr_blocks     = ["${var.allowed_cidr_blocks_cluster}"]
  enabled                 = var.enabled
}

module "eks_workers" {
  source                             = "git::https://github.com/cloudposse/terraform-aws-eks-workers.git?ref=tags/0.1.1"
  namespace                          = var.namespace
  stage                              = var.stage
  name                               = var.name
  attributes                         = var.attributes
  tags                               = var.tags
  image_id                           = var.image_id
  eks_worker_ami_name_filter         = var.eks_worker_ami_name_filter
  instance_type                      = var.instance_type
  vpc_id                             = module.vpc.vpc_id
  subnet_ids                         = ["${module.subnets.public_subnet_ids}"]
  health_check_type                  = var.health_check_type
  min_size                           = var.min_size
  max_size                           = var.max_size
  wait_for_capacity_timeout          = var.wait_for_capacity_timeout
  associate_public_ip_address        = var.associate_public_ip_address
  cluster_name                       = module.eks_cluster.eks_cluster_id
  cluster_endpoint                   = module.eks_cluster.eks_cluster_endpoint
  cluster_certificate_authority_data = module.eks_cluster.eks_cluster_certificate_authority_data
  cluster_security_group_id          = module.eks_cluster.security_group_id
  allowed_security_groups            = ["${var.allowed_security_groups_workers}"]
  allowed_cidr_blocks                = ["${var.allowed_cidr_blocks_workers}"]
  enabled                            = var.enabled

  # Auto-scaling policies and CloudWatch metric alarms
  autoscaling_policies_enabled           = var.autoscaling_policies_enabled
  cpu_utilization_high_threshold_percent = var.cpu_utilization_high_threshold_percent
  cpu_utilization_low_threshold_percent  = var.cpu_utilization_low_threshold_percent
}
