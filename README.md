# devops-project-terraform-servicemesh
𝑫𝒆𝒗𝑶𝒑𝒔 𝑹𝒆𝒂𝒍 𝑾𝒐𝒓𝒍𝒅 𝑷𝒓𝒐𝒋𝒆𝒄𝒕𝒔 𝒇𝒐𝒓 𝑨𝒔𝒑𝒊𝒓𝒊𝒏𝒈 𝑫𝒆𝒗𝑶𝒑𝒔 𝑬𝒏𝒈𝒊𝒏𝒆𝒆𝒓𝒔 [𝑩𝒆𝒈𝒊𝒏𝒏𝒆𝒓 𝒕𝒐 𝑨𝒅𝒗𝒂𝒏𝒄𝒆𝒅]

Below are updated project notes for deploying a production-ready 3-tier application (React frontend, Flask backend, PostgreSQL on RDS) on AWS EKS using **Terraform** for infrastructure provisioning, incorporating a **service mesh** (specifically **AWS App Mesh**) to enhance observability, traffic management, and security. The service mesh integrates with the existing setup, which includes AWS services like RDS, ALB, Route53, OIDC, IAM, and EC2, as well as Jenkins for CI/CD and monitoring with Prometheus, Grafana, and Fluentd. The notes include an updated directory structure, necessary code files, and production-ready considerations, aligning with your previous requests for a Kinesis project, Ansible integration, and Terraform-based EKS deployment.

---

## Project Notes: Deploying a 3-Tier Application on AWS EKS with Terraform and AWS App Mesh

### Project Overview
- **Objective**: Deploy a 3-tier application (React frontend, Flask backend, PostgreSQL on RDS) on AWS EKS, enhanced with AWS App Mesh for service-to-service communication, using Terraform for infrastructure, Helm for Kubernetes deployments, and Jenkins for CI/CD. The application is a quiz platform with a React frontend, Flask API backend, and RDS for data storage, accessible via a custom domain.
- **Architecture**:
  - **Frontend**: React app served via Kubernetes pods, exposed through an Application Load Balancer (ALB).
  - **Backend**: Flask API handling quiz logic, connected to RDS PostgreSQL.
  - **Database**: AWS RDS PostgreSQL in private subnets, accessed via Kubernetes ExternalName service.
  - **Service Mesh**: AWS App Mesh for managing service-to-service communication, providing observability, traffic routing, and security.
  - **Networking**: ALB for external traffic, Route53 for DNS, VPC with public and private subnets.
  - **Security**: OIDC for IAM roles, Kubernetes Secrets for sensitive data, ConfigMaps for configuration, and App Mesh for encrypted communication.
  - **CI/CD**: Jenkins pipeline with Docker, ECR, Helm, and Ansible for automated builds and deployments.
  - **Monitoring**: Prometheus, Grafana, and Fluentd integrated with App Mesh for metrics and logs.
- **Use Case**: A scalable, secure quiz application for DevOps learning with enhanced service communication via App Mesh.
- **Production Considerations**:
  - High availability with multi-AZ RDS and EKS managed node groups.
  - Autoscaling for nodes and pods.
  - Secure credential management with Secrets and OIDC.
  - App Mesh for traffic control, retries, and circuit breaking.
  - Comprehensive monitoring with Prometheus, Grafana, Fluentd, and CloudWatch (via App Mesh).
  - Automated deployments with Jenkins and Ansible for EC2 configuration.

---

### Why AWS App Mesh?
AWS App Mesh is a service mesh that standardizes how services communicate, offering:
- **Observability**: Metrics, logs, and traces for service interactions.
- **Traffic Management**: Routing rules, retries, timeouts, and circuit breaking.
- **Security**: Mutual TLS for encrypted communication.
- **Integration**: Works seamlessly with EKS, ECS, and EC2, and integrates with CloudWatch, Prometheus, and Grafana.

