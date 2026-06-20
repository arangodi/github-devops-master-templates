output "certificates" {
  description = "Map de certificados — key es el nombre lógico"
  value = {
    for k, m in module.certificates : k => {
      arn    = m.arn
      domain = m.domain
    }
  }
}

output "secrets" {
  description = "Map de los secrets creados"
  value = {
    for k, m in module.secrets : k => {
      secret_arn      = m.secret_arn
      secret_name     = m.secret_name
      secret_id       = m.secret_id
      rotation_enabled = m.rotation_enabled
    }
  }
}