# SSOT (Single Source of Truth) - Projet Cloud & Big Data

Ce document sert de **Source Unique de Vérité (SSOT)** pour tous les collaborateurs et agents autonomes intervenant sur ce projet. Il définit l'architecture technique, la répartition des rôles entre les outils de déploiement, et le workflow d'exploitation globale.

---

## 🧭 Philosophie & Répartition des Rôles

Pour garantir un déploiement 100% automatisé, propre et reproductible, l'infrastructure est segmentée selon une philosophie claire : **Séparation stricte entre le Contenant et le Contenu**.

```
┌────────────────────────────────────────────────────────┐
│               1. LE CONTENANT (OpenTofu)               │
│  - Création du réseau VPC & Sous-réseau                │
│  - Règles de pare-feu (sécurité interne & externe)     │
│  - Provisionnement des VMs Compute Engine (GCE)        │
│  - Attribution des adresses IP fixes et clés SSH       │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼ Génère l'inventaire dynamique
┌────────────────────────────────────────────────────────┐
│               2. LE CONTENU (Ansible)                  │
│  - Configuration de l'OS (mises à jour, dépendances)   │
│  - Installation et configuration de K3s Master/Agent   │
│  - Sécurisation locale & couplage réseau               │
│  - Exportation de la configuration Kubernetes          │
└──────────────────────────┬─────────────────────────────┘
                           │
                           ▼ Prêt pour les charges de travail
┌────────────────────────────────────────────────────────┐
│             3. L'APPLICATION (Kubernetes)              │
│  - Orchestration via Helm ou manifestes YAML           │
│  - Déploiement de Prometheus & Grafana (Monitoring)    │
│  - Déploiement de Hadoop Spark (Mode Cluster)          │
│  - Exécution du WordCount                              │
└────────────────────────────────────────────────────────┘
```

### 1. OpenTofu (ou Terraform) : Le Contenant 📦
* **Rôle** : Créer l'infrastructure réseau et physique dans Google Cloud Platform.
* **Philosophie** : OpenTofu déclare *où* et *sur quoi* s'exécute notre projet. Si l'on souhaite ajouter de la mémoire, un nouveau nœud worker, ou modifier une règle de pare-feu cloud, c'est ici que cela se passe.
* **Livrables clés** : 
  - Un VPC isolé et sécurisé (`k8s-vpc`).
  - Trois machines virtuelles GCE (1 Master, 2 Workers) avec clés SSH associées.
  - Un fichier d'inventaire `/ansible/inventory.ini` **généré automatiquement** à chaque exécution de manière dynamique.

### 2. Ansible : Le Contenu ⚙️
* **Rôle** : Configurer les machines et installer la suite logicielle Kubernetes (K3s).
* **Philosophie** : Ansible déclare *l'état exact requis* à l'intérieur de nos machines. Si une machine redémarre ou est recréée, Ansible peut être réappliqué instantanément pour la remettre dans son état nominal sans tout reconstruire.
* **Livrables clés** :
  - Un cluster Kubernetes (K3s) pleinement opérationnel avec 1 nœud Master et 2 nœuds Workers connectés.
  - La récupération du fichier de configuration sécurisé `kubeconfig` copié sur la machine de l'administrateur local pour le contrôle à distance via `kubectl`.

---

## Diagrammes d'Architecture

### 1. Architecture matérielle GCP

Ce diagramme décrit le socle physique réel : projet GCP, zone, VPC, sous-réseau, règles firewall et machines GCE.

