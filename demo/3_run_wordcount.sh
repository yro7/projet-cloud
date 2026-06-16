#!/bin/bash
# Script de Démo Oral - Étape 3 : Soumission du Job WordCount Spark
# Ce script se connecte en SSH sur la VM Master et déclenche le calcul distribué.

GREEN='\033[0;32m'
NC='\033[0m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'

MASTER_IP="34.155.93.127"
SSH_KEY="~/.ssh/id_rsa"

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}      DÉMO ORAL - ÉTAPE 3 : SOUMISSION DU JOB WORDCOUNT SPARK   ${NC}"
echo -e "${CYAN}================================================================${NC}"

echo -e "1. Connexion SSH au nœud Master GCP (${MASTER_IP})..."

# Commande spark-submit pré-configurée avec les defaults optimisés de spark-defaults.conf
SPARK_COMMAND="spark-submit \
  --class org.apache.spark.examples.JavaWordCount \
  local:///opt/spark/examples/jars/spark-examples_2.12-3.4.0.jar \
  /opt/spark/examples/src/main/resources/people.txt"

echo -e "2. Déclenchement du calcul distribué Spark sur Kubernetes...\n"
echo -e "   ${YELLOW}Vérifiez l'écran de monitoring de l'étape 2 (watch) et Grafana !${NC}"
echo -e "   -> Lancement de la commande : ${GREEN}$SPARK_COMMAND${NC}\n"

# Exécution de la commande sur le Master via SSH en forçant un login shell pour charger /etc/profile.d/spark.sh
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$MASTER_IP" "bash -l -c '$SPARK_COMMAND'"

echo -e "\n${GREEN}[SUCCÈS] Job Spark terminé.${NC}"
echo -e "Les pods exécuteurs dynamiques ont été détruits par Kubernetes pour libérer la mémoire."
echo -e "${CYAN}================================================================${NC}"
