#!/bin/bash
# Enhanced Jenkins setup script with webhook and automation support

# Source the original setup
source /opt/jenkins-setup.sh

echo "Starting enhanced Jenkins configuration..."

# Wait for Jenkins to be fully ready
timeout 300 bash -c 'until curl -f http://localhost:8080/login >/dev/null 2>&1; do echo "Waiting for Jenkins..."; sleep 10; done'

# Install additional tools for cross-platform support
echo "Installing additional tools..."

# Install Node.js via NodeSource repository  
curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
yum install -y nodejs

# Install Terraform
TERRAFORM_VERSION="1.6.0"
wget -q https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip
sudo mv terraform /usr/local/bin/
sudo chmod +x /usr/local/bin/terraform
rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip

# Install Python 3 and tools
yum install -y python3 python3-pip

# Verify tool installations
echo "Verifying tool installations..."
node --version
terraform version
python3 --version
aws --version

# Enhanced Jenkins plugin installation
echo "Installing enhanced Jenkins plugins..."
java -jar /var/lib/jenkins/jenkins-cli.jar -s http://localhost:8080/ -auth admin:admin123! install-plugin \
    workflow-aggregator \
    git \
    github \
    github-branch-source \
    blueocean \
    aws-credentials-binding \
    pipeline-stage-view \
    build-timeout \
    timestamper \
    ws-cleanup \
    webhook-step \
    pipeline-github-lib \
    github-pullrequest \
    nodejs \
    python \
    terraform \
    pipeline-utility-steps \
    build-name-setter \
    build-user-vars-plugin \
    email-ext \
    notification \
    || echo "Some plugins may already be installed"

# Restart Jenkins to load new plugins
echo "Restarting Jenkins to load plugins..."
systemctl restart jenkins
sleep 30

# Wait for Jenkins to be ready
timeout 300 bash -c 'until curl -f http://localhost:8080/login >/dev/null 2>&1; do echo "Waiting for Jenkins restart..."; sleep 10; done'

# Configure GitHub webhook integration
echo "Configuring GitHub webhook integration..."
cat > /tmp/webhook-config.groovy << 'EOF'
import jenkins.model.Jenkins
import org.jenkinsci.plugins.github.config.GitHubPluginConfig
import org.jenkinsci.plugins.github.config.GitHubServerConfig
import com.cloudbees.jenkins.GitHubPushTrigger

def instance = Jenkins.getInstance()

// Configure GitHub plugin
def githubConfig = instance.getDescriptor(GitHubPluginConfig.class)
if (githubConfig != null) {
    githubConfig.setManageHooks(true)
    githubConfig.save()
    println "GitHub webhook management enabled"
}

// Configure GitHub push trigger
def pushTriggerDesc = instance.getDescriptor(GitHubPushTrigger.class)
if (pushTriggerDesc != null) {
    pushTriggerDesc.setManageHooks(true)
    pushTriggerDesc.save()
    println "GitHub push trigger configured"
}

instance.save()
println "GitHub integration configuration completed"
EOF

# Apply webhook configuration
java -jar /var/lib/jenkins/jenkins-cli.jar -s http://localhost:8080/ -auth admin:admin123! groovy = < /tmp/webhook-config.groovy

# Configure global tools
echo "Configuring global tools..."
cat > /tmp/tools-config.groovy << 'EOF'
import jenkins.model.Jenkins
import hudson.model.JDK
import hudson.tools.*
import jenkins.plugins.nodejs.tools.*

def instance = Jenkins.getInstance()

// Configure Node.js
def nodeJSInstallations = [
    new NodeJSInstallation("NodeJS-18", "/usr/bin", null)
]

def nodeJSDesc = instance.getDescriptor("jenkins.plugins.nodejs.tools.NodeJSInstallation")
nodeJSDesc.setInstallations(nodeJSInstallations as NodeJSInstallation[])

// Configure Git (should already be available)
def gitInstallations = [
    new GitTool("Default", "/usr/bin/git", null)
]

def gitDesc = instance.getDescriptor("hudson.plugins.git.GitTool") 
if (gitDesc != null) {
    gitDesc.setInstallations(gitInstallations as GitTool[])
}

instance.save()
println "Global tools configuration completed"
EOF

# Apply tools configuration
java -jar /var/lib/jenkins/jenkins-cli.jar -s http://localhost:8080/ -auth admin:admin123! groovy = < /tmp/tools-config.groovy