App Mesh is chosen over alternatives like Istio or Linkerd due to its native AWS integration, compatibility with your existing EKS setup, and support for CloudWatch, aligning with your prior interest in AWS services and monitoring tools.

---

### Updated Directory Structure
The project includes additional files for App Mesh configuration, alongside the existing application, Kubernetes manifests, and Terraform infrastructure.

```
3-tier-app-eks/
├── backend/
│   ├── app.py                # Flask backend API
│   ├── requirements.txt      # Python dependencies
│   ├── questions-answers/    # Sample CSV files for quiz data
│   │   └── sample.csv
│   └── migrations/           # Database migration scripts
│       └── init.sql
├── frontend/
│   ├── src/
│   │   ├── App.js           # React frontend code
│   │   └── index.js
│   ├── package.json         # Node.js dependencies
│   └── Dockerfile           # Docker image for frontend
├── k8s/
│   ├── namespace.yaml       # Kubernetes namespace
│   ├── database-service.yaml # ExternalName service for RDS
│   ├── configmap.yaml       # ConfigMap for app configuration
│   ├── secrets.yaml         # Secrets for DB credentials
│   ├── migration_job.yaml   # Kubernetes job for DB migrations
│   ├── backend.yaml         # Backend deployment and service
│   ├── frontend.yaml        # Frontend deployment and service
│   ├── ingress.yaml         # Ingress for ALB
│   ├── appmesh/             # App Mesh Kubernetes resources
│   │   ├── mesh.yaml        # App Mesh definition
│   │   ├── virtual-node-frontend.yaml # Virtual node for frontend
│   │   ├── virtual-node-backend.yaml  # Virtual node for backend
│   │   └── virtual-router.yaml        # Virtual router for traffic routing
├── terraform/
│   ├── main.tf             # Terraform configuration for VPC, EKS, RDS, App Mesh
│   ├── variables.tf        # Terraform variables
│   ├── outputs.tf          # Terraform outputs
│   └── iam.tf             # IAM roles and policies
├── ansible/
│   ├── configure_ec2.yml   # Ansible playbook for EC2 setup
│   └── inventory_aws_ec2.yml # Dynamic inventory for EC2
├── Dockerfile              # Docker image for backend
├── Jenkinsfile             # Jenkins pipeline for CI/CD
└── README.md               # Project documentation
```

---

### Core Components and Code

#### 1. Terraform Configuration
Updated to include AWS App Mesh resources and IAM policies for App Mesh.

```hcl
# Provider configuration
provider "aws" {
  region = var.region
}

# VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "3-tier-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = false
  enable_dns_hostnames = true

  tags = {
    "kubernetes.io/role/elb" = "1"
  }
}

# EKS Cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.31"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    default = {
      min_size     = 1
      max_size     = 3
      desired_size = 2
      instance_types = ["t3.medium"]
    }
  }

  enable_irsa = true
}

# RDS PostgreSQL
resource "aws_db_subnet_group" "rds" {
  name       = "3-tier-postgres-subnet-group"
  subnet_ids = module.vpc.private_subnets
}

resource "aws_security_group" "rds" {
  name        = "3-tier-rds-sg"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }
}

resource "aws_db_instance" "postgres" {
  identifier           = "3-tier-postgres"
  engine               = "postgres"
  engine_version       = "15"
  instance_class       = "db.t3.small"
  allocated_storage    = 20
  storage_type         = "gp2"
  username             = "postgresadmin"
  password             = var.db_password
  db_subnet_group_name = aws_db_subnet_group.rds.name
  vpc_security_groups  = [aws_security_group.rds.id]
  multi_az             = true
  publicly_accessible  = false
  backup_retention_period = 7
}

# Route53 Hosted Zone
resource "aws_route53_zone" "main" {
  name = var.domain_name
}

# App Mesh
resource "aws_appmesh_mesh" "main" {
  name = "3-tier-mesh"
  spec {
    egress_filter {
      type = "ALLOW_ALL"
    }
  }
}
```

