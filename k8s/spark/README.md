# Apache Spark & Hadoop sur Kubernetes

Ce répertoire contiendra les manifestes et fichiers de configuration pour déployer Apache Spark en mode cluster sur Kubernetes et y exécuter le job `WordCount`.

## 🚀 Options de déploiement de Spark

Il y a deux approches majeures pour faire tourner Apache Spark sur Kubernetes :

---

### Option A : Soumission de Job Directe via `spark-submit` (Recommandé pour débuter)
Kubernetes dispose d'un scheduler Spark natif. Vous n'avez pas besoin d'installer de serveur Spark persistant : Spark crée des pods exécuteurs dynamiquement à la volée lorsqu'un job est soumis, puis les détruit à la fin, ce qui libère toutes les ressources !

#### 1. Créer un ServiceAccount sécurisé pour Spark
Pour que Spark puisse créer des pods Workers (exécuteurs), il lui faut un rôle spécifique :
```bash
kubectl create serviceaccount spark
kubectl create clusterrolebinding spark-role --clusterrole=edit --serviceaccount=default:spark --namespace=default
```

#### 2. Soumettre le Job WordCount
Exécutez la commande `spark-submit` en ciblant l'API K3s du Master (que vous pouvez exécuter en SSH sur le Master, ou localement si Spark est installé sur votre Mac) :
```bash
spark-submit \
  --master k8s://https://10.0.1.10:6443 \
  --deploy-mode cluster \
  --name spark-wordcount \
  --class org.apache.spark.examples.JavaWordCount \
  --conf spark.executor.instances=2 \
  --conf spark.kubernetes.authenticate.driver.serviceAccountName=spark \
  --conf spark.kubernetes.container.image=apache/spark:v3.4.0 \
  local:///opt/spark/examples/jars/spark-examples_2.12-3.4.0.jar \
  /opt/spark/README.md
```

*(Note : K3s utilise des conteneurs légers, l'image `apache/spark:v3.4.0` contient l'application WordCount d'exemple préinstallée au chemin `local:///opt/spark/examples/...`)*

---

### Option B : Déploiement via le Spark Operator
Le **Spark Operator** (développé par Google) permet de gérer des clusters et des applications Spark comme des ressources natives Kubernetes (avec des fichiers YAML définissant un objet `SparkApplication`).

#### 1. Installer le Spark Operator avec Helm
```bash
helm repo add spark-operator https://googlecloudplatform.github.io/spark-on-k8s-operator
helm repo update
helm install spark-operator spark-operator/spark-operator \
  --namespace spark-operator \
  --create-namespace \
  --set webhook.enable=true
```

#### 2. Déployer un Job avec un fichier YAML
Vous pouvez déclarer votre application Spark dans un fichier `spark-wordcount.yaml` :
```yaml
apiVersion: "sparkoperator.k8s.io/v1beta2"
kind: SparkApplication
metadata:
  name: spark-wordcount
  namespace: default
spec:
  type: Scala
  mode: cluster
  image: "apache/spark:v3.4.0"
  imagePullPolicy: Always
  mainClass: org.apache.spark.examples.SparkPi
  mainApplicationFile: "local:///opt/spark/examples/jars/spark-examples_2.12-3.4.0.jar"
  sparkVersion: "3.4.0"
  restartPolicy:
    type: Never
  volumes:
    - name: "test-volume"
      hostPath:
        path: "/tmp"
        type: Directory
  driver:
    cores: 1
    coreLimit: "1200m"
    memory: "512m"
    labels:
      version: 3.4.0
    serviceAccount: spark
  executor:
    cores: 1
    instances: 2
    memory: "512m"
    labels:
      version: 3.4.0
```
Pour le lancer :
```bash
kubectl apply -f spark-wordcount.yaml
```
Vous pouvez ensuite voir le job tourner avec `kubectl get sparkapplications` et suivre les logs avec `kubectl logs -f spark-wordcount-driver`.