```mermaid
flowchart TB
  Admin["Poste local administrateur\nOpenTofu / Ansible / kubectl / Helm\nSSH: ~/.ssh/id_rsa\nKubeconfig: ~/.kube/config-projet-cloud"]

  subgraph GCP["Google Cloud Platform\nproject-0209a452-648a-426d-a7b"]
    subgraph Region["Region europe-west9 (Paris)\nZone europe-west9-b"]
      subgraph VPC["VPC k8s-vpc"]
        subgraph Subnet["Subnet k8s-subnet\nCIDR 10.0.1.0/24"]
          Master["GCE k8s-master\nUbuntu 22.04 LTS\ne2-medium: 2 vCPU / 4 Go RAM\nBoot disk: pd-standard 30 Go\nIP privee: 10.0.1.10\nIP publique actuelle: 34.155.93.127\nTags: k8s-node, k8s-master"]
          Worker1["GCE k8s-worker-1\nUbuntu 22.04 LTS\ne2-medium: 2 vCPU / 4 Go RAM\nBoot disk: pd-standard 30 Go\nIP privee: 10.0.1.11\nIP publique actuelle: 34.163.51.166\nTags: k8s-node, k8s-worker"]
          Worker2["GCE k8s-worker-2\nUbuntu 22.04 LTS\ne2-medium: 2 vCPU / 4 Go RAM\nBoot disk: pd-standard 30 Go\nIP privee: 10.0.1.12\nIP publique actuelle: 34.155.93.9\nTags: k8s-node, k8s-worker"]
        end

        FWInternal["Firewall k8s-allow-internal\nSource: 10.0.1.0/24\nProtocoles: all\nUsage: trafic inter-noeuds K3s, Spark, HDFS"]
        FWSSH["Firewall k8s-allow-ssh\nSource: 0.0.0.0/0\nTCP 22"]
        FWK3S["Firewall k8s-allow-k3s-api\nSource: 0.0.0.0/0\nTCP 6443"]
        FWWeb["Firewall k8s-allow-web\nSource: 0.0.0.0/0\nTCP 80, 443, 3000, 8080, 9870, 30000-32767"]
      end
    end
  end

  Admin -->|SSH 22 / Ansible + demo scripts| FWSSH
  FWSSH --> Master
  FWSSH --> Worker1
  FWSSH --> Worker2

  Admin -->|kubectl / Helm / K3s API 6443| FWK3S
  FWK3S --> Master

  Admin -->|Interfaces web: Grafana / Spark UI / NameNode UI| FWWeb
  FWWeb --> Master

  Master <-->|trafic interne autorise| FWInternal
  Worker1 <-->|trafic interne autorise| FWInternal
  Worker2 <-->|trafic interne autorise| FWInternal
```

Points clés :

- OpenTofu crée le contenant GCP : VPC, subnet, firewall, VMs et inventaire Ansible.
- Les IPs privées sont stables et servent de contrat interne : master `10.0.1.10`, workers `10.0.1.11` et `10.0.1.12`.
- Les IPs publiques sont utilisées pour l'administration SSH et l'accès externe, mais le trafic inter-services passe par le réseau privé `10.0.1.0/24`.
- Les trois VMs sont des `e2-medium` avec 30 Go de disque standard. HDFS utilise le disque boot via `/data/hdfs/...`, sans disque additionnel.

### 2. Architecture Kubernetes K3s

Ce diagramme décrit la couche orchestrateur : K3s server, agents, namespaces, monitoring et pods Spark.

