pipeline {
    agent any

    parameters {
        choice(name: 'ENVIRONMENT', choices: ['default', 'test', 'dev', 'staging', 'prod'], description: 'Select the target environment')
        string(name: 'INSTANCE_TYPE', defaultValue: 't2.micro', description: 'AWS EC2 instance type')
        string(name: 'INSTANCE_COUNT', defaultValue: '1', description: 'Number of instances to deploy, must be a positive number')
    }

    environment {
        PATH=sh(script:"echo $PATH:/usr/local/bin", returnStdout:true).trim()
        AWS_REGION = "us-east-1"
        ANS_KEYPAIR="${params.ENVIRONMENT}"
        AWS_ACCOUNT_ID=sh(script:'export PATH="$PATH:/usr/local/bin" && aws sts get-caller-identity --query Account --output text', returnStdout:true).trim()
        ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        APP_REPO_NAME = "ecr-repo"
        INSTANCE_COUNT_INT = "${params.INSTANCE_COUNT.toInteger()}"
    }

    stages {
        stage('Create Key Pair for AWS instance') {
            steps {
                echo "Creating Key Pair "
                sh """
                    aws ec2 create-key-pair --region ${AWS_REGION} --key-name ${ENVIRONMENT} --query KeyMaterial --output text > ${ENVIRONMENT}
                    chmod 400 ${ENVIRONMENT}
                """
            }
        }


        stage('Create AWS Resources') {
            steps {
                sh """
                    cd terraform 
                    terraform workspace select ${params.ENVIRONMENT} || terraform workspace new ${params.ENVIRONMENT}
                    terraform init
                    terraform apply -var='ec2_type=${params.INSTANCE_TYPE}' \
                                    -var='num_of_instance=${INSTANCE_COUNT_INT}' \
                                    -var='ec2_key=${ENVIRONMENT}' \
                                    -auto-approve
                """
            }
        }

               stage('ENV REACT UPDATE') {
            steps {
                echo 'env update'
                dir('Task-3/terraform'){
                script {
                    env.NODE_IP = sh(script: 'terraform output -raw public_ip', returnStdout:true).trim()
                    
                }
                }
                sh "echo ${NODE_IP}"
            }
        }
        

        stage('ENVSUBST UPDATE DOCKER COMPOSE') {
            steps {
                echo 'env update'
                sh """
                envsubst < docker-compose-template.yml > docker-compose.yml
                """
            }
        }

        stage('Create ECR Repo') {
            steps {
                echo 'Creating ECR Repo for App'
                sh """
                    aws ecr describe-repositories --region ${AWS_REGION} --repository-name ${APP_REPO_NAME} || \
                    aws ecr create-repository \
                    --repository-name ${APP_REPO_NAME} \
                    --image-scanning-configuration scanOnPush=false \
                    --image-tag-mutability MUTABLE \
                    --region ${AWS_REGION}
                """
            }
        }

        stage('Wait the instance') {
            steps {
                script {
                    echo 'Waiting for the instance'
                    id = sh(script: 'aws ec2 describe-instances --filters Name=tag-value,Values="${ENVIRONMENT}_server" Name=instance-state-name,Values=running --query Reservations[*].Instances[*].[InstanceId] --output text',  returnStdout:true).trim()
                    sh 'aws ec2 wait instance-status-ok --instance-ids $id'
                }
            }
        }

        stage('Build App Docker Image') {
            steps {
                echo 'Building App Image'
                
                sh 'docker build --force-rm -t "$ECR_REGISTRY/$APP_REPO_NAME:postgre" -f ./postgresql/Dockerfile .'
                sh 'docker build --force-rm -t "$ECR_REGISTRY/$APP_REPO_NAME:backend" -f ./bluerentalcars-backend/Dockerfile .'
                sh 'docker build --force-rm -t "$ECR_REGISTRY/$APP_REPO_NAME:frontend" -f ./bluerentalcars-frontend/Dockerfile .'
                sh 'docker image ls'
            }
        }
        stage('Push Image to ECR Repo') {
            steps {
                echo 'Pushing App Image to ECR Repo'
                sh 'aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin "$ECR_REGISTRY"'
                sh 'docker push "$ECR_REGISTRY/$APP_REPO_NAME:postgre"'
                sh 'docker push "$ECR_REGISTRY/$APP_REPO_NAME:backend"'
                sh 'docker push "$ECR_REGISTRY/$APP_REPO_NAME:frontend"'
            }
        }
        stage('Deploy the App') {
            steps {
                echo 'Deploy the App'
                sh 'ls -l'
                sh 'ansible --version'
                sh 'ansible-inventory -i ./ansible/inventory_aws_ec2.yml --graph'
                sh """
                    export ANSIBLE_HOST_KEY_CHECKING=False
                    cd ansible
                    ansible-playbook -i inventory_aws_ec2.yml -e "compose_dir=${env.WORKSPACE}/" --private-key=${WORKSPACE}/${ENVIRONMENT} ${ENVIRONMENT}.yml -vv
                """
            }
        }
    } 



    post {
        always {
            echo 'Post Always block'
        }
        success {
            echo 'Delete the Key Pair'
                timeout(time:5, unit:'DAYS'){
                input message:'Approve terminate'
                }
            sh """
                aws ec2 delete-key-pair --region ${AWS_REGION} --key-name ${ENVIRONMENT}
                rm -rf ${ENVIRONMENT}
                """
            echo 'Delete AWS Resources'            
                sh """
                cd terraform 
                terraform destroy --auto-approve
                """
        }
        failure {

            echo 'Pipeline failed. Awaiting user approval for destroy operation.'
            timeout(time: 5, unit: 'DAYS') {
            input message: 'Pipeline failed. Do you want to proceed with destroy?'
            }
            echo 'Delete the Key Pair'
            sh """
                aws ec2 delete-key-pair --region ${AWS_REGION} --key-name ${ENVIRONMENT}
                rm -rf ${ENVIRONMENT}
                """
            echo 'Delete AWS Resources'            
                sh """
                cd terraform
                terraform destroy --auto-approve
                """
        }
    }

    }