```hcl
variable "region" {
  description = "AWS region"
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "EKS cluster name"
  default     = "3-tier-cluster"
}

variable "db_password" {
  description = "RDS PostgreSQL password"
  sensitive   = true
}

variable "domain_name" {
  description = "Domain name for Route53"
  default     = "example.com"
}
```

```hcl
# IAM Policy for AWS Load Balancer Controller
resource "aws_iam_policy" "alb_controller" {
  name   = "AWSLoadBalancerControllerIAMPolicy"
  policy = file("iam_policy.json")
}

# IAM Role for Load Balancer Controller
module "alb_controller_irsa" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  role_name = "AmazonEKSLoadBalancerControllerRole"

  attach_load_balancer_controller_policy = true
  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

# IAM Policy for App Mesh
resource "aws_iam_policy" "appmesh" {
  name   = "AWSAppMeshPolicy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "appmesh:*",
          "cloudwatch:PutMetricData",
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Role for App Mesh
module "appmesh_irsa" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  role_name = "AmazonEKSAppMeshRole"

  attach_policy_json = true
  policy_json        = aws_iam_policy.appmesh.policy

  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = ["3-tier-app-eks:appmesh"]
    }
  }
}
```

```hcl
output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "rds_endpoint" {
  value = aws_db_instance.postgres.endpoint
}

output "hosted_zone_id" {
  value = aws_route53_zone.main.zone_id
}

output "appmesh_arn" {
  value = aws_appmesh_mesh.main.arn
}
```

#### 2. Backend (Flask)
Unchanged from the previous setup, as App Mesh handles communication at the infrastructure level.

```python
from flask import Flask, jsonify
import psycopg2
from flask_sqlalchemy import SQLAlchemy
import os

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('DATABASE_URL')
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)

class Topic(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)

@app.route('/api/topics', methods=['GET'])
def get_topics():
    topics = Topic.query.all()
    return jsonify([{"id": t.id, "name": t.name} for t in topics])

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, debug=os.environ.get('FLASK_DEBUG') == '1')
```

```dockerfile
FROM python:3.9-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["python", "app.py"]
```


Flask==2.2.5
psycopg2-binary==2.9.9
Flask-SQLAlchemy==3.0.5


#### 3. Frontend (React)
Unchanged, as App Mesh is transparent to the application code.

```javascript
import React, { useEffect, useState } from 'react';
import './App.css';

function App() {
  const [topics, setTopics] = useState([]);

  useEffect(() => {
    fetch('/api/topics')
      .then(res => res.json())
      .then(data => setTopics(data));
  }, []);

  return (
    <div>
      <h1>DevOps Quiz</h1>
      <ul>
        {topics.map(topic => (
          <li key={topic.id}>{topic.name}</li>
        ))}
      </ul>
    </div>
  );
}

export default App;
```

```dockerfile
FROM node:16
WORKDIR /app
COPY package.json .
RUN npm install
COPY . .
RUN npm run build
CMD ["npx", "serve", "-s", "build", "-l", "80"]
```

#### 4. Kubernetes Manifests
Updated to include App Mesh resources (mesh, virtual nodes, and virtual router).

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: 3-tier-app-eks
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres-db
  namespace: 3-tier-app-eks
spec:
  type: ExternalName
  externalName: <RDS_ENDPOINT> # Replace with actual RDS endpoint
  ports:
  - port: 5432
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-secrets
  namespace: 3-tier-app-eks
type: Opaque
data:
  DB_USERNAME: cG9zdGdyZXNhZG1pbg==
  DB_PASSWORD: WW91clN0cm9uZ1Bhc3N3b3JkMTIzIQ==
  SECRET_KEY: ZGV2LXNlY3JldC1rZXk=
  DATABASE_URL: cG9zdGdyZXNxbDovL3Bvc3RncmVzYWRtaW46WW91clN0cm9uZ1Bhc3N3b3JkMTIzIUBwb3N0Z3Jlcy1kYi4zLXRpZXItYXBwLWVrcy5zdmMuY2x1c3Rlci5sb2NhbDo1NDMyL3Bvc3RncmVz
