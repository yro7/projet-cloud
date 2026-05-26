# Monitoring - Prometheus & Grafana

Ce répertoire contiendra toutes les configurations pour installer et gérer la suite de monitoring (Prometheus + Grafana) sur le cluster.

## 🚀 Déploiement recommandé via Helm

La méthode la plus rapide et propre pour déployer la pile complète de monitoring (Prometheus Operator, Prometheus, Grafana, Node-Exporter) est d'utiliser le chart Helm officiel `kube-prometheus-stack` :

### 1. Ajouter le dépôt Helm officiel
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### 2. Créer un Namespace Kubernetes dédié
```bash
kubectl create namespace monitoring
```

### 3. Installer la pile de Monitoring
Vous pouvez déployer avec les valeurs par défaut en exécutant :
```bash
helm install kube-prometheus monitoring/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword=admin
```

*(Remplacez `admin` par un mot de passe sécurisé pour l'interface de Grafana).*

### 4. Accéder à l'interface Grafana
Pour accéder à Grafana en local (port `3000`), effectuez un transfert de port (Port-Forward) :
```bash
kubectl port-forward deployment/kube-prometheus-grafana 3000:3000 -n monitoring
```
Ensuite, ouvrez [http://localhost:3000](http://localhost:3000) dans votre navigateur. Identifiants : `admin` / `<votre_mot_de_passe>`.

Grafana est pré-configuré avec des Dashboards Kubernetes complets montrant l'utilisation CPU et Mémoire globale de vos nœuds et de vos pods !
