# KL Ecommerce - Infraestructura AWS Enterprise

Infraestructura cloud-native completa para un sistema ecommerce basado en microservicios Java Spring Boot, desplegada en AWS con Terraform.

---

## Arquitectura

```
Usuario
  │
  ▼
CloudFront (CDN Global - HTTPS)
  │
  ├── /* ──────────────────► S3 (Frontend React/Vite)
  │
  └── /api/* ──────────────► API Gateway (REST)
                                  │
                                  ▼
                             ALB (Application Load Balancer)
                                  │
                    ┌─────────────┼─────────────┐
                    ▼             ▼             ▼
               ECS Fargate   ECS Fargate   ECS Fargate
               (auth-svc)   (user-svc)   (order-svc) ...
                    │
                    ▼
               RDS PostgreSQL
                    │
                    ▼
               CloudWatch Logs
```

---

## Microservicios

| Servicio | Puerto | Ruta ALB | Responsabilidad |
|---|---|---|---|
| auth-service | 9001 | /auth/* | JWT, login, autorización |
| user-service | 9002 | /users/* | Usuarios, vendedores, perfiles |
| solicitud-service | 9003 | /solicitudes/* | Onboarding vendedores |
| validation-service | 9004 | /validation/* | Validaciones crediticias |
| payment-service | 9005 | /payments/* | Pagos, estrategias |
| order-service | 9006 | /orders/* | Órdenes, IVA, logística |
| product-service | 9007 | /products/* | Catálogo, categorías |
| notification-service | 9008 | /notifications/* | Eventos, alertas |
| analytics-service | 9009 | /analytics/* | Métricas, KPIs |
| admin-service | 9010 | /admin/* | Configuración, auditoría |
| config-service | 9011 | /config/* | Configuración compartida |

---

## Estructura del Proyecto

```
terraform/
├── main.tf                    # Orquestador principal de módulos
├── provider.tf                # Configuración AWS provider
├── variables.tf               # Variables globales
├── outputs.tf                 # Outputs de la infraestructura
├── terraform.tfvars           # Valores de variables (NO commitear)
├── terraform.tfvars.example   # Ejemplo de variables
│
├── modules/
│   ├── networking/            # VPC, subnets, gateways, security groups
│   ├── ecr/                   # Repositorios Docker con lifecycle policies
│   ├── iam/                   # Roles y políticas mínimas
│   ├── cloudwatch/            # Log groups, métricas, alarmas, dashboard
│   ├── s3/                    # Bucket frontend React/Vite
│   ├── rds/                   # PostgreSQL con subnet group y SSM
│   ├── alb/                   # Load balancer con routing por path
│   ├── ecs/                   # Cluster, task definitions, services
│   ├── api-gateway/           # REST API proxy hacia ALB
│   ├── cloudfront/            # CDN con OAC para S3
│   ├── security/              # Secrets Manager, SSM parameters
│   └── monitoring/            # SNS, alarmas compuestas, metric filters
│
└── environments/
    ├── dev/                   # Configuración entorno desarrollo
    └── prod/                  # Configuración entorno producción
```

---

## Prerrequisitos

1. **AWS CLI** configurado con credenciales válidas
2. **Terraform** >= 1.5.0
3. **Permisos AWS** necesarios (ver sección de permisos)

```bash
# Verificar instalaciones
aws --version
terraform --version
aws sts get-caller-identity
```

---

## Despliegue Paso a Paso

### 1. Clonar y configurar variables

```bash
cd terraform/
cp terraform.tfvars.example terraform.tfvars
# Editar terraform.tfvars con tus valores reales
```

**Variables críticas a cambiar:**
- `db_password` - Contraseña segura para PostgreSQL
- `frontend_bucket_name` - Nombre único globalmente en S3

### 2. Inicializar Terraform

```bash
cd terraform/
terraform init
```

### 3. Validar configuración

```bash
terraform validate
terraform fmt -recursive
```

### 4. Ver plan de ejecución

```bash
terraform plan -out=tfplan
```

### 5. Aplicar infraestructura

```bash
terraform apply tfplan
# O directamente:
terraform apply -auto-approve
```

**Tiempo estimado:** 15-25 minutos (RDS tarda más)

### 6. Ver outputs

```bash
terraform output
terraform output access_summary
```

---

## Destrucción de Infraestructura

```bash
# Ver qué se va a destruir
terraform plan -destroy

# Destruir todo
terraform destroy -auto-approve
```

**Nota:** RDS puede tardar 5-10 minutos en eliminarse.

---

## Despliegue de Microservicios (Post-infraestructura)

### 1. Autenticarse en ECR

```bash
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS \
  --password-stdin $(terraform output -raw ecr_registry_id).dkr.ecr.us-east-1.amazonaws.com
```

### 2. Build y push de imagen

```bash
# Obtener URL del repositorio
ECR_URL=$(terraform output -json ecr_repository_urls | jq -r '.["auth-service"]')

# Build
docker build -t auth-service ./auth-service/

# Tag
docker tag auth-service:latest $ECR_URL:latest

# Push
docker push $ECR_URL:latest
```

### 3. Forzar nuevo despliegue en ECS

```bash
aws ecs update-service \
  --cluster kl-ecommerce-dev-cluster \
  --service kl-ecommerce-dev-auth-service-svc \
  --force-new-deployment \
  --region us-east-1
```

---

## Variables de Entorno en Spring Boot

Cada microservicio recibe automáticamente estas variables de entorno desde ECS:

```properties
SERVER_PORT=9001
SPRING_PROFILES_ACTIVE=dev
SPRING_DATASOURCE_URL=jdbc:postgresql://<rds-endpoint>:5432/kl_ecommerce
SPRING_DATASOURCE_USERNAME=kl_admin
SPRING_DATASOURCE_PASSWORD=<desde SSM>
SPRING_JPA_HIBERNATE_DDL_AUTO=update
MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE=health,info,metrics
AWS_REGION=us-east-1
```

---

## Costos Estimados (Demo)

| Recurso | Tipo | Costo/mes estimado |
|---|---|---|
| ECS Fargate (11 servicios x 0.25vCPU/512MB) | Fargate | ~$15-25 |
| RDS PostgreSQL | db.t3.micro | ~$15 |
| NAT Gateway | Single | ~$35 |
| ALB | Application | ~$20 |
| API Gateway | REST | ~$3-5 |
| CloudFront | PriceClass_100 | ~$1-3 |
| S3 | Standard | ~$1 |
| ECR | Storage | ~$1 |
| CloudWatch | Logs/Metrics | ~$3-5 |
| **TOTAL ESTIMADO** | | **~$93-110/mes** |

> Para reducir costos en demo: apagar ECS services cuando no se usen (`desired_count = 0`)

---

## CI/CD con GitHub Actions

Ejemplo de workflow para despliegue automático:

```yaml
# .github/workflows/deploy.yml
name: Deploy to ECS

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1

      - name: Login to ECR
        uses: aws-actions/amazon-ecr-login@v1

      - name: Build and push Docker image
        run: |
          docker build -t $ECR_URL:$GITHUB_SHA ./auth-service/
          docker push $ECR_URL:$GITHUB_SHA

      - name: Deploy to ECS
        run: |
          aws ecs update-service \
            --cluster kl-ecommerce-dev-cluster \
            --service kl-ecommerce-dev-auth-service-svc \
            --force-new-deployment
```

---

## Troubleshooting

### ECS service no arranca
```bash
# Ver eventos del servicio
aws ecs describe-services \
  --cluster kl-ecommerce-dev-cluster \
  --services kl-ecommerce-dev-auth-service-svc

# Ver logs del contenedor
aws logs tail /ecs/kl-ecommerce/dev/auth-service --follow
```

### Health check fallando
- Verificar que Spring Boot Actuator está habilitado
- Confirmar que el path `/auth/actuator/health` responde 200
- Revisar security groups (puerto 9001 desde ALB)

### RDS no accesible desde ECS
- Verificar security group de RDS permite puerto 5432 desde SG de ECS
- Confirmar que ECS y RDS están en la misma VPC
- Revisar subnet groups de RDS

---

## Arquitectura de Seguridad

```
Internet → CloudFront (HTTPS) → API Gateway → ALB (HTTP interno)
                                                    │
                                              ECS (subnets privadas)
                                                    │
                                              RDS (subnets privadas)

Security Groups:
- ALB SG: ingress 80/443 desde 0.0.0.0/0
- ECS SG: ingress 9001-9011 solo desde ALB SG
- RDS SG: ingress 5432 solo desde ECS SG
```

---

## Tecnologías

- **IaC:** Terraform >= 1.5
- **Cloud:** AWS (ECS Fargate, RDS, ALB, API Gateway, CloudFront, S3, ECR)
- **Backend:** Java Spring Boot (microservicios)
- **Frontend:** React + Vite (SPA)
- **Base de datos:** PostgreSQL 15
- **Contenedores:** Docker
- **Observabilidad:** CloudWatch Logs + Metrics + Dashboard
