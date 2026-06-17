#!/bin/bash
# Script de Démo Oral - Étape 4 : AUTO-SCALING des Executors Spark
# Job lourd (CPU-bound) qui déclenche la "Dynamic Allocation" de Spark :
# Kubernetes déploie automatiquement de nouveaux pods executors tant qu'il
# reste des tâches en attente, puis les détruit quand la charge retombe.

GREEN='\033[0;32m'
NC='\033[0m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'

MASTER_IP="34.155.93.127"
MASTER_INTERNAL_IP="10.0.1.10"   # IP VPC résolvable par les pods executors
SSH_KEY="~/.ssh/id_rsa"

# Charge : SparkPi avec beaucoup de partitions => beaucoup de tâches en attente
# => backlog persistant => Spark réclame de nouveaux executors jusqu'à MAX_EXEC.
# 8000 partitions : tâches SparkPi très courtes (~50ms), donc il en faut beaucoup
# pour tenir le plateau à 5 executors ~2 min (sinon le job finit en 30s et le pic
# rouge passe trop vite sur Grafana). Testé : 2000 -> 30s, donc ~8000 -> ~2 min.
PI_PARTITIONS=8000
MAX_EXEC=5                        # Cluster = 6 cores ; on monte jusqu'à 5 executors

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}   DÉMO ORAL - ÉTAPE 4 : AUTO-SCALING DYNAMIQUE DES EXECUTORS    ${NC}"
echo -e "${CYAN}================================================================${NC}"

echo -e "1. Connexion SSH au nœud Master GCP (${MASTER_IP})..."
echo -e "2. Lancement d'un job LOURD (SparkPi, ${PI_PARTITIONS} partitions)...\n"
echo -e "   ${YELLOW}Regardez l'étape 2 (watch) et le Grafana 'Nid d'Abeille' :${NC}"
echo -e "   ${YELLOW}les executors passent de 1 -> ${MAX_EXEC} automatiquement,${NC}"
echo -e "   ${YELLOW}puis sont détruits quand le calcul se termine.${NC}\n"

# Dynamic Allocation sur Kubernetes :
#  - shuffleTracking.enabled=true : obligatoire sur K8s (pas de external shuffle service).
#  - schedulerBacklogTimeout=5s : réclame des executors vite dès qu'il y a du backlog.
#  - executorIdleTimeout=30s : détruit les executors inactifs (scale-down visible).
SPARK_COMMAND="spark-submit \
  --master k8s://https://${MASTER_INTERNAL_IP}:6443 \
  --deploy-mode client \
  --class org.apache.spark.examples.SparkPi \
  --conf spark.driver.host=${MASTER_INTERNAL_IP} \
  --conf spark.driver.bindAddress=0.0.0.0 \
  --conf spark.dynamicAllocation.enabled=true \
  --conf spark.dynamicAllocation.shuffleTracking.enabled=true \
  --conf spark.dynamicAllocation.minExecutors=1 \
  --conf spark.dynamicAllocation.initialExecutors=1 \
  --conf spark.dynamicAllocation.maxExecutors=${MAX_EXEC} \
  --conf spark.dynamicAllocation.schedulerBacklogTimeout=5s \
  --conf spark.dynamicAllocation.executorIdleTimeout=30s \
  --conf spark.executor.cores=1 \
  --conf spark.executor.memory=1g \
  local:///opt/spark/examples/jars/spark-examples_2.12-3.4.0.jar \
  ${PI_PARTITIONS}"

ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$MASTER_IP" "bash -l -c '$SPARK_COMMAND'"

echo -e "\n${GREEN}[SUCCÈS] Job lourd terminé.${NC}"
echo -e "Spark a libéré les executors supplémentaires (scale-down automatique)."
echo -e "${CYAN}================================================================${NC}"
