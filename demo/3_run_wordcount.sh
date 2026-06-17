#!/bin/bash
# Script de Démo Oral - Étape 3 : Soumission du Job WordCount Spark
# Ce script se connecte en SSH sur la VM Master et déclenche le calcul distribué.

GREEN='\033[0;32m'
NC='\033[0m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'

MASTER_IP="34.155.93.127"
MASTER_INTERNAL_IP="10.0.1.10"   # IP VPC résolvable par les pods (fix DNS executors)
SSH_KEY="~/.ssh/id_rsa"
ITERATIONS=10                     # Répétitions pour élargir la fenêtre de monitoring

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}      DÉMO ORAL - ÉTAPE 3 : SOUMISSION DU JOB WORDCOUNT SPARK   ${NC}"
echo -e "${CYAN}================================================================${NC}"

echo -e "1. Connexion SSH au nœud Master GCP (${MASTER_IP})..."

# Commande spark-submit :
#  - spark.driver.host = IP interne VPC : les pods executors ne savent pas résoudre
#    le FQDN GCP interne du master ; on force une IP routable dans le VPC.
#  - spark.driver.bindAddress=0.0.0.0 : le driver écoute sur toutes les interfaces.
#  - dynamicAllocation désactivée + 2 executors fixes : 2 pods garantis et stables,
#    visibles sur le watch (étape 2) et sur Grafana.
#  - boucle ITERATIONS : maintient une charge CPU/mémoire sur ~1-2 min pour que
#    Prometheus (scrape 5s) échantillonne plusieurs fois la charge.
SPARK_COMMAND="for i in \$(seq 1 ${ITERATIONS}); do \
  echo \"=== Itération \$i / ${ITERATIONS} ===\"; \
  spark-submit \
    --master k8s://https://${MASTER_INTERNAL_IP}:6443 \
    --deploy-mode client \
    --class org.apache.spark.examples.JavaWordCount \
    --conf spark.driver.host=${MASTER_INTERNAL_IP} \
    --conf spark.driver.bindAddress=0.0.0.0 \
    --conf spark.dynamicAllocation.enabled=false \
    --conf spark.executor.instances=2 \
    --conf spark.executor.cores=1 \
    --conf spark.executor.memory=1g \
    local:///opt/spark/examples/jars/spark-examples_2.12-3.4.0.jar \
    /opt/spark/examples/src/main/resources/people.txt; \
done"

echo -e "2. Déclenchement du calcul distribué Spark sur Kubernetes...\n"
echo -e "   ${YELLOW}Vérifiez l'écran de monitoring de l'étape 2 (watch) et Grafana !${NC}"
echo -e "   -> 2 executors fixes, ${ITERATIONS} itérations pour charge visible.\n"

# Exécution sur le Master via SSH en forçant un login shell (charge /etc/profile.d/spark.sh)
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$MASTER_IP" "bash -l -c '$SPARK_COMMAND'"

echo -e "\n${GREEN}[SUCCÈS] Job Spark terminé.${NC}"
echo -e "Les pods exécuteurs dynamiques ont été détruits par Kubernetes pour libérer la mémoire."
echo -e "${CYAN}================================================================${NC}"
