output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "rds_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "hosted_zone_id" {
  value = aws_route53_zone.main.zone_id
}

output "appmesh_arn" {
  value = aws_appmesh_mesh.main.arn
}
