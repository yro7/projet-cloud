# Récupération de l'image de base Ubuntu 22.04 LTS
data "google_compute_image" "ubuntu" {
  family  = "ubuntu-2204-lts"
  project = "ubuntu-os-cloud"
}

# 1. Instance Master (Control Plane)
resource "google_compute_instance" "master" {
  name         = "k8s-master"
  machine_type = var.master_machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
      size  = 30 # 30 Go de disque (Suffisant pour stocker les images Docker/K3s)
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.id
    network_ip = "10.0.1.10" # IP interne statique pour le Master

    # Allocation d'une IP publique éphémère pour pouvoir se connecter en SSH et télécharger K3s
    access_config {}
  }

  metadata = {
    # Ajout automatique de la clé SSH publique locale pour l'utilisateur spécifié
    ssh-keys = "${var.ssh_username}:${file(pathexpand(var.ssh_public_key_file))}"
  }

  tags = ["k8s-node", "k8s-master"]

  description = "Nœud Master (Control Plane) du cluster Kubernetes"

  # L'image ubuntu-2204-lts pointe vers la dernière publiée par GCP : on ignore
  # sa dérive pour ne JAMAIS recréer une VM existante (perte du cluster) sur apply.
  lifecycle {
    ignore_changes = [boot_disk[0].initialize_params[0].image]
  }
}

# 2. Instances Workers (Agents)
resource "google_compute_instance" "workers" {
  count        = 2
  name         = "k8s-worker-${count.index + 1}"
  machine_type = var.worker_machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
      size  = 30 # 30 Go de disque
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.id
    network_ip = "10.0.1.1${count.index + 1}" # IPs internes statiques: 10.0.1.11 et 10.0.1.12

    # Allocation d'une IP publique éphémère
    access_config {}
  }

  metadata = {
    ssh-keys = "${var.ssh_username}:${file(pathexpand(var.ssh_public_key_file))}"
  }

  tags = ["k8s-node", "k8s-worker"]

  description = "Nœud Worker ${count.index + 1} du cluster Kubernetes"

  # Les workers dépendent du master pour le réseau, bien que cela soit géré au niveau d'Ansible
  depends_on = [google_compute_instance.master]

  lifecycle {
    ignore_changes = [boot_disk[0].initialize_params[0].image]
  }
}

# 3. Instance Monitoring dédiée (Prometheus/Grafana isolés du plan de calcul)
resource "google_compute_instance" "monitor" {
  name         = "k8s-monitor"
  machine_type = var.worker_machine_type # e2-medium (2 vCPU / 4 Go)
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
      size  = 30
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnet.id
    network_ip = "10.0.1.13" # IP interne statique du nœud monitoring

    access_config {}
  }

  metadata = {
    ssh-keys = "${var.ssh_username}:${file(pathexpand(var.ssh_public_key_file))}"
  }

  tags = ["k8s-node", "k8s-monitor"]

  description = "Nœud dédié au monitoring (Prometheus/Grafana), isolé des nœuds Spark/HDFS"

  depends_on = [google_compute_instance.master]

  lifecycle {
    ignore_changes = [boot_disk[0].initialize_params[0].image]
  }
}