```

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: 3-tier-app-eks
data:
  DB_HOST: "postgres-db.3-tier-app-eks.svc.cluster.local"
  DB_NAME: "postgres"
  DB_PORT: "5432"
  FLASK_DEBUG: "0"
```

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: database-migration
  namespace: 3-tier-app-eks
spec:
  template:
    spec:
      containers:
      - name: migration
        image: postgres:15
        command: ["psql", "-h", "postgres-db.3-tier-app-eks.svc.cluster.local", "-U", "postgresadmin", "-d", "postgres", "-f", "/migrations/init.sql"]
        env:
        - name: PGPASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secrets
              key: DB_PASSWORD
        volumeMounts:
        - name: migrations
          mountPath: /migrations
      volumes:
      - name: migrations
        configMap:
          name: app-config
      restartPolicy: Never
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: 3-tier-app-eks
  labels:
    app: backend
    appmesh.k8s.aws/sidecarInjectorWebhook: enabled
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: <AWS_ACCOUNT_ID>.dkr.ecr.us-west-2.amazonaws.com/3-tier-app-backend:production-latest
        ports:
        - containerPort: 8000
        envFrom:
        - configMapRef:
            name: app-config
        - secretRef:
            name: db-secrets
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: 3-tier-app-eks
  annotations:
    appmesh.k8s.aws/virtualNode: backend-vn
spec:
  selector:
    app: backend
  ports:
  - port: 8000
    targetPort: 8000
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: 3-tier-app-eks
  labels:
    app: frontend
    appmesh.k8s.aws/sidecarInjectorWebhook: enabled
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: <AWS_ACCOUNT_ID>.dkr.ecr.us-west-2.amazonaws.com/3-tier-app-frontend:production-latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: 3-tier-app-eks
  annotations:
    appmesh.k8s.aws/virtualNode: frontend-vn
spec:
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
```

```yaml
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: alb
  annotations:
    ingressclass.kubernetes.io/is-default-class: "false"
spec:
  controller: ingress.k8s.aws/alb
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: 3-tier-app-ingress
  namespace: 3-tier-app-eks
  annotations:
    alb.ingress.kubernetes.io/scheme: "internet-facing"
    alb.ingress.kubernetes.io/target-type: "ip"
    alb.ingress.kubernetes.io/healthcheck-path: "/"
spec:
  ingressClassName: "alb"
  rules:
  - http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: backend
            port:
              number: 8000
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
```

```yaml
apiVersion: appmesh.k8s.aws/v1beta2
kind: Mesh
metadata:
  name: 3-tier-mesh
spec:
  namespaceSelector:
    matchLabels:
      mesh: 3-tier-mesh
```

```yaml
apiVersion: appmesh.k8s.aws/v1beta2
kind: VirtualNode
metadata:
  name: frontend-vn
  namespace: 3-tier-app-eks
spec:
  podSelector:
    matchLabels:
      app: frontend
  listeners:
  - portMapping:
      port: 80
      protocol: http
  serviceDiscovery:
    dns:
      hostname: frontend.3-tier-app-eks.svc.cluster.local
  backends:
  - virtualService:
      virtualServiceRef:
        name: backend-vs
```

```yaml
apiVersion: appmesh.k8s.aws/v1beta2
kind: VirtualNode
metadata:
  name: backend-vn
  namespace: 3-tier-app-eks
spec:
  podSelector:
    matchLabels:
      app: backend
  listeners:
  - portMapping:
      port: 8000
      protocol: http
  serviceDiscovery:
    dns:
      hostname: backend.3-tier-app-eks.svc.cluster.local
