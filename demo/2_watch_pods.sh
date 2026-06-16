#!/bin/bash
# Script de Démo Oral - Étape 2 : Surveillance en direct des Pods Kubernetes
# Ce script affiche la création et destruction dynamique des exécuteurs Spark en temps réel.

GREEN='\033[0;32m'
NC='\033[0m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'

KUBECONFIG_PATH="/Users/marin.decanini/.kube/config-projet-cloud"

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}   DÉMO ORAL - ÉTAPE 2 : MONITORING TEMPS RÉEL DES PODS K8S     ${NC}"
echo -e "${CYAN}================================================================${NC}"

if [ ! -f "$KUBECONFIG_PATH" ]; then
    echo -e "${YELLOW}[ERREUR] Le fichier de configuration Kubernetes local est introuvable.${NC}"
    exit 1
fi

echo -e "${YELLOW}Ce terminal doit rester affiché sur votre écran scindé lors de la démo.${NC}"
echo -e "Il affichera les Pods Exécuteurs Spark dès que vous soumettrez le job WordCount."
echo -e "Appuyez sur [CTRL+C] pour quitter la surveillance.\n"

# Commande de watch
kubectl --kubeconfig="$KUBECONFIG_PATH" get pods -w -n default
