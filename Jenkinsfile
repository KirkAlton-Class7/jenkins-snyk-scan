// JENKINSFILE - Snyk Scan

// Deploys AWS infrastructure and Snyk scan

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
        // STAGE: Snyk IaC Scan Test (CLI Method) - DELIBERATE FAILURE
        // --------------------------------------------------------------------
        // This stage is designed to FAIL with exit code 127 (command not found).
        // Why? The hardcoded path /var/lib/jenkins/tools/.../snyk-linux does NOT exist.
        // Jenkins Tool "snyk" is configured, but the script uses a brittle hardcoded path.
        // This demonstrates that adding a tool in Jenkins does NOT magically fix a wrong path.
        //
        // TO FIX FOR SUCCESSFUL SCAN (after this failure demo):
        //   Replace the hardcoded path with Jenkins' `tool` step:
        //     def snykHome = tool name: 'snyk', type: 'io.snyk.jenkins.tools.SnykInstallation'
        //     sh "$snykHome/snyk-linux auth ..."
        //   Or rely on the plugin stage below (Snyk IaC Scan Monitor).
        //
        // UNDERSTANDING: Exit code 127 = command not found. The pipeline stops here.
        // This is NOT a security finding – it's a missing dependency.
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
                    additionalArguments: "--iac --report --org=$SNYK_ORG --severity-threshold=high",
                    failOnIssues: false,
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
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed!'
        }
    }
}