```mermaid
flowchart TB
  Admin["Poste local\nkubectl / Helm\nKUBECONFIG=~/.kube/config-projet-cloud"]

  subgraph Cluster["Cluster Kubernetes K3s\nVersion cible: v1.28.2+k3s1"]
    subgraph NodeMaster["Node Kubernetes: k8s-master\nVM: 10.0.1.10"]
      K3SServer["k3s server\nAPI Server :6443\nScheduler / Controller\nDatastore local K3s"]
      SystemMaster["Pods systeme K3s\nCoreDNS / metrics / CNI"]
    end

    subgraph NodeWorker1["Node Kubernetes: k8s-worker-1\nVM: 10.0.1.11"]
      K3SAgent1["k3s-agent\nrejoint https://10.0.1.10:6443"]
      ExecutorSlot1["Pods executors Spark\nnamespace default"]
      NodeExporter1["node-exporter\nDaemonSet monitoring"]
    end

    subgraph NodeWorker2["Node Kubernetes: k8s-worker-2\nVM: 10.0.1.12"]
      K3SAgent2["k3s-agent\nrejoint https://10.0.1.10:6443"]
      ExecutorSlot2["Pods executors Spark\nnamespace default"]
      NodeExporter2["node-exporter\nDaemonSet monitoring"]
    end

    subgraph DefaultNS["Namespace default"]
      SparkSA["ServiceAccount spark\nClusterRoleBinding: edit"]
      SparkExecPods["Pods Spark executors\nImage: apache/spark:v3.4.0\n1 core / 1 Go par executor"]
    end

    subgraph MonitoringNS["Namespace monitoring\nkube-prometheus-stack"]
      Prometheus["Prometheus\nService :9090\nScrape Kubernetes + HDFS"]
      Grafana["Grafana\nService :80\nAdmin: admin\nPlugin: grafana-polystat-panel"]
      GrafanaSidecar["Sidecar dashboards\nlabel: grafana_dashboard=1"]
      KubeStateMetrics["kube-state-metrics"]
      NodeExporterDS["node-exporter DaemonSet"]
      DashboardCM["ConfigMap honeycomb-dashboard\nDashboard node-honeycomb"]
    end
  end

  subgraph HostServices["Services hors Kubernetes, sur l'OS des VMs"]
    NameNode["HDFS NameNode\nk8s-master:9870 / :9000"]
    DataNode1["HDFS DataNode\nk8s-worker-1:9864 / :9866"]
    DataNode2["HDFS DataNode\nk8s-worker-2:9864 / :9866"]
  end

  Admin -->|kubectl / Helm| K3SServer
  K3SAgent1 -->|K3S_URL + token| K3SServer
  K3SAgent2 -->|K3S_URL + token| K3SServer

  SparkSA --> SparkExecPods
  SparkExecPods -.->|planifies sur workers| ExecutorSlot1
  SparkExecPods -.->|planifies sur workers| ExecutorSlot2

  DashboardCM --> GrafanaSidecar
  GrafanaSidecar --> Grafana
  Grafana --> Prometheus

  Prometheus -->|scrape /metrics| KubeStateMetrics
  Prometheus -->|scrape node metrics| NodeExporterDS
  NodeExporterDS -.->|1 pod par node| NodeExporter1
  NodeExporterDS -.->|1 pod par node| NodeExporter2
  Prometheus -->|scrape /prom| NameNode
  Prometheus -->|scrape /prom| DataNode1
  Prometheus -->|scrape /prom| DataNode2
```

Points clés :

- Le control-plane K3s est sur `k8s-master`. Les workers rejoignent le cluster via `https://10.0.1.10:6443` avec le token défini dans `ansible/group_vars/all.yml`.
- Le kubeconfig est récupéré par Ansible et adapté pour l'administration externe depuis la machine locale.
- Spark n'est pas installé comme un service permanent Kubernetes : les jobs créent des pods executors à la demande dans le namespace `default`.
- Prometheus/Grafana sont déployés dans `monitoring` via Helm. Le dashboard honeycomb est provisionné par ConfigMap, pas créé manuellement dans l'UI Grafana.
- HDFS tourne hors Kubernetes, directement sur les VMs via systemd, mais Prometheus le scrape via les IPs privées des noeuds.

### 3. Architecture Spark + HDFS

Ce diagramme décrit l'exécution applicative : `spark-submit` sur le master, driver en mode client, executors Kubernetes, lecture HDFS distribuée et visualisation.

