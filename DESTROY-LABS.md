# 🧪 Guide de Destruction des Labs

Ce guide explique comment utiliser le nouveau pipeline Jenkins pour lister et détruire les labs existants créés avec ce repository Terraform.

## 📋 Vue d'ensemble

Le pipeline `Jenkinsfile-destroy-lab` permet de :
- 🔍 **Scanner automatiquement** les labs existants dans AWS
- 📝 **Lister tous les labs** avec leurs détails (instances, VPC, ALB, clés SSH)
- 🎯 **Sélectionner un lab** via une liste déroulante
- 🧪 **Tester la destruction** en mode DRY RUN (simulation)
- 💥 **Détruire complètement** un lab sélectionné
- 🔨 **Forcer la suppression** en cas de ressources persistantes

## 🚀 Utilisation du Pipeline Jenkins

### Étape 1: Scan des Labs Existants

1. **Lancez le pipeline** `Jenkinsfile-destroy-lab`
2. **Laissez les paramètres par défaut** :
   - `LAB_TO_DESTROY`: `SCAN_FOR_LABS`
   - `FORCE_DESTROY`: `false`
   - `DRY_RUN`: `true`
3. **Cliquez sur "Build"**

Le pipeline va scanner AWS et afficher tous les labs trouvés avec leurs détails.

### Étape 2: Sélection et Destruction

