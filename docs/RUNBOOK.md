# Migration Runbook

Procedure to reproduce the workload migration from a legacy host to
ECS Fargate.

## Prerequisites

- AWS CLI configured with credentials for the target account
- Terraform 1.10 or later
- Session Manager plugin for AWS CLI
- An S3 bucket for Terraform remote state

## 1. Provision the base infrastructure

The ECS runtime is intentionally excluded at this stage. Provisioning a
service before its image exists produces tasks that fail in a restart
loop.

    cd infra
    terraform init
    terraform validate
    terraform plan
    terraform apply

Record the outputs — instance IDs and the ECR repository URL are used in
the following steps.

## 2. Establish the legacy baseline

Connect to the source instance:

    aws ssm start-session --target <source_instance_id> --region us-east-1

Install the runtime and start the application directly on the operating
system, without a container:

    sudo dnf install -y python3 python3-pip
    mkdir -p ~/legacy-app && cd ~/legacy-app
    python3 -m venv venv && source venv/bin/activate
    pip install flask==3.0.3

Place the application source in `app.py`, then start it:

    nohup python app.py > app.log 2>&1 &
    curl -s http://localhost:5000

Expected response reports `"environment": "on-premises"`.

## 3. Containerize on the target host

Connect to the target instance:

    aws ssm start-session --target <target_instance_id> --region us-east-1

Docker is installed during instance boot. Verify before proceeding:

    sudo systemctl is-active docker

Clone the repository and build the image from versioned source:

    sudo dnf install -y git
    git clone https://github.com/DanielMelo1/aws-workload-migration-poc.git
    cd aws-workload-migration-poc
    sudo docker build -t workload-migration-app:1.0.0 ./app

## 4. Publish to the registry

Authentication uses the instance IAM role. No credentials are entered or
stored on disk:

    ACCOUNT_ID=<account_id>
    REGION=us-east-1
    ECR_URL=$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/workload-migration-app

    aws ecr get-login-password --region $REGION \
      | sudo docker login --username AWS --password-stdin \
        $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

    sudo docker tag workload-migration-app:1.0.0 $ECR_URL:1.0.0
    sudo docker push $ECR_URL:1.0.0

The repository uses immutable tags. Publishing a new build requires a new
version number rather than overwriting an existing tag.

## 5. Provision the managed runtime

With the image available, enable the ECS resources:

    cd infra
    terraform apply -var="deploy_ecs=true"

Confirm the service reached a steady state:

    aws ecs describe-services \
      --cluster workload-migration-cluster \
      --services workload-migration-service \
      --region us-east-1 \
      --query "services[0].{Running:runningCount,Desired:desiredCount}" \
      --output table

## 6. Validate the migrated workload

Fargate assigns a network interface per task. The public address is
resolved through the attached ENI:

    TASK_ARN=$(aws ecs list-tasks --cluster workload-migration-cluster \
      --region us-east-1 --query "taskArns[0]" --output text)

    ENI_ID=$(aws ecs describe-tasks --cluster workload-migration-cluster \
      --tasks $TASK_ARN --region us-east-1 \
      --query "tasks[0].attachments[0].details[?name=='networkInterfaceId'].value" \
      --output text)

    TASK_IP=$(aws ec2 describe-network-interfaces \
      --network-interface-ids $ENI_ID --region us-east-1 \
      --query "NetworkInterfaces[0].Association.PublicIp" --output text)

    curl -s http://$TASK_IP:5000

Expected response reports `"environment": "aws-cloud"` with a hostname
distinct from the legacy host, confirming the workload runs on different
infrastructure.

## 7. Teardown

    terraform destroy

The ECR repository is configured with force_delete, allowing removal
while images are present. Remove the state bucket separately if the
environment is no longer needed.

## Troubleshooting

**Instance does not appear in Session Manager.** The agent registers a
few moments after boot. Verify the instance profile includes
AmazonSSMManagedInstanceCore and check registration status:

    aws ssm describe-instance-information --region us-east-1

**Push to ECR is denied.** Confirm the instance role includes
AmazonEC2ContainerRegistryPowerUser and that the login command targeted
the correct account and region.

**ECS task fails to start.** Inspect the stopped reason:

    aws ecs describe-tasks --cluster workload-migration-cluster \
      --tasks <task_arn> --region us-east-1 \
      --query "tasks[0].stoppedReason"

A missing image is the most common cause — verify the tag referenced in
the task definition exists in the repository.
