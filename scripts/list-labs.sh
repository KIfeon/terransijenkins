#!/bin/bash
#
# Script pour lister tous les labs existants créés avec Terraform
# Utilise les tags AWS pour identifier les environnements de lab
#

set -e

AWS_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

echo "=== RECHERCHE DES LABS EXISTANTS ==="
echo "Région AWS: $AWS_REGION"
echo ""

# Fonction pour afficher les détails d'un lab
show_lab_details() {
    local lab_name="$1"
    echo "🧪 Lab: $lab_name"
    
    # VPC
    vpc_id=$(aws ec2 describe-vpcs \
        --region "$AWS_REGION" \
        --filters "Name=tag:Environment,Values=$lab_name" \
        --query 'Vpcs[0].VpcId' \
        --output text 2>/dev/null || echo "N/A")
    echo "   VPC ID: $vpc_id"
    
    # Instances EC2 actives
    instances=$(aws ec2 describe-instances \
        --region "$AWS_REGION" \
        --filters "Name=tag:Environment,Values=$lab_name" "Name=instance-state-name,Values=running,stopped,stopping,pending" \
        --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name]' \
        --output text 2>/dev/null | wc -l)
    echo "   Instances actives: $instances"
    
    # Load Balancer
    alb_count=$(aws elbv2 describe-load-balancers \
        --region "$AWS_REGION" \
        --query "LoadBalancers[?contains(LoadBalancerName, '$lab_name')]" \
        --output text 2>/dev/null | wc -l)
    echo "   Load Balancers: $alb_count"
    
    # Clé SSH
    key_exists=$(aws ec2 describe-key-pairs \
        --region "$AWS_REGION" \
        --key-names "$lab_name-key" \
        --query 'KeyPairs[0].KeyName' \
        --output text 2>/dev/null || echo "Aucune")
    echo "   Clé SSH: $key_exists"
    echo ""
}

# Méthode 1: Recherche via les tags Environment des VPCs
echo "📍 Méthode 1: Recherche via les tags VPC..."
labs_from_vpcs=$(aws ec2 describe-vpcs \
    --region "$AWS_REGION" \
    --filters "Name=tag:Environment,Values=*" \
    --query 'Vpcs[?contains(Tags[?Key==`Environment`].Value, `lab`)].Tags[?Key==`Environment`].Value' \
    --output text | tr '\t' '\n' | sort -u | grep -v '^$' || true)

if [ -n "$labs_from_vpcs" ]; then
    echo "Labs trouvés via VPC tags:"
    echo "$labs_from_vpcs" | while read -r lab; do
        [ -n "$lab" ] && show_lab_details "$lab"
    done
else
    echo "Aucun lab trouvé via les tags VPC"
fi

echo "🔑 Méthode 2: Recherche via les clés SSH..."
labs_from_keys=$(aws ec2 describe-key-pairs \
    --region "$AWS_REGION" \
    --query 'KeyPairs[?contains(KeyName, `lab`)].KeyName' \
    --output text | tr '\t' '\n' | sed 's/-key$//' | sort -u | grep -v '^$' || true)

if [ -n "$labs_from_keys" ]; then
    echo "Labs trouvés via clés SSH:"
    echo "$labs_from_keys" | while read -r lab; do
        [ -n "$lab" ] && show_lab_details "$lab"
    done
else
    echo "Aucun lab trouvé via les clés SSH"
fi

# Méthode 3: Recherche via les instances avec tag Environment
echo "🖥️ Méthode 3: Recherche via les instances EC2..."
labs_from_instances=$(aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --filters "Name=tag:Environment,Values=*" "Name=instance-state-name,Values=running,stopped,stopping,pending" \
    --query 'Reservations[].Instances[].Tags[?Key==`Environment`].Value' \
    --output text | tr '\t' '\n' | grep lab | sort -u | grep -v '^$' || true)

if [ -n "$labs_from_instances" ]; then
    echo "Labs trouvés via instances EC2:"
    echo "$labs_from_instances" | while read -r lab; do
        [ -n "$lab" ] && show_lab_details "$lab"
    done
else
    echo "Aucun lab trouvé via les instances EC2"
fi

# Résumé global
echo "=== RÉSUMÉ ==="
all_labs=$(printf "%s\n%s\n%s" "$labs_from_vpcs" "$labs_from_keys" "$labs_from_instances" | sort -u | grep -v '^$' || true)

if [ -n "$all_labs" ]; then
    echo "✅ Labs découverts au total:"
    echo "$all_labs" | while read -r lab; do
        [ -n "$lab" ] && echo "  - $lab"
    done
    echo ""
    echo "💡 Pour détruire un lab, utilisez le pipeline Jenkins 'Destroy Lab'"
    echo "   ou lancez manuellement:"
    echo "   terraform destroy -var='env_name=NOM_DU_LAB' ..."
else
    echo "❌ Aucun lab trouvé dans la région $AWS_REGION"
    echo ""
    echo "💡 Vérifiez:"
    echo "  - Que vous êtes connecté au bon compte AWS"
    echo "  - Que la région est correcte: $AWS_REGION"
    echo "  - Que des labs ont bien été créés avec ce repository"
fi