1. **Relancez le pipeline** après le scan
2. **Configurez les paramètres** :
   - `LAB_TO_DESTROY`: Sélectionnez le lab à détruire dans la liste
   - `DRY_RUN`: 
     - `true` = Simulation (recommandé d'abord)
     - `false` = Destruction réelle
   - `FORCE_DESTROY`: 
     - `false` = Arrêt en cas d'erreur
     - `true` = Tentative de nettoyage forcé

### Exemple de Workflow Complet

```
1. Premier run: SCAN_FOR_LABS (découverte)
   ↓
2. Deuxième run: LAB_TO_DESTROY="lab-demo", DRY_RUN=true (simulation)
   ↓
3. Troisième run: LAB_TO_DESTROY="lab-demo", DRY_RUN=false (destruction)
```

## 🔧 Paramètres du Pipeline

| Paramètre | Valeurs | Description |
|-----------|---------|-------------|
| `LAB_TO_DESTROY` | `SCAN_FOR_LABS` ou nom de lab | Lab à détruire ou scan initial |
| `FORCE_DESTROY` | `true`/`false` | Force la suppression même en cas d'erreur |
| `DRY_RUN` | `true`/`false` | Mode simulation (true) ou destruction réelle (false) |

## 📊 Étapes du Pipeline

### 1. Discovery (Découverte)
- Scan des VPCs avec tags `Environment`
- Recherche des clés SSH avec pattern `*lab*`
- Affichage des détails de chaque lab trouvé

### 2. Validation
- Vérification que le lab sélectionné existe
- Confirmation des ressources à détruire

### 3. Plan de Destruction
- Liste détaillée des ressources qui seront supprimées :
  - Instances EC2 (avec types et états)
  - VPC et composants (subnets, security groups)
  - Load Balancers et Target Groups
  - Clés SSH AWS

### 4. Destruction Terraform
- Tentative avec `terraform destroy`
- Essaie plusieurs combinaisons de paramètres si nécessaire
- Mode force avec paramètres communs

### 5. Nettoyage AWS Direct (mode force)
- Suppression directe via AWS CLI si Terraform échoue
- Ordre de suppression :
  1. Instances EC2
  2. Load Balancers et Target Groups
  3. Security Groups
  4. Clés SSH
  5. Subnets et Route Tables
  6. Internet Gateways
  7. VPC

### 6. Vérification
- Contrôle que toutes les ressources ont été supprimées
- Rapport final des ressources persistantes

## 🛠️ Utilisation Manuelle (Alternative)

### Script de Découverte

```bash
# Lister tous les labs existants
./scripts/list-labs.sh
```

### Destruction Manuelle via Terraform

```bash
# Méthode 1: Avec paramètres connus
terraform destroy -auto-approve \
    -var='env_name=lab-demo' \
    -var='instance_count=2' \
    -var='instance_role=webserver' \
    -var='instance_distribution=ubuntu' \
    -var='instance_type=t3.micro'

# Méthode 2: Avec le pipeline original (ACTION=destroy)
# Utiliser le Jenkinsfile principal avec ACTION=destroy
```

### Nettoyage AWS Direct

```bash
# Variables
LAB_NAME="lab-demo"
AWS_REGION="us-east-1"

# Instances
aws ec2 describe-instances --filters "Name=tag:Environment,Values=$LAB_NAME" --query 'Reservations[].Instances[].InstanceId' --output text | xargs -r aws ec2 terminate-instances --instance-ids

# VPC et composants
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Environment,Values=$LAB_NAME" --query 'Vpcs[0].VpcId' --output text)
# ... puis supprimer subnets, security groups, etc.

# Clé SSH
aws ec2 delete-key-pair --key-name "$LAB_NAME-key"
```

## ⚠️ Bonnes Pratiques

### Avant la Destruction
1. **Toujours commencer par un DRY RUN** pour voir ce qui sera supprimé
2. **Vérifier que c'est le bon lab** - pas de retour en arrière possible
3. **S'assurer qu'aucune donnée importante** n'est stockée sur les instances
4. **Vérifier les dépendances** avec d'autres systèmes

### Pendant la Destruction
1. **Surveiller les logs** Jenkins pour détecter les erreurs
2. **Ne pas interrompre** le processus une fois lancé
3. **Utiliser FORCE_DESTROY** seulement si nécessaire

### Après la Destruction
1. **Vérifier le rapport final** - toutes les ressources supprimées ?
2. **Contrôler la console AWS** pour s'assurer de la propreté
3. **Vérifier les coûts AWS** - plus de facturation pour ce lab

## 🚨 Résolution de Problèmes

### Lab Non Trouvé
```
❌ Le lab 'lab-xxx' n'existe pas ou a déjà été détruit
```
**Solution**: Relancer le scan pour voir les labs disponibles

### Ressources Persistantes
```
⚠️ Des ressources persistent dans le state Terraform
```
**Solutions**:
1. Relancer avec `FORCE_DESTROY=true`
2. Utiliser le nettoyage AWS direct
3. Supprimer manuellement via la console AWS

### Terraform Échoue
```
⚠️ Erreur Terraform: [détails de l'erreur]
```
**Solutions**:
1. Vérifier les permissions AWS
2. Activer `FORCE_DESTROY` pour le nettoyage direct
3. Utiliser les scripts manuels

### Permissions AWS Insuffisantes
```
AccessDenied: User is not authorized
```
**Solution**: Vérifier que Jenkins a les permissions AWS nécessaires :
- EC2 (instances, VPC, security groups)
- ELB (load balancers, target groups)
- IAM (pour les clés SSH)

## 📝 Logs et Debugging

### Logs Importants
- **Discovery**: Liste des labs trouvés
- **Validation**: Confirmation du lab sélectionné
- **Plan**: Ressources qui seront supprimées
- **Terraform**: Sortie de `terraform destroy`
- **AWS Cleanup**: Résultats du nettoyage direct
- **Verification**: Rapport final

### Commandes de Debug
```bash
# Vérifier les ressources restantes
aws ec2 describe-instances --filters "Name=tag:Environment,Values=LAB_NAME"
aws ec2 describe-vpcs --filters "Name=tag:Environment,Values=LAB_NAME"
aws ec2 describe-key-pairs --key-names "LAB_NAME-key"

# Vérifier l'état Terraform
terraform show
terraform state list
```

## 🔄 Workflow Recommandé

1. **Développement/Test** :
   ```
   Création lab → Tests → DRY RUN destruction → Destruction réelle
   ```

2. **Production** :
   ```
   Scan périodique → Identification labs obsolètes → DRY RUN → Destruction
   ```

3. **Urgence** :
   ```
   Scan → Sélection → FORCE_DESTROY + Nettoyage direct
   ```

---

💡 **Astuce**: Gardez ce guide à portée de main lors des opérations de destruction de labs !
