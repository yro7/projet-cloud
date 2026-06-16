#!/bin/bash
# Script de Démo Oral - Étape 1 : Tunnel vers le Dashboard Grafana
# Ce script lance le port-forward vers Grafana et fournit les accès.

# Définition des couleurs pour l'affichage terminal
GREEN='\033[0;32m'
NC='\033[0m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'

KUBECONFIG_PATH="/Users/marin.decanini/.kube/config-projet-cloud"

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}    DÉMO ORAL - ÉTAPE 1 : ACTIVATION DU MONITORING (GRAFANA)     ${NC}"
echo -e "${CYAN}================================================================${NC}"

# Vérification du fichier kubeconfig
if [ ! -f "$KUBECONFIG_PATH" ]; then
    echo -e "${YELLOW}[ERREUR] Le fichier de configuration Kubernetes local est introuvable à l'adresse : $KUBECONFIG_PATH${NC}"
    exit 1
fi

echo -e "\n1. Récupération du Pod Grafana..."
POD_NAME=$(kubectl --kubeconfig="$KUBECONFIG_PATH" --namespace monitoring get pod -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=kube-prometheus" -o jsonpath="{.items[0].metadata.name}")

if [ -z "$POD_NAME" ]; then
    echo -e "${YELLOW}[ERREUR] Aucun pod Grafana détecté dans le namespace 'monitoring'. Vérifiez le cluster.${NC}"
    exit 1
fi
echo -e "   -> Pod Grafana identifié : ${GREEN}$POD_NAME${NC}"

# Tuer les anciens tunnels port-forward résiduels
echo -e "\n2. Nettoyage des anciens tunnels port-forward..."
pkill -f "port-forward.*3000" && echo "   -> Ancien tunnel fermé." || echo "   -> Aucun tunnel résiduel actif."

echo -e "\n3. Démarrage du tunnel de port-forwarding (Port 3000)..."
kubectl --kubeconfig="$KUBECONFIG_PATH" --namespace monitoring port-forward "$POD_NAME" 3000:3000 > /dev/null 2>&1 &
PORT_FORWARD_PID=$!

# Laisser le temps au tunnel de s'ouvrir
sleep 3

# Vérification de l'état du processus en arrière-plan
if ps -p $PORT_FORWARD_PID > /dev/null; then
    echo -e "   -> ${GREEN}Tunnel établi avec succès ! (PID: $PORT_FORWARD_PID)${NC}"
else
    echo -e "   -> ${YELLOW}[ERREUR] Le tunnel n'a pas pu démarrer. Vérifiez les accès réseau.${NC}"
    exit 1
fi

echo -e "\n${CYAN}================================================================${NC}"
echo -e "   ${YELLOW}ACCÈS AU DASHBOARD GRAFANA :${NC}"
echo -e "   🌐 URL : ${GREEN}http://localhost:3000${NC}"
echo -e "   👤 User : ${GREEN}admin${NC}"
echo -e "   🔑 Pass : ${GREEN}admin${NC}"
echo -e "${CYAN}================================================================${NC}"
echo -e "   ${YELLOW}Dashboards recommandés pour la démo Spark :${NC}"
echo -e "   - Kubernetes / Compute Resources / Namespace (Pods)$"
echo -e "   - Kubernetes / Compute Resources / Node (Pods)$"
echo -e "${CYAN}================================================================${NC}"

echo -e "\nOuverture automatique du navigateur sur Grafana..."
open "http://localhost:3000"

# Maintenir le script actif pour pouvoir fermer proprement le tunnel à la fin
echo -e "\n${YELLOW}Appuyez sur [ENTRÉE] ou [CTRL+C] pour couper le tunnel et terminer l'étape 1...${NC}"
read -r
kill $PORT_FORWARD_PID
echo -e "Tunnel Grafana fermé. Fin de l'étape 1."