```

```yaml
apiVersion: appmesh.k8s.aws/v1beta2
kind: VirtualService
metadata:
  name: backend-vs
  namespace: 3-tier-app-eks
spec:
  provider:
    virtualRouter:
      virtualRouterRef:
        name: backend-vr
---
apiVersion: appmesh.k8s.aws/v1beta2
kind: VirtualRouter
metadata:
  name: backend-vr
  namespace: 3-tier-app-eks
spec:
  listeners:
  - portMapping:
      port: 8000
      protocol: http
  routes:
  - name: backend-route
    match:
      prefix: /
    action:
      weightedTarget:
      - virtualNodeRef:
          name: backend-vn
        weight: 100
```

#### 5. Jenkins Pipeline
Updated to deploy App Mesh resources and enable monitoring via CloudWatch.

```groovy
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
```

#### 6. Ansible Playbook for EC2 Configuration
Unchanged, as App Mesh is managed at the Kubernetes level.

```yaml
- name: Configure EC2 for 3-tier app
  hosts: webservers
  become: yes
  tasks:
    - name: Install nginx
      yum:
        name: nginx
        state: present
    - name: Start nginx
      service:
        name: nginx
        state: started
        enabled: yes
```

```yaml
plugin: aws_ec2
regions:
  - us-west-2
filters:
  tag:Environment: production
```

---

### Production Considerations
1. **Scalability**:
   - EKS managed node group with autoscaling (min: 1, max: 3).
   - Horizontal Pod Autoscaler (HPA) for backend and frontend:
     ```yaml
     apiVersion: autoscaling/v2
     kind: HorizontalPodAutoscaler
     metadata:
       name: backend-hpa
       namespace: 3-tier-app-eks
     spec:
       scaleTargetRef:
         apiVersion: apps/v1
         kind: Deployment
         name: backend
       minReplicas: 2
       maxReplicas: 5
       metrics:
       - type: Resource
         resource:
           name: cpu
           target:
             type: Utilization
             averageUtilization: 70
     ```
   - Similar HPA for frontend.
   - App Mesh supports dynamic traffic routing for load balancing.
2. **Security**:
   - OIDC for IAM roles to avoid static credentials.
   - Kubernetes Secrets encrypted at rest.
   - App Mesh enables mutual TLS for secure service-to-service communication.
   - Restrict RDS access to EKS node security group.
   - Enable TLS for ALB (add `alb.ingress.kubernetes.io/certificate-arn` in `ingress.yaml`).
3. **High Availability**:
   - Multi-AZ RDS for failover.
   - Deploy pods across multiple availability zones.
   - Route53 health checks for DNS failover.
   - App Mesh retries and circuit breaking for resilience.
4. **Monitoring and Logging**:
   - App Mesh exports metrics to CloudWatch, integrated with Prometheus.
   - Grafana dashboards for CPU, memory, request latency, and App Mesh metrics (e.g., request rates, error rates).
   - Fluentd forwards logs to CloudWatch and Prometheus.
   - Configure CloudWatch alarms for App Mesh metrics (e.g., `5xxErrorCount`).
5. **Backup and Recovery**:
   - RDS automated backups with 7-day retention.
   - Regular snapshots of EKS cluster and App Mesh configurations.
6. **Cost Optimization**:
   - Use t3.medium instances for cost efficiency.
   - Enable EKS node group and pod autoscaling.
   - Monitor AWS costs with Cost Explorer, including App Mesh usage.
7. **App Mesh Features**:
   - **Traffic Management**: Configure retries and timeouts in `virtual-router.yaml`.
   - **Observability**: Enable X-Ray tracing for detailed request tracking.
   - **Security**: Use mutual TLS for encrypted communication between services.

---

### Setup Instructions
1. **Prerequisites**:
   - AWS CLI, Terraform, kubectl, Helm, and Ansible installed.
   - Jenkins server with Docker, AWS, Helm, Kubernetes CLI, and Slack plugins.
   - AWS credentials (`aws-cred`) and Account ID (`aws-account-id`) in Jenkins.
   - VPC ID stored as Jenkins credential (`vpc-id`).
   - Registered domain (e.g., `example.com`) for Route53.
   - Install App Mesh controller prerequisites: `pip install aws-app-mesh-controller-for-k8s`.
2. **Terraform Deployment**:
   - Initialize: `cd terraform && terraform init`.
   - Apply: `terraform apply -var="db_password=YourStrongPassword123!" -var="domain_name=example.com"`.
   - Note RDS endpoint, hosted zone ID, and App Mesh ARN from outputs.
3. **Update Kubernetes Manifests**:
   - Replace `<RDS_ENDPOINT>` in `database-service.yaml` with Terraform output `rds_endpoint`.
   - Replace `<AWS_ACCOUNT_ID>` in `backend.yaml` and `frontend.yaml`.
4. **Install App Mesh Controller**:
   - Add Helm repo: `helm repo add eks https://aws.github.io/eks-charts`.
   - Create service account for App Mesh:
     ```bash
     eksctl create iamserviceaccount \
       --cluster=3-tier-cluster \
       --namespace=3-tier-app-eks \
       --name=appmesh \
       --role-name=AmazonEKSAppMeshRole \
       --attach-policy-arn=arn:aws:iam::<AWS_ACCOUNT_ID>:policy/AWSAppMeshPolicy \
       --approve
     ```
