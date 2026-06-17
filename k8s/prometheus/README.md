# Monitoring - Prometheus & Grafana

Ce répertoire contient la configuration IaC de la stack monitoring :

- `values.yaml` : valeurs Helm du chart `kube-prometheus-stack`, plugins Grafana, sidecar dashboards et scrapes HDFS.
- `honeycomb-dashboard.yaml` : ConfigMap Grafana provisionnee par sidecar, dashboard `node-honeycomb`.

## Workflow

Modifier les fichiers du repo d'abord, puis appliquer explicitement au cluster.

### 1. Ajouter le depot Helm officiel
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### 2. Creer le namespace Kubernetes dedie
```bash
kubectl create namespace monitoring
```

### 3. Installer ou mettre a jour la stack

Installation initiale :
```bash
helm install kube-prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f k8s/prometheus/values.yaml
```

Mise a jour apres modification de `values.yaml` :
```bash
helm upgrade kube-prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f k8s/prometheus/values.yaml \
  --reuse-values \
  --wait \
  --timeout 180s
```

### 4. Appliquer les dashboards provisionnes

```bash
kubectl apply -f k8s/prometheus/honeycomb-dashboard.yaml
```

Le sidecar Grafana importe les ConfigMaps labellisees `grafana_dashboard=1`.

### 5. Acceder a Grafana

```bash
kubectl -n monitoring port-forward deploy/kube-prometheus-grafana 3000:3000
```

Puis ouvrir `http://localhost:3000`.

## Dashboard honeycomb

Le dashboard `Cluster - Vue Nid d'Abeille (CPU + HDFS)` contient :

- CPU des noeuds Kubernetes.
- CPU des pods executors Spark pendant l'autoscaling.
- Stockage utilise par DataNode HDFS.

Le panel HDFS s'appuie sur les metriques Hadoop exposees par `/prom` :

```promql
100 * (
  1 - (
    org_apache_hadoop_hdfs_server_datanode_fsdataset_impl_fs_dataset_impl_remaining{job="hdfs-datanodes"}
    /
    org_apache_hadoop_hdfs_server_datanode_fsdataset_impl_fs_dataset_impl_capacity{job="hdfs-datanodes"}
  )
)
```

Les targets HDFS sont configurees dans `values.yaml` :

- NameNode : `10.0.1.10:9870/prom`
- DataNode worker-1 : `10.0.1.11:9864/prom`
- DataNode worker-2 : `10.0.1.12:9864/prom`
