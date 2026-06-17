# 1. Output pour l'adresse IP publique du Master
output "master_public_ip" {
  value       = google_compute_instance.master.network_interface[0].access_config[0].nat_ip
  description = "Adresse IP publique du nœud Master (Control Plane)"
}

# 2. Output pour les adresses IP publiques des Workers
output "workers_public_ips" {
  value = {
    for worker in google_compute_instance.workers :
    worker.name => worker.network_interface[0].access_config[0].nat_ip
  }
  description = "Adresses IP publiques des nœuds Workers"
}

# 2b. Output pour l'adresse IP publique du nœud Monitoring
output "monitor_public_ip" {
  value       = google_compute_instance.monitor.network_interface[0].access_config[0].nat_ip
  description = "Adresse IP publique du nœud Monitoring (Prometheus/Grafana)"
}

# 3. Commande de connexion SSH pré-calculée pour le Master (pratique pour l'étudiant)
output "ssh_command_master" {
  value       = "ssh -i ${var.ssh_public_key_file} ${var.ssh_username}@${google_compute_instance.master.network_interface[0].access_config[0].nat_ip}"
  description = "Commande SSH directe pour se connecter au Master"
}

# 4. Génération AUTOMATIQUE du fichier d'inventaire Ansible (inventory.ini)
resource "local_file" "ansible_inventory" {
  content  = <<EOT
# Fichier généré automatiquement par Terraform / OpenTofu. Ne pas modifier manuellement.

[masters]
k8s-master ansible_host=${google_compute_instance.master.network_interface[0].access_config[0].nat_ip} ansible_user=${var.ssh_username} ansible_ssh_private_key_file=${replace(var.ssh_public_key_file, ".pub", "")}

[workers]
%{ for idx, worker in google_compute_instance.workers ~}
${worker.name} ansible_host=${worker.network_interface[0].access_config[0].nat_ip} ansible_user=${var.ssh_username} ansible_ssh_private_key_file=${replace(var.ssh_public_key_file, ".pub", "")}
%{ endfor ~}

[monitoring]
k8s-monitor ansible_host=${google_compute_instance.monitor.network_interface[0].access_config[0].nat_ip} ansible_user=${var.ssh_username} ansible_ssh_private_key_file=${replace(var.ssh_public_key_file, ".pub", "")}

[k8s:children]
masters
workers
monitoring
EOT
  filename = "${path.module}/../ansible/inventory.ini"
}
