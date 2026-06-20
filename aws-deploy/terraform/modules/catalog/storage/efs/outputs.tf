output "filesystem_id" {
  description = "ID del filesystem EFS"
  value       = var.create ? aws_efs_file_system.this[0].id : data.aws_efs_file_system.existing[0].id
}

output "filesystem_arn" {
  description = "ARN del filesystem EFS"
  value       = var.create ? aws_efs_file_system.this[0].arn : data.aws_efs_file_system.existing[0].arn
}

output "filesystem_dns_name" {
  description = "DNS name para montar desde EC2 via NFS. Ej: fs-xxxx.efs.us-east-1.amazonaws.com"
  value       = var.create ? aws_efs_file_system.this[0].dns_name : data.aws_efs_file_system.existing[0].dns_name
}

output "security_group_id" {
  description = "ID del Security Group del EFS. Agregar a las instancias EC2 o ECS que necesiten acceso"
  value       = var.create ? aws_security_group.this[0].id : null
}

output "mount_target_ids" {
  description = "IDs de los mount targets por subnet"
  value = var.create ? {
    for idx, mt in aws_efs_mount_target.this : idx => mt.id
  } : {}
}

output "mount_target_dns_names" {
  description = "DNS names de los mount targets por AZ. Ej: us-east-1a.fs-xxxx.efs.us-east-1.amazonaws.com"
  value = var.create ? {
    for idx, mt in aws_efs_mount_target.this : idx => mt.dns_name
  } : {}
}

output "access_point_ids" {
  description = "Mapa de nombre → ID del access point. Usado por ECS y EKS"
  value = var.create ? {
    for name, ap in aws_efs_access_point.this : name => ap.id
  } : {}
}

output "access_point_arns" {
  description = "Mapa de nombre → ARN del access point"
  value = var.create ? {
    for name, ap in aws_efs_access_point.this : name => ap.arn
  } : {}
}

output "ecs_volume_config" {
  description = "Configuración lista para usar en task definition de ECS. Mapa de access_point_name → config"
  value = var.create ? {
    for name, ap in aws_efs_access_point.this : name => {
      file_system_id  = aws_efs_file_system.this[0].id
      access_point_id = ap.id
      root_directory  = "/${name}"
    }
  } : {}
}

output "ec2_mount_command" {
  description = "Comando para montar el filesystem desde EC2 via NFS"
  value       = var.create ? "mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${aws_efs_file_system.this[0].dns_name}:/ /mnt/${var.name}" : null
}

output "eks_csi_config" {
  description = "Configuración para el EFS CSI driver en EKS"
  value = var.create ? {
    filesystem_id   = aws_efs_file_system.this[0].id
    access_point_ids = {
      for name, ap in aws_efs_access_point.this : name => ap.id
    }
  } : null
}
