#!/bin/bash
# Script de Démo Oral - Étape 5 : WordCount distribué sur un VRAI HDFS
# Le fichier d'entrée n'est plus embarqué dans l'image : il est stocké dans HDFS,
# réparti en blocs sur les DataNodes (workers). Chaque executor lit les blocs
# (idéalement locaux) via le NameNode. Vraie donnée distribuée.

GREEN='\033[0;32m'
NC='\033[0m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'

MASTER_IP="34.155.93.127"
MASTER_INTERNAL_IP="10.0.1.10"   # NameNode HDFS + driver Spark
SSH_KEY="~/.ssh/id_rsa"

HDFS_INPUT="hdfs://${MASTER_INTERNAL_IP}:9000/data/input/big.txt"

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}   DÉMO ORAL - ÉTAPE 5 : WORDCOUNT SUR HDFS DISTRIBUÉ           ${NC}"
echo -e "${CYAN}================================================================${NC}"

echo -e "1. Connexion SSH au nœud Master GCP (${MASTER_IP})..."
echo -e "2. Lecture du fichier depuis HDFS : ${HDFS_INPUT}\n"
echo -e "   ${YELLOW}Le fichier est réparti en blocs sur les 2 DataNodes (workers).${NC}"
echo -e "   ${YELLOW}Les executors lisent les blocs via le NameNode (data locality).${NC}\n"

# Astuce démo : afficher d'abord l'état HDFS, puis lancer le job.
SPARK_COMMAND="echo '=== Etat du cluster HDFS ==='; \
  /opt/hadoop/bin/hdfs dfsadmin -report | grep -E 'Live datanodes|Name|DFS Used%|Hostname'; \
  echo '=== Repartition des blocs du fichier ==='; \
  /opt/hadoop/bin/hdfs fsck /data/input/big.txt -files -blocks -locations 2>/dev/null | grep -E 'len=|Total blocks'; \
  echo '=== Lancement du WordCount Spark sur HDFS ==='; \
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
    ${HDFS_INPUT}"

ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@"$MASTER_IP" "bash -l -c '$SPARK_COMMAND'"

echo -e "\n${GREEN}[SUCCÈS] WordCount terminé en lisant les données depuis HDFS.${NC}"
echo -e "Données servies par les DataNodes, pas par l'image du conteneur."
echo -e "${CYAN}================================================================${NC}"
