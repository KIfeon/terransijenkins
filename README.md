# TerransiJenkins - Laboratoires AWS automatisés avec Terraform et Jenkins

Déployez et gérez facilement des environnements de laboratoire AWS via Jenkins et Terraform.

## Vue d'ensemble

Ce projet propose deux pipelines Jenkins :
- **Déploiement** (`Jenkinsfile`) : crée un lab (VPC, bastion, instances, load balancer, clés SSH, inventaire Ansible, etc.).
- **Destruction** (job dédié) : supprime un environnement déployé.

## Utilisation rapide

### Déploiement d’un environnement

1. Lancez le pipeline de déploiement dans Jenkins.
2. Renseignez les paramètres principaux :
    - `ENV_NAME` : nom court de l’environnement (ex: `lab-web-01`)
    - `INSTANCE_COUNT` : nombre d’instances (1-5)
    - `INSTANCE_ROLE` : `webserver`, `db`, `generic`
    - `INSTANCE_DISTRO` : `ubuntu`, `debian`, `amazonlinux`
    - `INSTANCE_TYPE` : (ex. `t3.micro`)
3. Exécutez. En fin de déploiement, consultez la console Jenkins pour :
    - IPs (bastion + instances)
    - Clés SSH générées
    - Inventaire Ansible prêt à l'emploi

### Destruction d’un environnement

1. Lancez le job de destruction.
2. Sélectionnez l’environnement à détruire dans la liste.
3. Exécutez. Tous les composants AWS du lab seront supprimés et l’état local nettoyé.

## Architecture des états Terraform

- Chaque environnement a son propre répertoire d’état local (ex: `/var/lib/jenkins/terraform-states/LAB_NAME/terraform.tfstate`).
- Le job de destruction liste dynamiquement les états existants.
- Tout est stocké localement sur le serveur Jenkins pour plus de simplicité.

## Dépannage & Support

- Consultez les logs Jenkins en cas de problème.
- Vérifiez les droits sur par exemple `/var/lib/jenkins/terraform-states/` si besoin.
- Les environnements peuvent être listés/nettoyés manuellement en cas de besoin.

## Exemple

Pour créer un lab web :
- `ENV_NAME`: `lab-web-demo`
- `INSTANCE_COUNT`: `2`
- `INSTANCE_ROLE`: `webserver`
- etc.
- Détruisez-le ensuite via le job approprié.

---
