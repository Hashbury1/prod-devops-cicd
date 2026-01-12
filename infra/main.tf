name: CI/CD Pipeline to ECS Fargate
on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

env:
  AWS_REGION: us-east-1
  ECR_REPOSITORY: portfolio-api              # Matches aws_ecr_repository.api.name
  ECS_SERVICE: portfolio-service            # Matches aws_ecs_service.api.name output
  ECS_CLUSTER: portfolio-cluster            # Matches aws_ecs_cluster.portfolio.name output
  CONTAINER_NAME: api                       # Matches your container_definitions.name
  TASK_FAMILY: portfolio-api                # Matches aws_ecs_task_definition.api.family output

jobs:
  deploy:
    name: Build, Test, Scan, Deploy
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write

    steps:
    - name: Checkout code
      uses: actions/checkout@v4

    - name: Configure AWS credentials (OIDC)
      uses: aws-actions/configure-aws-credentials@v4
      with:
        role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
        aws-region: ${{ env.AWS_REGION }}
        role-session-name: GitHubActions-${{ github.run_id }}

    - name: Login to Amazon ECR
      id: login-ecr
      uses: aws-actions/amazon-ecr-login@v2

    - name: Build and push Docker image to ECR
      id: build-image
      env:
        ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
      run: |
        IMAGE_TAG=${{ github.sha }}
        docker build ./api --file ./api/Dockerfile \
          -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG \
          -t $ECR_REGISTRY/$ECR_REPOSITORY:latest
        docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
        docker push $ECR_REGISTRY/$ECR_REPOSITORY:latest
        echo "image=$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" >> $GITHUB_OUTPUT
        echo "registry=$ECR_REGISTRY" >> $GITHUB_OUTPUT

    - name: Run unit tests
      run: |
        docker run --rm ${{ steps.build-image.outputs.image }} pytest tests/ -v

    - name: Security scan with Trivy
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: ${{ steps.build-image.outputs.image }}
        severity: 'CRITICAL,HIGH'

    - name: Get current task definition
      id: current-task-def
      run: |
        TASK_DEF_ARN=$(aws ecs describe-task-definition \
          --task-definition ${{ env.TASK_FAMILY }} \
          --query 'taskDefinition' \
          --output json)
        echo "task-definition=$TASK_DEF_ARN" >> $GITHUB_OUTPUT

    - name: Fill task definition with new image
      id: task-def
      uses: aws-actions/amazon-ecs-render-task-definition@v1
      with:
        task-definition: ${{ steps.current-task-def.outputs['task-definition'] }}
        container-name: ${{ env.CONTAINER_NAME }}
        image: ${{ steps.build-image.outputs.image }}

    - name: Deploy to ECS (Blue/Green rolling update)
      if: github.ref == 'refs/heads/main'
      run: |
        # Register new task definition
        aws ecs register-task-definition \
          --cli-input-json file://${{ steps.task-def.outputs.task-definition }} \
          --family ${{ env.TASK_FAMILY }}

        # Update service (triggers rolling deployment)
        aws ecs update-service \
          --cluster ${{ env.ECS_CLUSTER }} \
          --service ${{ env.ECS_SERVICE }} \
          --task-definition ${{ steps.task-def.outputs.task-definition }} \
          --force-new-deployment

    - name: Verify deployment
      if: github.ref == 'refs/heads/main'
      run: |
        aws ecs wait services-stable \
          --cluster ${{ env.ECS_CLUSTER }} \
          --services ${{ env.ECS_SERVICE }}
        echo "✅ Deployment successful! Check your ALB: ${{ needs.terraform.outputs.alb_dns }}"
