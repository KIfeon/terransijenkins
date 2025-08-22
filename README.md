# TerransiJenkins - Laboratoires AWS avec Terraform et Jenkins

Ce projet permet de déployer et gérer des environnements de laboratoire AWS automatiquement via Jenkins et Terraform.

## Table des matières

- [Vue d'ensemble](#vue-densemble)
- [Prérequis](#prérequis)
- [Configuration Jenkins](#configuration-jenkins)
- [Déploiement d'un environnement](#déploiement-dun-environnement)
- [Destruction d'un environnement](#destruction-dun-environnement)
- [Architecture des états Terraform](#architecture-des-états-terraform)
- [Dépannage](#dépannage)

## Vue d'ensemble

Le projet comprend deux pipelines Jenkins :

1. **Pipeline de déploiement** (`Jenkinsfile`) : Crée des environnements de lab
2. **Pipeline de destruction** (job Jenkins GUI) : Détruit des environnements existants

### Ressources créées par environnement :
- **VPC** avec sous-réseaux publics et privés
- **Instance Bastion** pour l'accès SSH
- **Instances de laboratoire** (1 à 5 instances)
- **Load Balancer** (pour les rôles webserver)
- **Security Groups** adaptés au rôle
- **Clés SSH** générées automatiquement
- **Inventaire Ansible** pour la configuration

## Prérequis

### Jenkins
- Jenkins 2.x avec les plugins :
  - Pipeline
  - Git
  - Active Choices (optionnel, pour la destruction)
- Accès aux credentials AWS configurés

### Système
- Terraform >= 1.0
- AWS CLI configuré
- Ansible (pour la configuration post-déploiement)
- jq (pour le traitement JSON)

### Permissions AWS
- EC2 : création/suppression d'instances, VPC, Security Groups
- IAM : gestion des clés SSH
- ELB : création/suppression de Load Balancers

## Configuration Jenkins

### 1. Pipeline de déploiement

Créer un job **Pipeline** ou **Multibranch Pipeline** pointant vers ce repository.

### 2. Pipeline de destruction

Créer un job **Pipeline** avec les paramètres suivants :

#### Paramètre Active Choices
- **Nom** : `ENV_TO_DESTROY`
- **Type** : Active Choices Parameter
- **Script Groovy** :
```groovy
# Script 1 : Active Choices Parameter pour la liste des environnements

import java.io.File

def stateDir = "/var/lib/jenkins/terraform-states"
def envs = []

try {
    def dir = new File(stateDir)
    if (dir.exists() && dir.isDirectory()) {
        dir.listFiles().each { file ->
            if (file.isDirectory()) {
                def name = file.getName()
                // Filter out hidden directories and ensure valid names
                if (!name.startsWith('.') && name.matches(/^[a-zA-Z0-9][a-zA-Z0-9-_]*$/)) {
                    envs.add(name)
                }
            }
        }
    }
} catch (Exception e) {
    // Error handling
}

return envs.size() > 0 ? envs.sort() : ["refresh-to-see-environments"]
```

#### Script Pipeline de destruction
- **Type** : Pipeline Script
- **Script complet** :
```groovy
# Script 2 : Pipeline complet de destruction

pipeline {
    agent any
    
    environment {
        TF_DIR = './'
        TF_STATE_ROOT = '/var/lib/jenkins/terraform-states'
    }
    
    stages {
        stage('Validate Selection') {
            steps {
                script {
                    echo "Selected environment: ${params.ENV_TO_DESTROY}"
                    
                    if (params.ENV_TO_DESTROY.contains('refresh') || 
                        params.ENV_TO_DESTROY.contains('aucun') || 
                        params.ENV_TO_DESTROY.contains('environnement')) {
                        error("Please select a valid environment to destroy")
                    }
                    
                    def statePath = "${TF_STATE_ROOT}/${params.ENV_TO_DESTROY}"
                    if (!fileExists(statePath)) {
                        error("Environment '${params.ENV_TO_DESTROY}' not found at ${statePath}")
                    }
                    
                    echo "✅ Environment '${params.ENV_TO_DESTROY}' found and ready for destruction"
                }
            }
        }
        
        stage('Get Terraform Files') {
            steps {
                script {
                    git url: 'https://github.com/KIfeon/terransijenkins', branch: 'main'
                }
            }
        }
        
        stage('Terraform Init') {
            steps {
                dir("${env.TF_DIR}") {
                    sh '''
                        echo "Initializing Terraform for environment: ${ENV_TO_DESTROY}"
                        
                        rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup
                        
                        terraform init \
                          -input=false \
                          -backend-config="path=${TF_STATE_ROOT}/${ENV_TO_DESTROY}/terraform.tfstate"
                        
                        echo "✅ Terraform initialized successfully"
                    '''
                }
            }
        }
        
        stage('Terraform Destroy') {
            steps {
                dir("${env.TF_DIR}") {
                    sh '''
                        echo "=== DESTROYING ENVIRONMENT: ${ENV_TO_DESTROY} ==="
                        
                        terraform destroy -auto-approve \
                          -var="env_name=${ENV_TO_DESTROY}"
                        
                        echo "=== DESTRUCTION COMPLETED ==="
                    '''
                }
            }
        }
        
        stage('Cleanup State Directory') {
            steps {
                sh '''
                    echo "Cleaning up state directory..."
                    rm -rf "${TF_STATE_ROOT}/${ENV_TO_DESTROY}"
                    echo "State directory removed successfully"
                '''
            }
        }
    }
    
    post {
        success {
            echo "✅ DESTRUCTION RÉUSSIE pour l'environnement '${params.ENV_TO_DESTROY}'"
        }
        failure {
            echo "❌ ÉCHEC DE LA DESTRUCTION pour l'environnement '${params.ENV_TO_DESTROY}'"
        }
    }
}
```

## Déploiement d'un environnement

### Étapes

1. **Accéder au job de déploiement** dans Jenkins
2. **Cliquer sur "Build with Parameters"**
3. **Configurer les paramètres** :

### Paramètres de déploiement

| Paramètre | Description | Valeurs | Exemple |
|-----------|-------------|---------|---------|
| `ENV_NAME` | Nom de l'environnement | Lettres minuscules, chiffres, tirets (max 15 caractères) | `lab-web-01` |
| `INSTANCE_COUNT` | Nombre d'instances | 1, 2, 3, 4, 5 | `2` |
| `INSTANCE_ROLE` | Rôle des instances | `webserver`, `db`, `generic` | `webserver` |
| `INSTANCE_DISTRO` | Distribution Linux | `ubuntu`, `debian`, `amazonlinux` | `ubuntu` |
| `INSTANCE_TYPE` | Type d'instance AWS | `t3.nano`, `t3.micro`, `t3.medium` | `t3.micro` |
| `ACTION` | Action à effectuer | `deploy`, `destroy` | `deploy` |

### Impact des paramètres

#### INSTANCE_ROLE
- **webserver** : Crée un Load Balancer, ouvre les ports 80/443
- **db** : Configuration optimisée pour base de données
- **generic** : Configuration basique

#### INSTANCE_DISTRO
- **ubuntu** : Utilisateur SSH `ubuntu`
- **debian** : Utilisateur SSH `admin`
- **amazonlinux** : Utilisateur SSH `ec2-user`

### Processus de déploiement

1. **Validation** du nom d'environnement
2. **Vérification** qu'il n'existe pas déjà
3. **Initialisation Terraform** avec état local
4. **Planification et application** des ressources
5. **Génération** de l'inventaire Ansible
6. **Configuration** des instances via Ansible
7. **Affichage** des informations de connexion

### Sorties importantes

À la fin du déploiement, vous obtiendrez :
- **IP publique du Bastion**
- **IPs privées des instances**
- **Clé SSH publique**
- **Clé SSH privée** (à sauvegarder)
- **Inventaire Ansible** généré

## Destruction d'un environnement

### Étapes

1. **Accéder au job de destruction** dans Jenkins
2. **Cliquer sur "Build with Parameters"**
3. **Sélectionner l'environnement** dans la liste déroulante
4. **Lancer le build**

### Paramètres de destruction

| Paramètre | Description | Source |
|-----------|-------------|---------|
| `ENV_TO_DESTROY` | Environnement à détruire | Liste dynamique des environnements déployés |

### Processus de destruction

1. **Validation** de la sélection
2. **Récupération** des fichiers Terraform
3. **Initialisation** avec l'état de l'environnement
4. **Destruction** des ressources AWS
5. **Nettoyage** du répertoire d'état local

### Sécurité

- **Destruction immédiate** : Pas de confirmation supplémentaire
- **États isolés** : Chaque environnement a son propre état
- **Nettoyage automatique** : Suppression de l'état local après destruction

## Architecture des états Terraform

### Comment fonctionnent les états Terraform

Le projet utilise un backend local pour stocker les états Terraform dans `/var/lib/jenkins/terraform-states/`. Chaque environnement possède son propre répertoire et fichier d'état.

### Processus de création des états

#### Lors du déploiement (Jenkinsfile principal)

1. **Création du répertoire** : `mkdir -p /var/lib/jenkins/terraform-states/${ENV_NAME}`
2. **Initialisation Terraform** avec backend local :
   ```bash
   terraform init -input=false -reconfigure \
     -backend-config="path=/var/lib/jenkins/terraform-states/${ENV_NAME}/terraform.tfstate"
   ```
3. **Application des ressources** : L'état est automatiquement créé et mis à jour
4. **Persistance** : Le fichier d'état reste sur le serveur Jenkins

#### Configuration backend dans main.tf

```hcl
terraform {
  # Backend local configuré dynamiquement via -backend-config
  backend "local" {}
}
```

Le chemin exact est fourni au moment de l'exécution via le paramètre `-backend-config`.

### Structure des répertoires

```
/var/lib/jenkins/terraform-states/
├── lab-web-01/                    # Environnement 1
│   └── terraform.tfstate          # État de lab-web-01
├── lab-db-prod/                   # Environnement 2
│   └── terraform.tfstate          # État de lab-db-prod
└── test-env/                      # Environnement 3
    └── terraform.tfstate          # État de test-env
```

### Utilisation des états

#### Pipeline de déploiement
- **Vérification** : Contrôle si l'environnement existe déjà via `fileExists(statePath)`
- **Création/Mise à jour** : Terraform utilise l'état pour connaître les ressources existantes
- **Isolation** : Chaque `terraform apply` ne voit que son propre état

#### Pipeline de destruction
- **Détection automatique** : Le script Groovy scanne `/var/lib/jenkins/terraform-states/` pour lister les environnements
- **Initialisation** : `terraform init` avec le chemin de l'état spécifique
- **Destruction** : `terraform destroy` utilise l'état pour identifier les ressources à supprimer
- **Nettoyage** : Suppression du répertoire d'état après destruction

### Cycle de vie d'un état

```
1. Déploiement
   └── mkdir /var/lib/jenkins/terraform-states/ENV_NAME/
   └── terraform init -backend-config="path=.../terraform.tfstate"
   └── terraform apply (crée/met à jour l'état)

2. Utilisation
   └── L'état persiste sur le serveur Jenkins
   └── Visible dans la liste des environnements

3. Destruction
   └── terraform init -backend-config="path=.../terraform.tfstate"
   └── terraform destroy (utilise l'état pour supprimer les ressources)
   └── rm -rf /var/lib/jenkins/terraform-states/ENV_NAME/
```

### Avantages de cette approche

- **Isolation complète** : Chaque environnement est totalement indépendant
- **Simplicité** : Pas besoin de configuration S3/DynamoDB ou de verrouillage
- **Traçabilité** : Historique complet dans Jenkins
- **Sécurité** : Accès limité au serveur Jenkins uniquement
- **Performance** : Accès local plus rapide que le stockage distant
- **Coût** : Aucun coût supplémentaire AWS pour le stockage des états

## Dépannage

### Erreurs courantes

#### "Environment already exists"
```bash
# Solution : Détruire l'environnement existant ou choisir un autre nom
```

#### "Terraform init failed"
```bash
# Vérifier les permissions sur /var/lib/jenkins/terraform-states/
sudo chmod 755 /var/lib/jenkins/terraform-states/
sudo chown jenkins:jenkins /var/lib/jenkins/terraform-states/
```

#### "AWS credentials not found"
```bash
# Configurer les credentials AWS pour l'utilisateur Jenkins
aws configure
# ou configurer via variables d'environnement dans Jenkins
```

#### "Instance limit exceeded"
```bash
# Vérifier les quotas AWS dans votre région
# Réduire INSTANCE_COUNT ou changer INSTANCE_TYPE
```

### Commandes utiles

#### Lister les environnements manuellement
```bash
ls -la /var/lib/jenkins/terraform-states/
```

#### Vérifier l'état d'un environnement
```bash
cd /var/lib/jenkins/terraform-states/ENV_NAME/
terraform show
```

#### Nettoyer un environnement manuellement
```bash
# En cas de problème avec le pipeline de destruction
cd /path/to/terraform/files
terraform init -backend-config="path=/var/lib/jenkins/terraform-states/ENV_NAME/terraform.tfstate"
terraform destroy -var="env_name=ENV_NAME"
rm -rf /var/lib/jenkins/terraform-states/ENV_NAME/
```

### Scripts utiles

Le projet inclut `scripts/list-labs.sh` pour lister les environnements via AWS CLI.

## Support

En cas de problème :

1. **Vérifier les logs** Jenkins pour l'erreur exacte
2. **Consulter la section dépannage** ci-dessus
3. **Vérifier les quotas AWS** et permissions
4. **Tester manuellement** les commandes Terraform

## Exemple complet

### Déploiement d'un serveur web

1. **Paramètres** :
   - ENV_NAME: `lab-web-demo`
   - INSTANCE_COUNT: `2`
   - INSTANCE_ROLE: `webserver`
   - INSTANCE_DISTRO: `ubuntu`
   - INSTANCE_TYPE: `t3.micro`
   - ACTION: `deploy`

2. **Résultat** : 2 instances Ubuntu avec Load Balancer

3. **Destruction** : Sélectionner `lab-web-demo` dans le job de destruction

---

**Profitez de vos laboratoires AWS automatisés !**