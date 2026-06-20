# shared/ no provisiona recursos directamente.
# Su responsabilidad es leer la red existente y
# exponer los outputs para que catalog/ los consuma.
resource "terraform_data" "anchor" {
  input = local.network
}
