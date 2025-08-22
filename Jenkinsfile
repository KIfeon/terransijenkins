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
        TF_VAR_env_name              = "${params.ENV_NAME}"
        TF_VAR_instance_count        = "${params.INSTANCE_COUNT}"
        TF_VAR_instance_role         = "${params.INSTANCE_ROLE}"
        TF_VAR_instance_distribution = "${params.INSTANCE_DISTRO}"
        TF_VAR_instance_type         = "${params.INSTANCE_TYPE}"
        TF_ACTION                    = "${params.ACTION}"
        TF_DIR                       = './'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
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
                                
                                # First, run terraform plan -destroy to see what will be destroyed
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
                # Pick SSH user by distro for instances and bastion
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
                    echo "=== Cleaning up generated files for environment: ${params.ENV_NAME} ==="
                }
                sh '''
                    # Remove generated files to ensure clean state
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
                        echo "=== Verifying all resources destroyed for environment: ${params.ENV_NAME} ==="
                    }
                    sh '''
                        # Check if there are any remaining resources in state
                        if terraform show | grep -q "resource"; then
                            echo "WARNING: Some resources may still exist in state!"
                            terraform show
                            exit 1
                        else
                            echo "SUCCESS: No resources found in terraform state"
                        fi
                        
                        # Optional: Also check if state file exists and is empty/minimal
                        if [ -f terraform.tfstate ]; then
                            echo "State file contents:"
                            cat terraform.tfstate | jq '.resources // []' | head -10
                        fi
                    '''
                }
            }
        }
        
        // Optionnel : Lancer Ansible après déploiement (adapter selon ton setup)
        // stage('Configuration Ansible') {
        //     when { expression { env.TF_ACTION == "deploy" } }
        //     steps {
        //         dir("${env.TF_DIR}") {
        //             sh 'ansible-playbook -i inventory.py site.yml'
        //         }
        //     }
        // }

    }
    post {
        always {
            script {
                echo "========== RÉSUMÉ DES OPÉRATIONS =========="
                echo "Environnement : ${params.ENV_NAME}"
                echo "Action : ${params.ACTION}"
                
                if (params.ACTION == "destroy") {
                    echo "=== RÉSUMÉ DE LA DESTRUCTION ==="
                    echo "Toutes les ressources pour l'environnement '${params.ENV_NAME}' ont été détruites :"
                    echo "- Instances EC2 (${params.INSTANCE_COUNT} × ${params.INSTANCE_TYPE})"
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
                    echo "✅ DESTRUCTION RÉUSSIE pour l'environnement '${params.ENV_NAME}'"
                } else {
                    echo "✅ DÉPLOIEMENT RÉUSSI pour l'environnement '${params.ENV_NAME}'"
                }
            }
        }
        failure {
            script {
                if (params.ACTION == "destroy") {
                    echo "❌ ÉCHEC DE LA DESTRUCTION pour l'environnement '${params.ENV_NAME}'"
                    echo "Vérifiez manuellement l'état des ressources AWS"
                } else {
                    echo "❌ ÉCHEC DU DÉPLOIEMENT pour l'environnement '${params.ENV_NAME}'"
                }
            }
        }
    }
}