5. **Jenkins Configuration**:
   - Create a pipeline job pointing to the `Jenkinsfile`.
   - Ensure `ansible/` directory contains `configure_ec2.yml` and `inventory_aws_ec2.yml`.
6. **Deploy and Test**:
   - Push to the `main` branch to trigger the pipeline.
   - Verify ALB DNS in AWS Console and access `app.example.com`.
   - Check App Mesh metrics in CloudWatch and Grafana.
   - Verify pod logs: `kubectl logs -n 3-tier-app-eks -l app=backend`.
7. **Monitoring Setup**:
   - Configure Grafana to connect to Prometheus and CloudWatch for App Mesh metrics.
   - Set up Fluentd to forward logs to CloudWatch.
   - Enable X-Ray in App Mesh for tracing: add `aws_xray_daemon` sidecar to deployments.

---

### Troubleshooting
- **Terraform Errors**: Verify AWS credentials and IAM permissions.
- **EKS Connectivity**: Run `aws eks update-kubeconfig --name 3-tier-cluster --region us-west-2`.
- **RDS Connectivity**: Ensure security group allows port 5432 from EKS nodes.
- **ALB Issues**: Verify subnet tags (`kubernetes.io/role/elb=1`) and OIDC setup.
- **App Mesh Issues**:
  - Check App Mesh controller logs: `kubectl logs -n 3-tier-app-eks -l app.kubernetes.io/name=appmesh-controller`.
  - Verify virtual node and router configurations.
  - Ensure Envoy sidecars are injected: `kubectl describe pod -n 3-tier-app-eks`.
- **Pipeline Failures**: Check Jenkins logs for credential or connectivity issues.

---

### Summary
This project deploys a production-ready 3-tier application on AWS EKS using Terraform for infrastructure, incorporating AWS App Mesh for service-to-service communication. The setup includes RDS, ALB, Route53, OIDC, IAM, and EC2, with Jenkins for CI/CD and Ansible for EC2 configuration. Monitoring with Prometheus, Grafana, Fluentd, and CloudWatch ensures observability, enhanced by App Mesh metrics and traces. Replace placeholders (e.g., `example.com`, `AWS_ACCOUNT_ID`, `<RDS_ENDPOINT>`) with actual values. This setup is secure, scalable, and optimized for production, leveraging your prior interest in AWS services, Kubernetes, and observability tools.
