variable "project_id" {
  type        = string
  default     = "project-0209a452-648a-426d-a7b"
  description = "L'ID du projet Google Cloud"
}

variable "region" {
  type        = string
  default     = "europe-west9" # Paris
  description = "La région GCP par défaut pour déployer les ressources"
}

variable "zone" {
  type        = string
  default     = "europe-west9-a"
  description = "La zone GCP spécifique pour déployer les ressources"
}

variable "ssh_public_key_file" {
  type        = string
  default     = "~/.ssh/id_rsa.pub"
  description = "Chemin vers le fichier de clé publique SSH pour se connecter aux machines"
}

variable "ssh_username" {
  type        = string
  default     = "ubuntu"
  description = "Nom d'utilisateur SSH créé sur les machines virtuelles (recommandé: ubuntu)"
}

variable "master_machine_type" {
  type        = string
  default     = "e2-medium" # 2 vCPU, 4 Go RAM (Idéal et économique pour le master K3s)
  description = "Type de machine pour le nœud master (control-plane)"
}

variable "worker_machine_type" {
  type        = string
  default     = "e2-medium" # 2 vCPU, 4 Go RAM
  description = "Type de machine pour les nœuds workers"
}

variable "k3s_token" {
  type        = string
  default     = "K3sSuperSecretToken12345!"
  sensitive   = true
  description = "Jeton de sécurité secret utilisé par les workers pour joindre le master K3s"
}
