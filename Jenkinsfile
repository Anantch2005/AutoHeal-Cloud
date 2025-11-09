pipeline {
    agent {
        docker {
            image 'python:3.10'
            args '-u root --privileged' // allows installing tools like docker, terraform
        }
    }

    environment {
        AWS_DEFAULT_REGION = "us-east-1"
        DOCKER_IMAGE = "anant2005ch/autoheal-cloud"
        TF_BACKEND_DIR = "remote-backend-s3"
        TF_MAIN_DIR = "terraform"
    }

    stages {

        
        stage('Install Dependencies') {
            steps {
                echo "Installing required dependencies..."
                sh '''
                    apt-get update -y
                    apt-get install -y unzip jq ansible curl docker.io lsb-release gnupg
                    curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
                    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
                        https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
                        tee /etc/apt/sources.list.d/hashicorp.list
                    apt-get update && apt-get install -y terraform
                    pip install boto3 awscli
                    service docker start || true
                    echo "Dependencies installed successfully."
                '''
            }
        }

        
        stage('Checkout Code') {
            steps {
                git branch: 'main', url: 'https://github.com/Anantch2005/AutoHeal-Cloud.git'
                echo "Code checked out from GitHub."
            }
        }

        
        stage('Test App') {
            steps {
                dir('app') {
                    sh '''
                        echo "Running syntax test for Python app..."
                        python3 -m py_compile app.py
                        echo "Test passed: Python syntax is valid."
                    '''
                }
            }
        }

        
        stage('Build & Push Docker Image') {
            steps {
                dir('app') {
                    withCredentials([usernamePassword(credentialsId: 'docker-cred', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                        sh '''
                            echo "Building Docker image..."
                            docker build -t $DOCKER_IMAGE:latest .

                            echo "Logging in to DockerHub..."
                            echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin

                            echo "Pushing image to DockerHub..."
                            docker push $DOCKER_IMAGE:latest

                            echo "Docker image pushed successfully."
                        '''
                    }
                }
            }
        }

        
        stage('Terraform Remote Backend') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                    dir("${TF_BACKEND_DIR}") {
                        sh '''
                            echo "Setting up Terraform remote backend (S3)..."
                            terraform init -input=false
                            terraform apply -auto-approve
                            echo "Remote backend setup complete."
                        '''
                    }
                }
            }
        }

        
        stage('Archive Backend State File') {
            steps {
                echo "Archiving backend state file for download..."
                archiveArtifacts artifacts: 'remote-backend-s3/terraform.tfstate', fingerprint: true
            }
        }


        
        stage('Terraform Main Apply') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                    dir("${TF_MAIN_DIR}") {
                        sh '''
                            echo "Initializing and applying Terraform configuration..."
                            terraform init -input=false
                            terraform apply -auto-approve
                            echo "Infrastructure deployed successfully."
                        '''
                    }
                }
            }
        }

       
        stage('Generate Ansible Inventory') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-creds']]) {
                    sh '''
                        echo "Generating Ansible inventory from Terraform outputs..."
                        python3 scripts/generate_inventory.py
                   
                        echo "Setting correct permissions for SSH keys..."
                        chmod 400 terraform/*.pem
                    '''
                }
            }
        }

        
        stage('Configure Primary EC2 with Ansible') {
            steps {
                sh '''
                     echo "Preparing SSH environment..."
                     mkdir -p ~/.ssh
                     touch ~/.ssh/known_hosts
                     chmod 644 ~/.ssh/known_hosts
                     chmod 400 terraform/autoheal-key-primary.pem

                     echo "Running Ansible playbook for primary region..."
                     ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i ansible/inventory.ini ansible/playbook.yml \
                     --private-key terraform/autoheal-key-primary.pem -u ubuntu -l primary

                     echo "Primary EC2 configuration completed successfully."
                 '''
            }
        }

        stage('Configure Secondary EC2 with Ansible') {
            steps {
                sh '''
                    echo "Preparing SSH environment..."
                    mkdir -p ~/.ssh
                    touch ~/.ssh/known_hosts
                    chmod 644 ~/.ssh/known_hosts
                    chmod 400 terraform/autoheal-key-secondary.pem

                    echo "Running Ansible playbook for secondary region..."
                    ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -i ansible/inventory.ini ansible/playbook.yml \
                    --private-key terraform/autoheal-key-secondary.pem -u ubuntu -l secondary

                    echo "Secondary EC2 configuration completed successfully."
                '''
            }
        }


       
        stage('Health Check & AutoHeal') {
            steps {
                sh '''
                    echo "Starting application health check..."
                    mkdir -p ~/.ssh
                    touch ~/.ssh/known_hosts
                    chmod 644 ~/.ssh/known_hosts
                    
                    for ip in $(awk '/^[0-9]/{print $1}' ansible/inventory.ini); do
                        echo "Checking http://$ip ..."
                        if curl -s --head --request GET http://$ip | grep "200 OK" > /dev/null; then
                            echo "$ip is healthy."
                        else
                            echo "$ip is unhealthy, restarting container..."
                            ansible -i ansible/inventory.ini all -m shell \
                                -a 'containers=$(docker ps -q); if [ -n "$containers" ]; then docker restart $containers; fi' \
                                -u ubuntu --private-key terraform/autoheal-key-primary.pem --become
                        fi
                    done
                    echo "Health check completed."
                '''
            }
        }
    }

    post {
        success {
            echo " Pipeline executed successfully. AutoHeal Cloud fully deployed!"
        }
        failure {
            echo " Pipeline failed. Check logs for details."
        }
    }
}