```mermaid
flowchart LR
  User["Utilisateur demo\n./demo/3_run_wordcount.sh\n./demo/4_run_heavy_autoscale.sh\n./demo/5_run_wordcount_hdfs.sh"]

  subgraph MasterVM["VM k8s-master - 10.0.1.10"]
    SSH["SSH ubuntu@k8s-master"]
    SparkSubmit["/opt/spark/bin/spark-submit\nSpark 3.4.0 bin-hadoop3"]
    Driver["Spark Driver\n--deploy-mode client\nspark.driver.host=10.0.1.10"]
    K3SAPI["K3s API\nk8s://https://10.0.1.10:6443"]
    HDFSNN["HDFS NameNode\nRPC :9000\nUI /prom :9870\n/data/hdfs/namenode"]
  end

  subgraph K8SDefault["Kubernetes namespace default"]
    SparkSA2["ServiceAccount spark"]
    Exec1["Executor pod\napache/spark:v3.4.0\n1 core / 1 Go"]
    Exec2["Executor pod\napache/spark:v3.4.0\n1 core / 1 Go"]
    ExecDyn["Executors dynamiques\nscript 4: 1 -> 5 pods"]
  end

  subgraph WorkerVMs["VMs workers"]
    subgraph Worker1Spark["k8s-worker-1 - 10.0.1.11"]
      DN1["HDFS DataNode\n:9864 / :9866\n/data/hdfs/datanode"]
      PodPlacement1["Placement possible\nexecutor pods"]
    end
    subgraph Worker2Spark["k8s-worker-2 - 10.0.1.12"]
      DN2["HDFS DataNode\n:9864 / :9866\n/data/hdfs/datanode"]
      PodPlacement2["Placement possible\nexecutor pods"]
    end
  end

  subgraph HDFSData["Jeu de donnees HDFS"]
    BigFile["/data/input/big.txt\n256 Mo\n2 blocs ~128 Mo\nreplication=2"]
    Block1["Bloc 1\nreplicas: worker-1 + worker-2"]
    Block2["Bloc 2\nreplicas: worker-1 + worker-2"]
  end

  subgraph Monitoring["Observabilite"]
    Prom["Prometheus\nscrape Kubernetes + HDFS /prom"]
    Honeycomb["Grafana honeycomb\nCPU nodes\nCPU executors Spark\nStockage HDFS DataNodes"]
  end

  User -->|SSH| SSH
  SSH --> SparkSubmit
  SparkSubmit --> Driver
  Driver -->|cree / supprime executors| K3SAPI
  K3SAPI --> SparkSA2
  SparkSA2 --> Exec1
  SparkSA2 --> Exec2
  SparkSA2 --> ExecDyn

  Exec1 -.->|schedule| PodPlacement1
  Exec2 -.->|schedule| PodPlacement2
  ExecDyn -.->|autoscaling Spark dynamic allocation| PodPlacement1
  ExecDyn -.->|autoscaling Spark dynamic allocation| PodPlacement2

  Driver -->|metadata HDFS / hdfs://10.0.1.10:9000| HDFSNN
  Exec1 -->|demande localisation blocs| HDFSNN
  Exec2 -->|demande localisation blocs| HDFSNN
  HDFSNN --> BigFile
  BigFile --> Block1
  BigFile --> Block2
  Block1 --> DN1
  Block1 --> DN2
  Block2 --> DN1
  Block2 --> DN2
  Exec1 -->|lecture blocs HDFS / IP DataNode| DN1
  Exec2 -->|lecture blocs HDFS / IP DataNode| DN2

  Prom -->|metrics cAdvisor / kube-state / node-exporter| Exec1
  Prom -->|metrics cAdvisor / kube-state / node-exporter| Exec2
  Prom -->|metrics HDFS /prom| HDFSNN
  Prom -->|metrics HDFS /prom| DN1
  Prom -->|metrics HDFS /prom| DN2
  Honeycomb --> Prom
```

Points clés :

- Le driver Spark tourne sur la VM master, pas dans un pod, car les scripts utilisent `--deploy-mode client`.
- Les executors sont des pods Kubernetes éphémères créés par Spark via l'API K3s avec le ServiceAccount `spark`.
- `demo/3_run_wordcount.sh` lance un WordCount léger avec 2 executors fixes.
- `demo/4_run_heavy_autoscale.sh` lance SparkPi avec dynamic allocation : Spark augmente le nombre d'executors jusqu'à `MAX_EXEC=5`, puis scale down après inactivité.
- `demo/5_run_wordcount_hdfs.sh` lance un WordCount sur `hdfs://10.0.1.10:9000/data/input/big.txt`.
- HDFS est distribué sur les deux workers : NameNode sur master, DataNodes sur workers, réplication `2`, deux blocs visibles sur les deux DataNodes.
- Le client HDFS est déjà disponible dans Spark 3.4.0 `bin-hadoop3`, donc aucune image custom n'est nécessaire.
- Le NameNode renvoie des IPs de DataNodes, pas des hostnames, via `dfs.client.use.datanode.hostname=false`; cela permet aux pods executors de joindre directement `10.0.1.11` et `10.0.1.12`.

