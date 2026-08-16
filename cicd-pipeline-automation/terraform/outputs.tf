output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "health_check_url" {
  description = "Feed this to scripts/smoke-test.sh or the STAGING_HEALTH_URL / PRODUCTION_HEALTH_URL GitHub Actions variable"
  value       = module.alb.health_check_url
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "ecs_service_name" {
  value = module.ecs.service_name
}