# Create automated deployment job
echo "Creating automated deployment job..."
cat > /tmp/auto-job.xml << EOF
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <actions/>
  <description>Automated deployment pipeline for ${github_repo} with cross-platform support</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
      <triggers>
        <com.cloudbees.jenkins.GitHubPushTrigger plugin="github">
          <spec></spec>
        </com.cloudbees.jenkins.GitHubPushTrigger>
      </triggers>
    </org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
    <hudson.model.ParametersDefinitionProperty>
      <parameterDefinitions>
        <hudson.model.ChoiceParameterDefinition>
          <name>ENVIRONMENT</name>
          <description>Select the environment to deploy to</description>
          <choices class="java.util.Arrays\$ArrayList">
            <a class="string-array">
              <string>dev</string>
              <string>staging</string>
              <string>prod</string>
            </a>
          </choices>
        </hudson.model.ChoiceParameterDefinition>
        <hudson.model.BooleanParameterDefinition>
          <name>SKIP_TESTS</name>
          <description>Skip validation tests</description>
          <defaultValue>false</defaultValue>
        </hudson.model.BooleanParameterDefinition>
        <hudson.model.BooleanParameterDefinition>
          <name>DEPLOY_INFRASTRUCTURE</name>
          <description>Deploy Terraform templates and CloudFormation infrastructure</description>
          <defaultValue>true</defaultValue>
        </hudson.model.BooleanParameterDefinition>
      </parameterDefinitions>
    </hudson.model.ParametersDefinitionProperty>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps">
    <scm class="hudson.plugins.git.GitSCM" plugin="git">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>https://github.com/${github_owner}/${github_repo}.git</url>
          <credentialsId>github-token</credentialsId>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/main</name>
        </hudson.plugins.git.BranchSpec>
        <hudson.plugins.git.BranchSpec>
          <name>*/master</name>
        </hudson.plugins.git.BranchSpec>
        <hudson.plugins.git.BranchSpec>
          <name>*/features-*</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
      <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
      <submoduleCfg class="list"/>
      <extensions/>
    </scm>
    <scriptPath>Jenkinsfile</scriptPath>
    <lightweight>true</lightweight>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
EOF

# Create the Jenkins job
java -jar /var/lib/jenkins/jenkins-cli.jar -s http://localhost:8080/ -auth admin:admin123! create-job "${github_repo}-auto-pipeline" < /tmp/auto-job.xml || echo "Job may already exist, updating..."

# Update job if it exists
java -jar /var/lib/jenkins/jenkins-cli.jar -s http://localhost:8080/ -auth admin:admin123! update-job "${github_repo}-auto-pipeline" < /tmp/auto-job.xml || echo "Job updated or creation failed"

# Clean up temporary files
rm -f /tmp/webhook-config.groovy /tmp/tools-config.groovy /tmp/auto-job.xml

# Create enhanced info script
cat > /home/ec2-user/deployment-info.sh << EOF
#!/bin/bash
echo "=== Automated Jenkins Deployment Information ==="
echo "Jenkins URL: http://\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo "Webhook URL: http://\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080/github-webhook/"
echo ""
echo "=== Credentials ==="
echo "Default Admin User: admin"
echo "Default Admin Password: admin123!"
echo "Initial Admin Password: \$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword 2>/dev/null || echo 'Not available')"
echo ""
echo "=== GitHub Integration ==="
echo "Repository: https://github.com/${github_owner}/${github_repo}"
echo "Pipeline Job: ${github_repo}-auto-pipeline"
echo "Supported Branches: main, master, features-*"
echo ""
echo "=== Environment ==="
echo "AWS Region: ${aws_region}"
echo "Deployment Bucket: ${deployment_bucket}"
echo "Artifacts Bucket: ${jenkins_artifacts_bucket}"
echo ""
echo "=== Tools Installed ==="
echo "Node.js: \$(node --version 2>/dev/null || echo 'Not installed')"
echo "Terraform: \$(terraform version 2>/dev/null | head -1 || echo 'Not installed')"
echo "Python: \$(python3 --version 2>/dev/null || echo 'Not installed')"
echo "AWS CLI: \$(aws --version 2>/dev/null || echo 'Not installed')"
echo ""
echo "=== Monitoring ==="
echo "Jenkins Logs: sudo journalctl -u jenkins -f"
echo "System Logs: sudo tail -f /var/log/messages"
echo ""
echo "=== Quick Commands ==="
echo "Restart Jenkins: sudo systemctl restart jenkins"
echo "Check Status: sudo systemctl status jenkins"
echo "View Jobs: curl -u admin:admin123! http://localhost:8080/api/json"
EOF

chmod +x /home/ec2-user/deployment-info.sh

# Run the enhanced info script
echo "Generating deployment information..."
/home/ec2-user/deployment-info.sh > /home/ec2-user/jenkins-deployment-complete.log

# Final status check
echo "=== Final Setup Status ==="
echo "Jenkins Status: $(systemctl is-active jenkins)"
echo "Tools Check:"
echo "  - Node.js: $(node --version 2>/dev/null || echo 'MISSING')"
echo "  - Terraform: $(terraform version 2>/dev/null | head -1 || echo 'MISSING')"
echo "  - Python: $(python3 --version 2>/dev/null || echo 'MISSING')"
echo "  - AWS CLI: $(aws --version 2>/dev/null || echo 'MISSING')"

echo "Enhanced Jenkins setup completed successfully!"
echo "Check /home/ec2-user/jenkins-deployment-complete.log for detailed information."