# 🧪 Quick Reference - Destruction des Labs

## 🚀 Pipeline Jenkins - Étapes Rapides

### 1️⃣ Scanner les Labs
```
LAB_TO_DESTROY: SCAN_FOR_LABS
FORCE_DESTROY: false  
DRY_RUN: true
→ Build
```

### 2️⃣ Simuler la Destruction
```
LAB_TO_DESTROY: [choisir dans la liste]
FORCE_DESTROY: false
DRY_RUN: true
→ Build
```

### 3️⃣ Détruire Réellement
```
LAB_TO_DESTROY: [même lab qu'étape 2]
FORCE_DESTROY: false
DRY_RUN: false
→ Build
```

### 🔨 Mode Force (si problème)
```
LAB_TO_DESTROY: [lab problématique]
FORCE_DESTROY: true
DRY_RUN: false
→ Build
```

## 🛠️ Commandes Manuelles

### Lister les Labs
```bash
./scripts/list-labs.sh
```

### Destruction Terraform Directe
```bash
terraform destroy -auto-approve \
  -var='env_name=LAB_NAME' \
  -var='instance_count=2' \
  -var='instance_role=webserver' \
  -var='instance_distribution=ubuntu' \
  -var='instance_type=t3.micro'
```

### Nettoyage AWS d'Urgence
```bash
LAB="lab-demo"

# Instances
aws ec2 describe-instances --filters "Name=tag:Environment,Values=$LAB" --query 'Reservations[].Instances[].InstanceId' --output text | xargs -r aws ec2 terminate-instances --instance-ids

# Clé SSH
aws ec2 delete-key-pair --key-name "$LAB-key"

# VPC (après instances supprimées)
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Environment,Values=$LAB" --query 'Vpcs[0].VpcId' --output text)
aws ec2 delete-vpc --vpc-id $VPC_ID
```

## ⚠️ Codes d'Erreur Courants

| Message | Action |
|---------|--------|
| `Le lab 'x' n'existe pas` | Re-scanner les labs |
| `Des ressources persistent` | Utiliser FORCE_DESTROY |
| `AccessDenied` | Vérifier permissions AWS |
| `VPC has dependencies` | Attendre ou nettoyage manuel |

## 📋 Checklist de Destruction

- [ ] Scanner les labs existants
- [ ] DRY RUN sur le lab cible
- [ ] Vérifier qu'aucune donnée importante
- [ ] Destruction réelle
- [ ] Vérifier suppression complète
- [ ] Contrôler coûts AWS

---
📖 **Guide complet**: [DESTROY-LABS.md](./DESTROY-LABS.md)
