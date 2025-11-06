pipeline {
    agent any
    
    environment {
        AWS_DEFAULT_REGION = 'us-east-1'  // Change to your preferred region
        AWS_CREDENTIALS = credentials('aws-credentials')  // Jenkins credential ID for AWS
        GITHUB_CREDENTIALS = credentials('github-token')  // Jenkins credential ID for GitHub
        S3_BUCKET = "${params.ENVIRONMENT}-deployment-artifacts-${env.BUILD_NUMBER}"
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
            description: 'Deploy CloudFormation infrastructure'
        )
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out source code from GitHub...'
                checkout scm
                
                script {
                    env.GIT_COMMIT_SHORT = sh(
                        script: 'git rev-parse --short HEAD',
                        returnStdout: true
                    ).trim()
                    env.BUILD_TIMESTAMP = sh(
                        script: 'date +%Y%m%d-%H%M%S',
                        returnStdout: true
                    ).trim()
                }
            }
        }
        
        stage('Environment Setup') {
            steps {
                echo "Setting up environment for: ${params.ENVIRONMENT}"
                script {
                    env.STACK_NAME = "faus-${params.ENVIRONMENT}-stack"
                    env.DEPLOYMENT_BUCKET = "faus-${params.ENVIRONMENT}-deployments"
                }
            }
        }
        
        stage('Validate Templates') {
            when {
                not { params.SKIP_TESTS }
            }
            steps {
                echo 'Validating CloudFormation templates...'
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                    sh '''
                        # Validate CloudFormation templates
                        for template in resources/*.yaml; do
                            if [ -f "$template" ]; then
                                echo "Validating $template..."
                                aws cloudformation validate-template --template-body file://$template
                            fi
                        done
                        
                        # Validate JSON files
                        for json_file in *.json; do
                            if [ -f "$json_file" ]; then
                                echo "Validating JSON syntax for $json_file..."
                                python -m json.tool "$json_file" > /dev/null
                            fi
                        done
                    '''
                }
            }
        }
        
        stage('Package Templates') {
            steps {
                echo 'Packaging CloudFormation templates...'
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-credentials']]) {
                    sh '''
                        # Create deployment bucket if it doesn't exist
                        aws s3 mb s3://${DEPLOYMENT_BUCKET} --region ${AWS_DEFAULT_REGION} || true
                        
                        # Package SAM/CloudFormation templates
                        if [ -f "resources/create-s3-bucket.yaml" ]; then
                            aws cloudformation package \
                                --template-file resources/create-s3-bucket.yaml \
                                --s3-bucket ${DEPLOYMENT_BUCKET} \
                                --s3-prefix ${BUILD_TIMESTAMP} \
                                --output-template-file packaged-template.yaml
                        fi
                        
                        # Upload other artifacts
                        aws s3 cp iam-role-and-policies.json s3://${DEPLOYMENT_BUCKET}/${BUILD_TIMESTAMP}/
                    '''
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
                sh '''
                    rm -f packaged-template.yaml
                    echo "Cleanup completed"
                '''
            }
        }
    }
    
    post {
        always {
            echo 'Pipeline execution completed.'
            // Archive build artifacts
            archiveArtifacts artifacts: 'resources/*.yaml, *.json', fingerprint: true, allowEmptyArchive: true
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