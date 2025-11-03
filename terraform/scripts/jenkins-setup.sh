#!/bin/bash
# Jenkins installation and configuration script for Amazon Linux 2

# Update system
yum update -y

# Install Java 11 (required for Jenkins)
yum install -y java-11-amazon-corretto-headless

# Add Jenkins repository
wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key

# Install Jenkins
yum install -y jenkins

# Install Git
yum install -y git

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
yum install -y unzip
unzip awscliv2.zip
./aws/install

# Install Docker (for potential containerized builds)
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker jenkins

# Install additional tools
yum install -y wget curl

# Configure AWS credentials for Jenkins user
mkdir -p /var/lib/jenkins/.aws
cat > /var/lib/jenkins/.aws/credentials << EOF
[default]
aws_access_key_id = ${aws_access_key}
aws_secret_access_key = ${aws_secret_key}
EOF

cat > /var/lib/jenkins/.aws/config << EOF
[default]
region = ${aws_region}
output = json
EOF

# Set proper ownership
chown -R jenkins:jenkins /var/lib/jenkins/.aws
chmod 600 /var/lib/jenkins/.aws/credentials

# Start and enable Jenkins
systemctl start jenkins
systemctl enable jenkins

# Wait for Jenkins to start
sleep 30

# Get Jenkins initial admin password
JENKINS_PASSWORD=$(cat /var/lib/jenkins/secrets/initialAdminPassword)

# Create Jenkins configuration directory
mkdir -p /var/lib/jenkins/init.groovy.d

# Create Jenkins initial configuration script
cat > /var/lib/jenkins/init.groovy.d/basic-security.groovy << 'EOF'
#!groovy

import jenkins.model.*
import hudson.security.*
import jenkins.security.s2m.AdminWhitelistRule

def instance = Jenkins.getInstance()

// Create admin user
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount("admin", "admin123!")
instance.setSecurityRealm(hudsonRealm)

// Set authorization strategy
def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)

// Disable CLI over remoting
instance.getDescriptor("jenkins.CLI").get().setEnabled(false)

// Enable agent to master security subsystem
instance.getInjector().getInstance(AdminWhitelistRule.class).setMasterKillSwitch(false)

instance.save()
EOF

# Install Jenkins plugins
cat > /var/lib/jenkins/init.groovy.d/install-plugins.groovy << 'EOF'
#!groovy

import jenkins.model.*
import hudson.model.*
import hudson.PluginWrapper
import hudson.PluginManager

def instance = Jenkins.getInstance()
def pm = instance.getPluginManager()
def uc = instance.getUpdateCenter()

def plugins = [
    "git",
    "github",
    "github-branch-source",
    "pipeline-stage-view",
    "build-pipeline-plugin",
    "aws-credentials",
    "pipeline-aws",
    "s3",
    "cloudformation",
    "workflow-aggregator"
]

plugins.each {
    if (!pm.getPlugin(it)) {
        def plugin = uc.getPlugin(it)
        if (plugin) {
            plugin.deploy(true)
        }
    }
}

instance.save()
EOF

# Create Jenkins job for the repository
cat > /var/lib/jenkins/jobs/practice-learning-faus-project/config.xml << 'EOF'
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <actions/>
  <description>CI/CD Pipeline for ${github_repo}</description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
      <triggers>
        <com.cloudbees.jenkins.GitHubPushTrigger plugin="github">
          <spec></spec>
        </com.cloudbees.jenkins.GitHubPushTrigger>
      </triggers>
    </org.jenkinsci.plugins.workflow.job.properties.PipelineTriggersJobProperty>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps">
    <scm class="hudson.plugins.git.GitSCM" plugin="git">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>https://github.com/${github_owner}/${github_repo}.git</url>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/main</name>
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

# Set proper ownership for Jenkins files
chown -R jenkins:jenkins /var/lib/jenkins/

# Restart Jenkins to apply changes
systemctl restart jenkins

# Create a startup script to display Jenkins info
cat > /home/ec2-user/jenkins-info.sh << EOF
#!/bin/bash
echo "=== Jenkins Server Information ==="
echo "Jenkins URL: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
echo "Initial Admin Password: \$(sudo cat /var/lib/jenkins/secrets/initialAdminPassword)"
echo "Default Admin User: admin"
echo "Default Admin Password: admin123!"
echo ""
echo "GitHub Repository: https://github.com/${github_owner}/${github_repo}"
echo "AWS Region: ${aws_region}"
echo "Deployment Bucket: ${deployment_bucket}"
echo "Artifacts Bucket: ${jenkins_artifacts_bucket}"
echo ""
echo "Jenkins Logs: sudo journalctl -u jenkins -f"
EOF

chmod +x /home/ec2-user/jenkins-info.sh

# Run the info script once
/home/ec2-user/jenkins-info.sh > /home/ec2-user/jenkins-setup-complete.log

echo "Jenkins setup completed!"