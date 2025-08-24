### Pipeline de destruction

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