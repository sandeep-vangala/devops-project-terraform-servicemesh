pipeline {
    agent {
        docker {
            image 'node:16'
        }
    }
    environment {
        APP_ENV = 'production'
        AWS_REGION = 'us-west-2'
        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        AWS_ACCOUNT_ID = credentials('aws-account-id')
        EKS_CLUSTER = '3-tier-cluster'
        VPC_ID = credentials('vpc-id')
    }
    stages {
        stage('Checkout') {
            steps {
                git branch: "${env.BRANCH_NAME}", url: 'https://github.com/example/3-tier-app-eks.git'
            }
        }
        stage('Build Frontend') {
            when {
                branch 'main'
            }
            steps {
                dir('frontend') {
                    sh 'npm install'
                    sh 'docker build -t 3-tier-app-frontend:${APP_ENV}-${env.BUILD_NUMBER} .'
                }
            }
        }
        stage('Build Backend') {
            when {
                branch 'main'
            }
            steps {
                dir('backend') {
                    sh 'docker build -t 3-tier-app-backend:${APP_ENV}-${env.BUILD_NUMBER} .'
                }
            }
        }
        stage('Push to ECR') {
            when {
                branch 'main'
            }
            steps {
                withAWS(credentials: 'aws-cred', region: "${AWS_REGION}") {
                    sh 'aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}'
                    sh 'docker tag 3-tier-app-frontend:${APP_ENV}-${env.BUILD_NUMBER} ${ECR_REGISTRY}/3-tier-app-frontend:${APP_ENV}-${env.BUILD_NUMBER}'
                    sh 'docker tag 3-tier-app-backend:${APP_ENV}-${env.BUILD_NUMBER} ${ECR_REGISTRY}/3-tier-app-backend:${APP_ENV}-${env.BUILD_NUMBER}'
                    sh 'docker push ${ECR_REGISTRY}/3-tier-app-frontend:${APP_ENV}-${env.BUILD_NUMBER}'
                    sh 'docker push ${ECR_REGISTRY}/3-tier-app-backend:${APP_ENV}-${env.BUILD_NUMBER}'
                }
            }
        }
        stage('Configure EC2 with Ansible') {
            when {
                branch 'main'
            }
            steps {
                withAWS(credentials: 'aws-cred', region: "${AWS_REGION}") {
                    sh 'ansible-playbook -i ansible/inventory_aws_ec2.yml ansible/configure_ec2.yml'
                }
            }
        }
        stage('Deploy to EKS') {
            when {
                branch 'main'
            }
            steps {
                script {
                    try {
                        withAWS(credentials: 'aws-cred', region: "${AWS_REGION}") {
                            sh 'aws eks update-kubeconfig --name ${EKS_CLUSTER}'
                            sh 'kubectl apply -f k8s/namespace.yaml'
                            sh 'kubectl label namespace 3-tier-app-eks mesh=3-tier-mesh'
                            sh 'kubectl apply -f k8s/database-service.yaml'
                            sh 'kubectl apply -f k8s/configmap.yaml'
                            sh 'kubectl apply -f k8s/secrets.yaml'
                            sh 'kubectl apply -f k8s/migration_job.yaml'
                            sh 'kubectl apply -f k8s/appmesh/mesh.yaml'
                            sh 'kubectl apply -f k8s/appmesh/virtual-node-frontend.yaml'
                            sh 'kubectl apply -f k8s/appmesh/virtual-node-backend.yaml'
                            sh 'kubectl apply -f k8s/appmesh/virtual-router.yaml'
                            sh 'kubectl apply -f k8s/backend.yaml'
                            sh 'kubectl apply -f k8s/frontend.yaml'
                            sh 'kubectl apply -f k8s/ingress.yaml'
                            sh 'helm repo add eks https://aws.github.io/eks-charts'
                            sh 'helm repo update'
                            sh 'helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=${EKS_CLUSTER} --set serviceAccount.create=false --set serviceAccount.name=aws-load-balancer-controller --set vpcId=${VPC_ID} --set region=${AWS_REGION}'
                            sh 'helm upgrade --install appmesh-controller eks/appmesh-controller -n 3-tier-app-eks --set serviceAccount.create=false --set serviceAccount.name=appmesh --set region=${AWS_REGION}'
                            sh 'helm upgrade --install prometheus prometheus-community/prometheus -n 3-tier-app-eks'
                            sh 'helm upgrade --install grafana grafana/grafana -n 3-tier-app-eks'
                            sh 'helm upgrade --install fluentd fluent/fluentd -n 3-tier-app-eks --set fluentd.configMap.fluentdOutput="prometheus"'
                        }
                    } catch (Exception e) {
                        sh 'helm rollback 3-tier-app 0 -n 3-tier-app-eks'
                        error "Deployment failed, rolled back: ${e}"
                    }
                }
            }
        }
        stage('Configure Route53') {
            when {
                branch 'main'
            }
            steps {
                withAWS(credentials: 'aws-cred', region: "${AWS_REGION}") {
                    sh '''
                    ALB_DNS=$(kubectl get ingress 3-tier-app-ingress -n 3-tier-app-eks -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
                    ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name example.com --query "HostedZones[0].Id" --output text | sed 's/\/hostedzone\///')
                    aws route53 change-resource-record-sets \
                      --hosted-zone-id $ZONE_ID \
                      --change-batch '{
                        "Changes": [
                          {
                            "Action": "UPSERT",
                            "ResourceRecordSet": {
                              "Name": "app.example.com",
                              "Type": "A",
                              "AliasTarget": {
                                "HostedZoneId": "Z32O12XQLNTSW2",
                                "DNSName": "'$ALB_DNS'",
                                "EvaluateTargetHealth": true
                              }
                            }
                          }
                        ]
                      }'
                    '''
                }
            }
        }
    }
    post {
        success {
            slackSend(channel: '#builds', message: "Build succeeded: ${env.JOB_NAME} #${env.BUILD_NUMBER}")
        }
        failure {
            slackSend(channel: '#builds', message: "Build failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}")
        }
    }
}
