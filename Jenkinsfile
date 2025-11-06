pipeline {
    agent any
    
    environment {
        AWS_DEFAULT_REGION = 'us-east-1'  // Change to your preferred region
        AWS_CREDENTIALS = credentials('aws-credentials')  // Jenkins credential ID for AWS
        GITHUB_CREDENTIALS = credentials('github-token')  // Jenkins credential ID for GitHub
        // Fixed S3 bucket naming - environment-specific, not build-specific
        DEPLOYMENT_BUCKET_BASE = "faus-deployment-artifacts"
    }
    
    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'staging', 'prod'],
            description: 'Select the environment to deploy to'
        )
        booleanParam(
            name: 'SKIP_TESTS',
            defaultValue: false,
            description: 'Skip validation tests'
        )
        booleanParam(
            name: 'DEPLOY_INFRASTRUCTURE',
            defaultValue: true,
            description: 'Deploy Terraform templates and CloudFormation infrastructure'
        )
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out source code from GitHub...'
                checkout scm
                
                script {
                    // Cross-platform compatible commands
                    try {
                        if (isUnix()) {
                            env.GIT_COMMIT_SHORT = sh(
                                script: 'git rev-parse --short HEAD',
                                returnStdout: true
                            ).trim()
                            env.BUILD_TIMESTAMP = sh(
                                script: 'date +%Y%m%d-%H%M%S',
                                returnStdout: true
                            ).trim()
                        } else {
                            env.GIT_COMMIT_SHORT = bat(
                                script: 'git rev-parse --short HEAD',
                                returnStdout: true
                            ).trim()
                            env.BUILD_TIMESTAMP = powershell(
                                script: 'Get-Date -Format "yyyyMMdd-HHmmss"',
                                returnStdout: true
                            ).trim()
                        }
                        echo "Git commit: ${env.GIT_COMMIT_SHORT}"
                        echo "Build timestamp: ${env.BUILD_TIMESTAMP}"
                    } catch (Exception e) {
                        echo "Warning: Could not retrieve git information: ${e.getMessage()}"
                        env.GIT_COMMIT_SHORT = "unknown"
                        env.BUILD_TIMESTAMP = new Date().format('yyyyMMdd-HHmmss')
                    }
                }
            }
        }
        
        stage('Environment Setup') {
            steps {
                echo "Setting up environment for: ${params.ENVIRONMENT}"
                script {
                    try {
                        env.STACK_NAME = "faus-${params.ENVIRONMENT}-stack"
                        env.DEPLOYMENT_BUCKET = "${env.DEPLOYMENT_BUCKET_BASE}-${params.ENVIRONMENT}"
                        echo "Stack name: ${env.STACK_NAME}"
                        echo "Deployment bucket: ${env.DEPLOYMENT_BUCKET}"
                        
                        // Validate environment parameter
                        if (!['dev', 'staging', 'prod'].contains(params.ENVIRONMENT)) {
                            error("Invalid environment: ${params.ENVIRONMENT}. Must be dev, staging, or prod.")
                        }
                    } catch (Exception e) {
                        error("Environment setup failed: ${e.getMessage()}")
                    }
                }
            }
        }
        
        stage('Validate Templates') {
            when {
                not { params.SKIP_TESTS }
            }
            steps {
                echo 'Validating Terraform templates and CloudFormation templates...'
                
                script {
                    try {
                        // Check required tools availability
                        def toolsAvailable = [:]
                        
                        // Check Node.js
                        try {
                            if (isUnix()) {
                                sh 'node --version'
                            } else {
                                bat 'node --version'
                            }
                            toolsAvailable.nodejs = true
                            echo "✓ Node.js is available"
                        } catch (Exception e) {
                            toolsAvailable.nodejs = false
                            echo "✗ Node.js is not available: ${e.getMessage()}"
                        }
                        
                        // Check AWS CLI
                        try {
                            if (isUnix()) {
                                sh 'aws --version'
                            } else {
                                bat 'aws --version'
                            }
                            toolsAvailable.awscli = true
                            echo "✓ AWS CLI is available"
                        } catch (Exception e) {
                            toolsAvailable.awscli = false
                            echo "✗ AWS CLI is not available: ${e.getMessage()}"
                        }
                        
                        // Check Terraform
                        try {
                            if (isUnix()) {
                                sh 'terraform version'
                            } else {
                                bat 'terraform version'
                            }
                            toolsAvailable.terraform = true
                            echo "✓ Terraform is available"
                        } catch (Exception e) {
                            toolsAvailable.terraform = false
                            echo "✗ Terraform is not available: ${e.getMessage()}"
                        }
                        
                        // Check Python
                        try {
                            if (isUnix()) {
                                sh 'python --version || python3 --version'
                            } else {
                                bat 'python --version'
                            }
                            toolsAvailable.python = true
                            echo "✓ Python is available"
                        } catch (Exception e) {
                            toolsAvailable.python = false
                            echo "✗ Python is not available: ${e.getMessage()}"
                        }
                        
                        // Validate CloudFormation templates
                        if (toolsAvailable.awscli) {
                            withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                                if (isUnix()) {
                                    sh '''
                                        if [ -d "resources" ]; then
                                            echo "Found resources directory, validating CloudFormation templates..."
                                            for template in resources/*.yaml resources/*.yml; do
                                                if [ -f "$template" ]; then
                                                    echo "Validating CloudFormation template: $template..."
                                                    aws cloudformation validate-template --template-body file://$template || echo "Warning: Failed to validate $template"
                                                fi
                                            done
                                        else
                                            echo "No resources directory found, skipping CloudFormation validation"
                                        fi
                                    '''
                                } else {
                                    bat '''
                                        if exist "resources" (
                                            echo Found resources directory, validating CloudFormation templates...
                                            for %%f in (resources\\*.yaml resources\\*.yml) do (
                                                if exist "%%f" (
                                                    echo Validating CloudFormation template: %%f...
                                                    aws cloudformation validate-template --template-body file://%%f || echo Warning: Failed to validate %%f
                                                )
                                            )
                                        ) else (
                                            echo No resources directory found, skipping CloudFormation validation
                                        )
                                    '''
                                }
                            }
                        } else {
                            echo "Skipping CloudFormation validation - AWS CLI not available"
                        }
                        
                        // Validate Terraform files
                        if (toolsAvailable.terraform) {
                            if (isUnix()) {
                                sh '''
                                    if [ -d "terraform" ]; then
                                        echo "Found terraform directory, validating Terraform templates..."
                                        cd terraform
                                        echo "Checking Terraform formatting..."
                                        terraform fmt -check || echo "Warning: Terraform files not properly formatted"
                                        echo "Initializing Terraform (without backend)..."
                                        terraform init -backend=false || echo "Warning: Terraform init failed"
                                        echo "Validating Terraform configuration..."
                                        terraform validate || echo "Warning: Terraform validation failed"
                                        cd ..
                                    else
                                        echo "No terraform directory found, skipping Terraform validation"
                                    fi
                                '''
                            } else {
                                bat '''
                                    if exist "terraform" (
                                        echo Found terraform directory, validating Terraform templates...
                                        cd terraform
                                        echo Checking Terraform formatting...
                                        terraform fmt -check || echo Warning: Terraform files not properly formatted
                                        echo Initializing Terraform ^(without backend^)...
                                        terraform init -backend=false || echo Warning: Terraform init failed
                                        echo Validating Terraform configuration...
                                        terraform validate || echo Warning: Terraform validation failed
                                        cd ..
                                    ) else (
                                        echo No terraform directory found, skipping Terraform validation
                                    )
                                '''
                            }
                        } else {
                            echo "Skipping Terraform validation - Terraform not available"
                        }
                        
                        // Validate JSON files with Python
                        if (toolsAvailable.python) {
                            if (isUnix()) {
                                sh '''
                                    echo "Validating JSON files with Python..."
                                    for json_file in *.json; do
                                        if [ -f "$json_file" ]; then
                                            echo "Validating JSON syntax for $json_file using Python..."
                                            python -m json.tool "$json_file" > /dev/null && echo "✓ Valid JSON: $json_file" || echo "✗ Invalid JSON: $json_file"
                                        fi
                                    done
                                '''
                            } else {
                                bat '''
                                    echo Validating JSON files with Python...
                                    for %%f in (*.json) do (
                                        if exist "%%f" (
                                            echo Validating JSON syntax for %%f using Python...
                                            python -m json.tool "%%f" >nul 2>&1 && echo ✓ Valid JSON: %%f || echo ✗ Invalid JSON: %%f
                                        )
                                    )
                                '''
                            }
                        }
                        
                        // Validate JSON files with Node.js
                        if (toolsAvailable.nodejs) {
                            if (isUnix()) {
                                sh '''
                                    echo "Validating JSON files with Node.js..."
                                    for json_file in *.json; do
                                        if [ -f "$json_file" ]; then
                                            echo "Validating JSON syntax for $json_file using JavaScript..."
                                            node -e "
                                                const fs = require('fs');
                                                try {
                                                    const data = fs.readFileSync('$json_file', 'utf8');
                                                    JSON.parse(data);
                                                    console.log('✓ Valid JSON: $json_file');
                                                } catch (error) {
                                                    console.error('✗ Invalid JSON: $json_file - ' + error.message);
                                                    process.exit(1);
                                                }
                                            "
                                        fi
                                    done
                                '''
                            } else {
                                bat '''
                                    echo Validating JSON files with Node.js...
                                    for %%f in (*.json) do (
                                        if exist "%%f" (
                                            echo Validating JSON syntax for %%f using JavaScript...
                                            node -e "const fs = require('fs'); try { const data = fs.readFileSync('%%f', 'utf8'); JSON.parse(data); console.log('✓ Valid JSON: %%f'); } catch (error) { console.error('✗ Invalid JSON: %%f - ' + error.message); process.exit(1); }"
                                        )
                                    )
                                '''
                            }
                        }
                        
                        echo "Template validation completed"
                        
                    } catch (Exception e) {
                        error("Template validation failed: ${e.getMessage()}")
                    }
                }
            }
        }
        
        stage('Package Templates') {
            steps {
                echo 'Packaging Terraform templates and CloudFormation templates...'
                script {
                    try {
                        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                            // Create deployment bucket if it doesn't exist
                            try {
                                if (isUnix()) {
                                    sh """
                                        echo "Creating deployment bucket if it doesn't exist..."
                                        aws s3 mb s3://${env.DEPLOYMENT_BUCKET} --region ${env.AWS_DEFAULT_REGION} || echo "Bucket already exists or creation failed"
                                    """
                                } else {
                                    bat """
                                        echo Creating deployment bucket if it doesn't exist...
                                        aws s3 mb s3://${env.DEPLOYMENT_BUCKET} --region ${env.AWS_DEFAULT_REGION} || echo Bucket already exists or creation failed
                                    """
                                }
                            } catch (Exception e) {
                                echo "Warning: Could not create S3 bucket: ${e.getMessage()}"
                            }
                            
                            // Package CloudFormation templates
                            try {
                                if (isUnix()) {
                                    sh '''
                                        if [ -f "resources/create-s3-bucket.yaml" ]; then
                                            echo "Packaging CloudFormation template..."
                                            aws cloudformation package \
                                                --template-file resources/create-s3-bucket.yaml \
                                                --s3-bucket ${DEPLOYMENT_BUCKET} \
                                                --s3-prefix ${BUILD_TIMESTAMP} \
                                                --output-template-file packaged-template.yaml
                                            echo "CloudFormation template packaged successfully"
                                        else
                                            echo "No CloudFormation template found at resources/create-s3-bucket.yaml"
                                        fi
                                    '''
                                } else {
                                    bat '''
                                        if exist "resources\\create-s3-bucket.yaml" (
                                            echo Packaging CloudFormation template...
                                            aws cloudformation package --template-file resources/create-s3-bucket.yaml --s3-bucket %DEPLOYMENT_BUCKET% --s3-prefix %BUILD_TIMESTAMP% --output-template-file packaged-template.yaml
                                            echo CloudFormation template packaged successfully
                                        ) else (
                                            echo No CloudFormation template found at resources/create-s3-bucket.yaml
                                        )
                                    '''
                                }
                            } catch (Exception e) {
                                echo "Warning: CloudFormation packaging failed: ${e.getMessage()}"
                            }
                            
                            // Package Terraform templates
                            try {
                                if (isUnix()) {
                                    sh '''
                                        if [ -d "terraform" ]; then
                                            echo "Packaging Terraform templates..."
                                            tar -czf terraform-templates-${BUILD_TIMESTAMP}.tar.gz terraform/
                                            aws s3 cp terraform-templates-${BUILD_TIMESTAMP}.tar.gz s3://${DEPLOYMENT_BUCKET}/${BUILD_TIMESTAMP}/
                                            echo "Terraform templates packaged and uploaded successfully"
                                        else
                                            echo "No terraform directory found"
                                        fi
                                    '''
                                } else {
                                    bat '''
                                        if exist "terraform" (
                                            echo Packaging Terraform templates...
                                            powershell -Command "Compress-Archive -Path terraform\\* -DestinationPath terraform-templates-%BUILD_TIMESTAMP%.zip -Force"
                                            aws s3 cp terraform-templates-%BUILD_TIMESTAMP%.zip s3://%DEPLOYMENT_BUCKET%/%BUILD_TIMESTAMP%/
                                            echo Terraform templates packaged and uploaded successfully
                                        ) else (
                                            echo No terraform directory found
                                        )
                                    '''
                                }
                            } catch (Exception e) {
                                echo "Warning: Terraform packaging failed: ${e.getMessage()}"
                            }
                            
                            // Upload other artifacts
                            try {
                                if (isUnix()) {
                                    sh '''
                                        if [ -f "iam-role-and-policies.json" ]; then
                                            echo "Uploading IAM role and policies..."
                                            aws s3 cp iam-role-and-policies.json s3://${DEPLOYMENT_BUCKET}/${BUILD_TIMESTAMP}/
                                            echo "IAM artifacts uploaded successfully"
                                        else
                                            echo "No iam-role-and-policies.json file found"
                                        fi
                                    '''
                                } else {
                                    bat '''
                                        if exist "iam-role-and-policies.json" (
                                            echo Uploading IAM role and policies...
                                            aws s3 cp iam-role-and-policies.json s3://%DEPLOYMENT_BUCKET%/%BUILD_TIMESTAMP%/
                                            echo IAM artifacts uploaded successfully
                                        ) else (
                                            echo No iam-role-and-policies.json file found
                                        )
                                    '''
                                }
                            } catch (Exception e) {
                                echo "Warning: IAM artifacts upload failed: ${e.getMessage()}"
                            }
                        }
                        
                        echo "Packaging stage completed"
                        
                    } catch (Exception e) {
                        error("Packaging failed: ${e.getMessage()}")
                    }
                }
            }
        }
        
        stage('Deploy Infrastructure') {
            when {
                expression { params.DEPLOY_INFRASTRUCTURE }
            }
            steps {
                echo "Deploying infrastructure to ${params.ENVIRONMENT} environment..."
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                    script {
                        try {
                            sh '''
                                # Deploy the CloudFormation stack
                                aws cloudformation deploy \
                                    --template-file packaged-template.yaml \
                                    --stack-name ${STACK_NAME} \
                                    --parameter-overrides \
                                        Environment=${ENVIRONMENT} \
                                        BuildNumber=${BUILD_NUMBER} \
                                        GitCommit=${GIT_COMMIT_SHORT} \
                                    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
                                    --region ${AWS_DEFAULT_REGION} \
                                    --no-fail-on-empty-changeset
                                
                                # Get stack outputs
                                echo "Stack deployment completed. Getting outputs..."
                                aws cloudformation describe-stacks \
                                    --stack-name ${STACK_NAME} \
                                    --query 'Stacks[0].Outputs' \
                                    --output table
                            '''
                        } catch (Exception e) {
                            echo "Deployment failed: ${e.getMessage()}"
                            currentBuild.result = 'FAILURE'
                            error("CloudFormation deployment failed")
                        }
                    }
                }
            }
        }
        
        stage('Post-Deploy Verification') {
            when {
                expression { params.DEPLOY_INFRASTRUCTURE }
            }
            steps {
                echo 'Running post-deployment verification...'
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                    sh '''
                        # Verify stack status
                        STACK_STATUS=$(aws cloudformation describe-stacks \
                            --stack-name ${STACK_NAME} \
                            --query 'Stacks[0].StackStatus' \
                            --output text)
                        
                        echo "Stack Status: $STACK_STATUS"
                        
                        if [[ "$STACK_STATUS" == "CREATE_COMPLETE" || "$STACK_STATUS" == "UPDATE_COMPLETE" ]]; then
                            echo "Stack deployment successful!"
                            
                            # Test S3 bucket if created
                            BUCKET_NAME=$(aws cloudformation describe-stacks \
                                --stack-name ${STACK_NAME} \
                                --query 'Stacks[0].Outputs[?OutputKey==`BucketName`].OutputValue' \
                                --output text 2>/dev/null || echo "")
                            
                            if [ ! -z "$BUCKET_NAME" ]; then
                                echo "Testing S3 bucket: $BUCKET_NAME"
                                aws s3 ls s3://$BUCKET_NAME || echo "Bucket not accessible yet"
                            fi
                        else
                            echo "Stack deployment failed with status: $STACK_STATUS"
                            exit 1
                        fi
                    '''
                }
            }
        }
        
        stage('Cleanup') {
            steps {
                echo 'Cleaning up temporary files...'
                script {
                    try {
                        if (isUnix()) {
                            sh '''
                                echo "Removing temporary files..."
                                rm -f packaged-template.yaml
                                rm -f terraform-templates-*.tar.gz
                                echo "Cleanup completed successfully"
                            '''
                        } else {
                            bat '''
                                echo Removing temporary files...
                                if exist "packaged-template.yaml" del /f "packaged-template.yaml"
                                if exist "terraform-templates-*.zip" del /f "terraform-templates-*.zip"
                                echo Cleanup completed successfully
                            '''
                        }
                    } catch (Exception e) {
                        echo "Warning: Cleanup failed: ${e.getMessage()}"
                    }
                }
            }
        }
    }
    
    post {
        always {
            echo 'Pipeline execution completed.'
            // Archive build artifacts
            archiveArtifacts artifacts: 'resources/*.yaml, *.json, terraform/*.tf, terraform/*.tfvars', fingerprint: true, allowEmptyArchive: true
        }
        success {
            echo 'Pipeline completed successfully!'
            script {
                if (params.ENVIRONMENT == 'prod') {
                    // Send notification for production deployments
                    echo 'Production deployment completed successfully!'
                }
            }
        }
        failure {
            echo 'Pipeline failed!'
            script {
                // You can add notification logic here (email, Slack, etc.)
                echo 'Deployment failed. Please check the logs.'
            }
        }
        cleanup {
            // Clean up workspace
            deleteDir()
        }
    }
}