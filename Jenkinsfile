// ============================================================================
// JENKINSFILE - Snyk Scan
// ============================================================================
// Deploys AWS infrastructure and Snyk scan
// ============================================================================

pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = 'us-east-1'
        TF_IN_AUTOMATION = 'true'
        SNYK_ORG = credentials('snyk-org-slug')
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        // --------------------------------------------------------------------
        // STAGE: Snyk IaC Scan Test (CLI Method)
        // --------------------------------------------------------------------
        // Tests infrastructure code using Snyk CLI. 
        // The || true ensures pipeline continues even if issues found.
        // --------------------------------------------------------------------
        stage('Snyk IaC Scan Test') {
            steps {
                withCredentials([string(credentialsId: 'snyk-api-token-string', variable: 'SNYK_TOKEN')]) {
                    sh '''
                        # Use pre-installed Snyk or install if needed
                        if command -v snyk &> /dev/null; then
                            SNYK_CMD="snyk"
                        else
                            SNYK_CMD="/var/lib/jenkins/tools/io.snyk.jenkins.tools.SnykInstallation/snyk/snyk-linux"
                        fi
                        
                        # Authenticate
                        $SNYK_CMD auth $SNYK_TOKEN
                        
                        # Run IaC test
                        $SNYK_CMD iac test --org=$SNYK_ORG --severity-threshold=high || true
                    '''
                }
            }
        }

        // --------------------------------------------------------------------
        // STAGE: Snyk IaC Scan Monitor (Plugin Method)
        // --------------------------------------------------------------------
        // Runs Snyk scan and reports results to Snyk platform.
        // Generates HTML report for local viewing.
        // --------------------------------------------------------------------
        stage('Snyk IaC Scan Monitor') {
            steps {
                snykSecurity(
                    snykInstallation: 'snyk',
                    snykTokenId: 'snyk-api-token',
                    additionalArguments: '--iac --report --org=$SNYK_ORG --severity-threshold=high',
                    failOnIssues: false,  // Don't fail pipeline on findings
                    monitorProjectOnBuild: false
                )
            }
        }

        // --------------------------------------------------------------------
        // STAGE: Terraform Init
        // --------------------------------------------------------------------
        stage('Terraform Init') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-iam-user-creds'
                ]]) {
                    sh 'terraform init -reconfigure'
                }
            }
        }

        // --------------------------------------------------------------------
        // STAGE: Terraform Plan
        // --------------------------------------------------------------------
        stage('Terraform Plan') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-iam-user-creds'
                ]]) {
                    sh 'terraform plan'
                }
            }
        }

        // --------------------------------------------------------------------
        // STAGE: Optional Destroy
        // --------------------------------------------------------------------
        stage('Optional Destroy') {
            steps {
                script {
                    def destroyChoice = input(
                        message: 'Do you want to run terraform destroy?',
                        ok: 'Submit',
                        parameters: [
                            choice(
                                name: 'DESTROY',
                                choices: ['no', 'yes'],
                                description: 'Select yes to destroy resources'
                            )
                        ]
                    )

                    if (destroyChoice == 'yes') {
                        withCredentials([[
                            $class: 'AmazonWebServicesCredentialsBinding',
                            credentialsId: 'aws-iam-user-creds'
                        ]]) {
                            sh 'terraform destroy -auto-approve'
                        }
                    } else {
                        echo "Skipping destroy"
                    }
                }
            }
        }
    }

    post {
        success {
            echo '✅ Pipeline completed successfully!'
        }
        failure {
            echo '❌ Pipeline failed!'
        }
    }
}