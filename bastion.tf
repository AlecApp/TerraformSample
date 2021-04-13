# Bastion key
resource "tls_private_key" "bastion_tls_key" {
  algorithm = "RSA"
}

module "bastion_key_pair" {
  source     = "terraform-aws-modules/key-pair/aws"
  key_name   = "bastion-${var.env}"
  public_key = tls_private_key.bastion_tls_key.public_key_openssh
}

# Print private key. There are better & more secure ways of doing this than printing it in console.
output "bastion_private_key" {
  value = tls_private_key.bastion_tls_key.private_key_pem
}

# Bastion
module "bastion" {
  source                       = "Guimove/bastion/aws"
  version                      = "2.2.2"
  bastion_launch_template_name = "bastion-${var.env}"
  bucket_name                  = "bastion-${var.env}"
  bucket_force_destroy         = true
  region                       = var.region
  vpc_id                       = module.vpc.vpc_id
  is_lb_private                = false
  create_dns_record            = false
  bastion_host_key_pair        = module.bastion_key_pair.this_key_pair_key_name
  bastion_iam_policy_name      = "bastion-${var.env}-iam-policy"
  elb_subnets                  = module.vpc.public_subnets
  auto_scaling_group_subnets   = module.vpc.public_subnets
  extra_user_data_content      = "amazon-linux-extras install postgresql10 vim epel"
  cidrs                        = ["${var.my_cidr}"]
  tags = {
    "name"        = "bastion-${var.env}",
    "description" = "Bastion for ${var.env}"
  }
}

# Allow Postgres traffic to the database from the bastion instance
resource "aws_security_group_rule" "bastion-db" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.allow_postgres.id
  source_security_group_id = module.bastion.bastion_host_security_group[0]
}
