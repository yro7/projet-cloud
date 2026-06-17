# 1. Réseau VPC dédié au Cluster Kubernetes
resource "google_compute_network" "vpc_network" {
  name                    = "k8s-vpc"
  auto_create_subnetworks = false
  description             = "Réseau VPC dédié pour le cluster Kubernetes K3s"
}

# 2. Sous-réseau privé
resource "google_compute_subnetwork" "subnet" {
  name          = "k8s-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = var.region
  network       = google_compute_network.vpc_network.id
}

# 3. Règle de Pare-feu : Autoriser TOUTES les communications internes au VPC (Requis pour K8s)
resource "google_compute_firewall" "allow_internal" {
  name        = "k8s-allow-internal"
  network     = google_compute_network.vpc_network.name
  description = "Autorise toutes les communications de nœud à nœud au sein du VPC"

  allow {
    protocol = "all"
  }

  source_ranges = ["10.0.1.0/24"]
}

# 4. Règle de Pare-feu : Autoriser la connexion SSH externe
resource "google_compute_firewall" "allow_ssh" {
  name        = "k8s-allow-ssh"
  network     = google_compute_network.vpc_network.name
  description = "Autorise les connexions SSH externes sur le port 22"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # Pour des raisons de sécurité, vous pouvez restreindre cette plage à votre IP publique unique
  source_ranges = ["0.0.0.0/0"]
}

# 5. Règle de Pare-feu : Autoriser l'accès à l'API Kubernetes externe (K3s)
resource "google_compute_firewall" "allow_k3s_api" {
  name        = "k8s-allow-k3s-api"
  network     = google_compute_network.vpc_network.name
  description = "Autorise l'accès à l'API Server Kubernetes de K3s (Port 6443) depuis l'extérieur"

  allow {
    protocol = "tcp"
    ports    = ["6443"]
  }

  source_ranges = ["0.0.0.0/0"]
}

# 6. Règle de Pare-feu : Autoriser l'accès aux interfaces Web (Grafana, NodePorts K8s)
resource "google_compute_firewall" "allow_web" {
  name        = "k8s-allow-web"
  network     = google_compute_network.vpc_network.name
  description = "Autorise les flux HTTP, HTTPS, Grafana (3000) et la plage de ports NodePort de Kubernetes"

  allow {
    protocol = "tcp"
    ports    = [
      "80",          # HTTP standard
      "443",         # HTTPS standard
      "3000",        # Port par défaut Grafana
      "4040",        # Spark UI du driver (DAG, stages, tasks) pendant un job
      "8080",        # Port par défaut UI Spark
      "9870",        # UI Web du NameNode HDFS
      "30000-32767"  # Plage par défaut NodePorts Kubernetes
    ]
  }

  source_ranges = ["0.0.0.0/0"]
}