---

## 📁 Structure du Répertoire IaC

```
projet_cloud/
├── terraform/                # Gestion du Contenant (OpenTofu)
│   ├── providers.tf          # Déclaration du provider GCP
│   ├── variables.tf          # Définition des variables éditables
│   ├── terraform.tfvars      # Paramètres appliqués (ex: project_id, ssh_key)
│   ├── network.tf            # Création VPC, sous-réseau et Pare-feu
│   ├── compute.tf            # Définition des instances virtuelles GCE
│   └── outputs.tf            # Sorties utiles et génération automatique d'inventory.ini
│
├── ansible/                  # Gestion du Contenu (Ansible)
│   ├── group_vars/
│   │   └── all.yml           # Configuration globale (Token K3s, User GCP, etc.)
│   ├── inventory.ini         # Généré automatiquement par OpenTofu
│   ├── ansible.cfg           # Réglages de connexion SSH d'Ansible
│   └── playbooks/
│       ├── site.yml          # Playbook racine (point d'entrée)
│       ├── common.yml        # Tâches communes aux 3 instances (mise à jour, utilitaires)
│       ├── master.yml        # Déploiement et démarrage de K3s Master
│       ├── worker.yml        # Déploiement et jonction des agents Workers
│       ├── spark.yml         # Installation Spark, image executors, RBAC Kubernetes
│       └── hdfs.yml          # Déploiement HDFS natif (NameNode + DataNodes)
│
├── k8s/                      # Déploiement applicatif (Kubernetes)
│   ├── prometheus/           # Helm values, dashboards Grafana, scrape HDFS
│   └── spark/                # Documentation et ressources Spark éventuelles
│
├── demo/                     # Scripts de démonstration orale
│   ├── 3_run_wordcount.sh    # WordCount Spark léger, 2 executors fixes
│   ├── 4_run_heavy_autoscale.sh # SparkPi lourd, dynamic allocation 1 -> 5
│   └── 5_run_wordcount_hdfs.sh  # WordCount Spark lisant un fichier HDFS
│
├── var.md                    # Déclaration de l'ID projet (PROJET_ID)
├── projetmodia.md            # Spécifications de l'UE d'origine
└── SSOT.md                   # Ce document
```

---

## 🛠️ Workflow de Déploiement (Étape par Étape)

### Prérequis Locaux
1. Avoir **OpenTofu** ou **Terraform** installé sur sa machine.
2. Avoir **Ansible** installé (`brew install ansible` sur macOS).
3. Être authentifié sur GCP avec l'outil gcloud : `gcloud auth application-default login`.
4. Disposer d'une clé SSH publique locale dans `~/.ssh/id_rsa.pub`.

### Étape 1 : Provisionnement de l'infrastructure (OpenTofu)
Se placer dans le dossier Terraform, initialiser le projet et appliquer la configuration :
```bash
cd terraform
tofu init
tofu apply
```
*Cette étape crée le réseau, les VMs et écrit dynamiquement le fichier `../ansible/inventory.ini`.*

### Étape 2 : Configuration du cluster Kubernetes (Ansible)
Se placer dans le dossier Ansible et exécuter le playbook d'automatisation :
```bash
cd ../ansible
ansible-playbook -i inventory.ini playbooks/site.yml
```
*Cette étape installe K3s, connecte les nœuds, et rapatrie la configuration Kubernetes (`kubeconfig`) dans `~/.kube/config-projet-cloud`.*

### Étape 3 : Administration du cluster
Vous pouvez désormais interagir avec votre cluster Kubernetes GCP directement depuis votre terminal local :
```bash
export KUBECONFIG=~/.kube/config-projet-cloud
kubectl get nodes
```

---

## 🛑 Nettoyage (Destruction des ressources)
Pour détruire toutes les ressources GCP et éviter de consommer inutilement des crédits GCP hors ligne :
```bash
cd terraform
tofu destroy
```
