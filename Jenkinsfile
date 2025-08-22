pipeline {
    agent any

    parameters {
        string(name: 'ENV_NAME', defaultValue: 'lab-demo', description: 'Nom de l environnement Lab')
        choice(name: 'INSTANCE_COUNT', choices: ['1','2','3','4','5'], description: 'Nombre d instances')
        choice(name: 'INSTANCE_ROLE', choices: ['webserver','db','generic'], description: 'Rôle')
        choice(name: 'INSTANCE_DISTRO', choices: ['ubuntu','debian','amazonlinux'], description: 'Distribution')
        choice(name: 'INSTANCE_TYPE', choices: ['t3.nano','t3.micro','t3.medium'], description: 'Instance type')
        choice(name: 'ACTION', choices: ['deploy','destroy'], description: 'Déployer ou Nettoyer ?')
    }

    environment {
        TF_VAR_env_name              = "${params.ACTION == 'destroy' && params.LAB_TO_DESTROY?.trim() ? params.LAB_TO_DESTROY : params.ENV_NAME}"
        TF_VAR_instance_count        = "${params.INSTANCE_COUNT}"
        TF_VAR_instance_role         = "${params.INSTANCE_ROLE}"
        TF_VAR_instance_distribution = "${params.INSTANCE_DISTRO}"
        TF_VAR_instance_type         = "${params.INSTANCE_TYPE}"
        TF_ACTION                    = "${params.ACTION}"
        TF_DIR                       = './'
    }

    stages {
        stage('Configure Job Parameters') {
            steps {
                script {
                    properties([
                        parameters([
                            string(name: 'ENV_NAME', defaultValue: 'lab-demo', description: 'Nom de l environnement Lab'),
                            choice(name: 'INSTANCE_COUNT', choices: ['1','2','3','4','5'], description: 'Nombre d instances'),
                            choice(name: 'INSTANCE_ROLE', choices: ['webserver','db','generic'], description: 'Rôle'),
                            choice(name: 'INSTANCE_DISTRO', choices: ['ubuntu','debian','amazonlinux'], description: 'Distribution'),
                            choice(name: 'INSTANCE_TYPE', choices: ['t3.nano','t3.micro','t3.medium'], description: 'Instance type'),
                            choice(name: 'ACTION', choices: ['deploy','destroy'], description: 'Déployer ou Nettoyer ?'),
                            [$class: 'org.biouno.unochoice.DynamicChoiceParameter',
                              description: 'Sélectionnez un lab existant à détruire',
                              name: 'LAB_TO_DESTROY',
                              randomName: 'choice-parameter-labs',
                              choiceType: 'PT_SINGLE_SELECT',
                              filterable: true,
                              script: [
                                $class: 'org.biouno.unochoice.model.GroovyScript',
                                sandbox: true,
                                script: '''
import jenkins.model.Jenkins

def job = Jenkins.instance.getItemByFullName(JOB_NAME)
if (job == null) return ["(aucun)"]
def build = job.getLastSuccessfulBuild() ?: job.getLastBuild()
def ws = build?.workspace
if (ws == null) return ["(aucun)"]
def stateDir = ws.child('terraform.tfstate.d')
if (!stateDir.exists()) return ["(aucun)"]
def items = stateDir.list().findAll { it.isDirectory() }.collect { it.name }.sort()
return items ?: ["(aucun)"]
''',
                                fallbackScript: 'return ["(aucun)"]'
                              ]
                            ]
                        ])
                    ])
                }
            }
        }
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Validate ENV_NAME') {
            steps {
                script {
                    if (!env.TF_VAR_env_name.matches('^[a-z0-9-]+$')) {
                        error """
Le nom d'environnement (ENV_NAME = '${env.TF_VAR_env_name}') contient des caractères non autorisés !
Utilisez uniquement des lettres minuscules (a-z), des chiffres (0-9) et le tiret (-).
"""
                    }
                    if (env.TF_VAR_env_name.length() > 15) {
                        error """
Le nom d'environnement (ENV_NAME = '${env.TF_VAR_env_name}') est trop long (${env.TF_VAR_env_name.length()} caractères).
La longueur maximale autorisée est de 15 caractères.
"""
                    }
                }
            }
        }

        stage('Check if Lab Name Already Exists') {
            when {
                expression { params.ACTION == 'deploy' }
            }
            steps {
                script {
                    // Vérifie si le fichier de state local existe déjà
                    def statePath = "./terraform.tfstate.d/${env.TF_VAR_env_name}/terraform.tfstate"
                    if (fileExists(statePath)) {
                        error """
Un lab avec ce nom ('${env.TF_VAR_env_name}') existe déjà (state: ${statePath}).
Veuillez choisir un autre nom ou détruire d'abord l'environnement existant.
"""
                    }
                }
            }
        }

        stage('Terraform Init') {
            steps {
                dir("${env.TF_DIR}") {
                    sh 'terraform init'
                }
            }
        }
        stage('Terraform Plan & Apply/Destroy') {
            steps {
                dir("${env.TF_DIR}") {
                    script {
                        if (env.TF_ACTION == "deploy") {
                            sh """
                                terraform plan -out=tfplan \
                                    -var='env_name=$TF_VAR_env_name' \
                                    -var='instance_count=$TF_VAR_instance_count' \
                                    -var='instance_role=$TF_VAR_instance_role' \
                                    -var='instance_distribution=$TF_VAR_instance_distribution' \
                                    -var='instance_type=$TF_VAR_instance_type'

                                terraform apply -auto-approve tfplan
                                sleep 30
                            """
                        } else {
                            sh """
                                echo "=== Starting DESTROY for environment: $TF_VAR_env_name ==="

                                terraform plan -destroy \
                                    -var='env_name=$TF_VAR_env_name' \
                                    -var='instance_count=$TF_VAR_instance_count' \
                                    -var='instance_role=$TF_VAR_instance_role' \
                                    -var='instance_distribution=$TF_VAR_instance_distribution' \
                                    -var='instance_type=$TF_VAR_instance_type'

                                echo "=== Executing DESTROY ==="
                                terraform destroy -auto-approve \
                                    -var='env_name=$TF_VAR_env_name' \
                                    -var='instance_count=$TF_VAR_instance_count' \
                                    -var='instance_role=$TF_VAR_instance_role' \
                                    -var='instance_distribution=$TF_VAR_instance_distribution' \
                                    -var='instance_type=$TF_VAR_instance_type'

                                echo "=== DESTROY completed for environment: $TF_VAR_env_name ==="
                            """
                        }
                    }
                }
            }
        }
        stage('Generate Ansible Inventory') {
            when { expression { env.TF_ACTION == "deploy" } }
            steps {
                sh '''
                terraform output -json > tf_outputs.json
                bastion_ip=$(jq -r .bastion_public_ip.value tf_outputs.json)
                instance_ips=$(jq -r .lab_public_ips.value[] tf_outputs.json)
                role_lower=$(echo "$TF_VAR_instance_role" | tr '[:upper:]' '[:lower:]')
                host_base="${TF_VAR_env_name}-${role_lower}"
                case "$TF_VAR_instance_distribution" in
                  amazonlinux) inst_user=ec2-user ; bastion_user=ec2-user ;;
                  debian) inst_user=admin ; bastion_user=admin ;;
                  *) inst_user=ubuntu ; bastion_user=ubuntu ;;
                esac
                echo "[targets]" > ansible_inventory.ini
                echo "${TF_VAR_env_name}-bastion ansible_host=$bastion_ip ansible_user=$bastion_user" >> ansible_inventory.ini
                echo "" >> ansible_inventory.ini
                case "$TF_VAR_instance_role" in
                  db) group_name="dbservers" ;;
                  webserver) group_name="webservers" ;;
                  *) group_name="generic" ;;
                esac
                echo "[$group_name]" >> ansible_inventory.ini
                i=1
                for ip in $instance_ips; do
                  if [ "$ip" != "null" ] && [ -n "$ip" ]; then
                    echo "${host_base}-${i} ansible_host=$ip ansible_user=$inst_user" >> ansible_inventory.ini
                    i=$((i+1))
                  fi
                done
                '''
            }
        }
        stage('Write Ansible SSH Key') {
            when { expression { env.TF_ACTION == "deploy" } }
            steps {
                sh '''
                terraform output -raw ssh_private_key_pem > lab_rsa.pem
                chmod 600 lab_rsa.pem
                '''
            }
        }
        stage('Ansible - Copy SSH Key') {
            when { expression { env.TF_ACTION == "deploy" } }
            steps {
                sh 'ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i ansible_inventory.ini ansible_playbook.yml --private-key lab_rsa.pem --timeout 60'
            }
        }
        stage('Afficher infos Lab & clé SSH') {
            when { expression { env.TF_ACTION == "deploy" } }
            steps {
                dir("${env.TF_DIR}") {
                    script {
                        echo "========== INFOS LAB ==========="
                    }
                    sh '''
                        echo "IP publique Bastion:"
                        terraform output bastion_public_ip

                        echo "IPs privées des instances LAB :"
                        terraform output lab_private_ips

                        echo "Clé publique SSH :"
                        terraform output ssh_public_key

                        echo "=== Clé privée SSH à copier dans un fichier lab_rsa.pem (chmod 600):"
                        terraform output ssh_private_key_pem
                    '''
                }
            }
        }
        stage('Cleanup Generated Files') {
            when { expression { env.TF_ACTION == "destroy" } }
            steps {
                script {
                    echo "=== Cleaning up generated files for environment: ${env.TF_VAR_env_name} ==="
                }
                sh '''
                    rm -f tf_outputs.json
                    rm -f ansible_inventory.ini
                    rm -f lab_rsa.pem
                    rm -f tfplan
                    echo "Generated files cleaned up successfully"
                '''
            }
        }
        stage('Verify Destroy Completion') {
            when { expression { env.TF_ACTION == "destroy" } }
            steps {
                dir("${env.TF_DIR}") {
                    script {
                        echo "=== Verifying all resources destroyed for environment: ${env.TF_VAR_env_name} ==="
                    }
                    sh '''
                        if ! terraform show | grep -q "resource"; then
                            echo "SUCCESS: No resources found in terraform state"
                        else
                            echo "WARNING: Some resources may still exist in state!"
                            terraform show
                            exit 1
                        fi

                        if [ -f terraform.tfstate ]; then
                            echo "State file contents:"
                            cat terraform.tfstate | jq '.resources // []' | head -10
                        fi
                    '''
                }
            }
        }
    }
    post {
        always {
            script {
                echo "========== RÉSUMÉ DES OPÉRATIONS =========="
                echo "Environnement : ${env.TF_VAR_env_name}"
                echo "Action : ${params.ACTION}"
                if (params.ACTION == "destroy") {
                    echo "=== RÉSUMÉ DE LA DESTRUCTION ==="
                    echo "Toutes les ressources pour l'environnement '${env.TF_VAR_env_name}' ont été détruites :"
                    echo "- Instances EC2 (${env.TF_VAR_instance_count} × ${env.TF_VAR_instance_type})"
                    echo "- Bastion host"
                    echo "- VPC et sous-réseaux"
                    echo "- Security Groups"
                    echo "- Application Load Balancer (si webserver)"
                    echo "- Target Groups (si webserver)"
                    echo "- Clés SSH AWS"
                                        echo "- Fichiers générés locaux (inventory, clés privées, etc.)"
                    echo "=========================================="
                }
            }
        }
        success {
            script {
                if (params.ACTION == "destroy") {
                    echo "✅ DESTRUCTION RÉUSSIE pour l'environnement '${env.TF_VAR_env_name}'"
                } else {
                    echo "✅ DÉPLOIEMENT RÉUSSI pour l'environnement '${env.TF_VAR_env_name}'"
                }
            }
        }
        failure {
            script {
                if (params.ACTION == "destroy") {
                    echo "❌ ÉCHEC DE LA DESTRUCTION pour l'environnement '${env.TF_VAR_env_name}'"
                    echo "Vérifiez manuellement l'état des ressources AWS"
                } else {
                    echo "❌ ÉCHEC DU DÉPLOIEMENT pour l'environnement '${env.TF_VAR_env_name}'"
                }
            }
        }
    }
}