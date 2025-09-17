pipeline {
    agent any
    
    environment {
        // Firebase project configuration  
        FIREBASE_PROJECT = 'jenkins-ws2-b6b91'
        
        // Remote server configuration
        REMOTE_USER = 'newbie'
        REMOTE_HOST = '118.69.34.46'
        REMOTE_PORT = '3334'
        REMOTE_PATH = '/usr/share/nginx/html/jenkins'
        REMOTE_DEPLOY_PATH = '/usr/share/nginx/html/jenkins/tannp/template2'
        
        // Deployment configuration
        PROJECT_NAME = 'web-performance-project1-initial'
        DEPLOY_FILES = 'index.html 404.html css js images'
        
        // Slack configuration
        SLACK_CHANNEL = '#lnd-2025-workshop-tannp'
        
        // Get current date for deployment folder
        DEPLOY_DATE = sh(script: "date +%Y%m%d", returnStdout: true).trim()
        
        // User name for notifications
        DEPLOY_USER = sh(script: "whoami", returnStdout: true).trim()
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out source code from SCM...'
                checkout scm
                
                // Display current branch and commit info
                script {
                    def gitCommit = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    def gitBranch = sh(script: "git rev-parse --abbrev-ref HEAD", returnStdout: true).trim()
                    echo "Building commit: ${gitCommit} on branch: ${gitBranch}"
                }
            }
        }
        
        stage('Build') {
            steps {
                echo 'Installing dependencies...'
                dir("${PROJECT_NAME}") {
                    sh 'npm install'
                }
            }
        }
        
        stage('Lint & Test') {
            steps {
                echo 'Running linting and tests...'
                dir("${PROJECT_NAME}") {
                    sh 'npm run test:ci'
                }
            }
            post {
                always {
                    // Archive test results if they exist
                    script {
                        if (fileExists("${PROJECT_NAME}/coverage")) {
                            publishHTML([
                                allowMissing: false,
                                alwaysLinkToLastBuild: true,
                                keepAll: true,
                                reportDir: "${PROJECT_NAME}/coverage/lcov-report",
                                reportFiles: 'index.html',
                                reportName: 'Coverage Report'
                            ])
                        }
                    }
                }
            }
        }
        
        stage('Deploy') {
            parallel {
                stage('Deploy to Firebase') {
                    steps {
                        echo 'Deploying to Firebase Hosting...'
                        script {
                            try {
                                // Prepare public folder for Firebase
                                dir("${PROJECT_NAME}") {
                                    sh '''
                                        mkdir -p public
                                        cp -r ./index.html ./404.html ./css ./js ./images ./public
                                    '''
                                }

                                // Deploy using Firebase token
                                withCredentials([string(credentialsId: 'firebase-token', variable: 'FIREBASE_TOKEN')]) {
                                    dir("${PROJECT_NAME}") {
                                        sh """
                                            firebase deploy --token "\$FIREBASE_TOKEN" --only hosting --project="${FIREBASE_PROJECT}"
                                        """
                                    }
                                }
                                echo "✅ Firebase deployment successful!"
                            } catch (Exception e) {
                                echo "⚠️ Firebase deployment failed: ${e.getMessage()}"
                                echo "This might be due to:"
                                echo "- Missing 'firebase-token' credential in Jenkins"
                                echo "- Invalid or expired Firebase token"
                                echo "- Project '${FIREBASE_PROJECT}' doesn't exist or no permissions"
                                echo "- Network connectivity issues"
                                echo ""
                                echo "💡 To fix this:"
                                echo "1. Run: firebase login:ci"
                                echo "2. Copy the generated token"
                                echo "3. Add to Jenkins Credentials as 'firebase-token' (Secret text)"
                                currentBuild.result = 'UNSTABLE'
                            }
                        }
                    }
                }
                
                stage('Deploy to Remote Server') {
                    steps {
                        echo 'Deploying to remote server...'
                        script {
                            try {
                                def RELEASE_DATE = new Date().format("yyyyMMddHHmmss")
                                def PRIVATE_FOLDER = "/usr/share/nginx/html/jenkins/tannp"
                                def DEPLOY_FOLDER = "/usr/share/nginx/html/jenkins/tannp/deploy"
                                def RELEASE_FOLDER = "${DEPLOY_FOLDER}/${RELEASE_DATE}"
                                def TEMPLATE_FOLDER = "/usr/share/nginx/html/jenkins/template2"
                                def REMOTE_PORT = 3334
                                def REMOTE_USER = "newbie"
                                def REMOTE_HOST = "118.69.34.46"

                                sshagent(credentials: ['remote-server-key']) {
                                    // Initialize private folder from template if empty
                                    sh """
                                        ssh -o StrictHostKeyChecking=no -p ${REMOTE_PORT} ${REMOTE_USER}@${REMOTE_HOST} '
                                            mkdir -p ${PRIVATE_FOLDER}
                                            if [ -z "\$(ls -A ${PRIVATE_FOLDER})" ]; then
                                                cp -r ${TEMPLATE_FOLDER}/* ${PRIVATE_FOLDER}
                                            fi
                                        '
                                    """

                                    // Create release folder
                                    sh """
                                        ssh -o StrictHostKeyChecking=no -p ${REMOTE_PORT} ${REMOTE_USER}@${REMOTE_HOST} "mkdir -p ${RELEASE_FOLDER}"
                                    """

                                    // Copy files to release folder
                                    dir("${PROJECT_NAME}") {
                                        sh """
                                            scp -o StrictHostKeyChecking=no -P ${REMOTE_PORT} -r ./index.html ./404.html ./css ./js ./images ${REMOTE_USER}@${REMOTE_HOST}:${RELEASE_FOLDER}
                                        """
                                    }

                                    // Create symlink to current release
                                    sh """
                                        ssh -o StrictHostKeyChecking=no -p ${REMOTE_PORT} ${REMOTE_USER}@${REMOTE_HOST} "rm -rf ${DEPLOY_FOLDER}/current && ln -s ${RELEASE_FOLDER} ${DEPLOY_FOLDER}/current"
                                    """

                                    // Cleanup old releases (keep 5 most recent)
                                    sh """
                                        ssh -o StrictHostKeyChecking=no -p ${REMOTE_PORT} ${REMOTE_USER}@${REMOTE_HOST} '
                                            cd ${DEPLOY_FOLDER} && ls -1t | grep -v "^current\$" | tail -n +6 | xargs -r rm -rf
                                        '
                                    """
                                }
                                echo "✅ Remote server deployment successful!"
                            } catch (Exception e) {
                                echo "⚠️ Remote server deployment failed: ${e.getMessage()}"
                                echo "This might be due to:"
                                echo "- SSH key authentication issues"
                                echo "- Network connectivity to ${REMOTE_HOST}:${REMOTE_PORT}"
                                echo "- Permission issues on remote server"
                                currentBuild.result = 'UNSTABLE'
                            }
                        }
                    }
                }
            }
        }
    }
    
    post {
        success {
            echo 'Pipeline completed successfully!'
            script {
                def gitCommit = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                def gitBranch = sh(script: "git rev-parse --abbrev-ref HEAD", returnStdout: true).trim()
                
                try {
                    slackSend(
                        channel: env.SLACK_CHANNEL,
                        color: 'good',
                        message: """
                            ✅ *Deployment Successful!*
                            
                            *User:* ${env.DEPLOY_USER}
                            *Job:* ${env.JOB_NAME} #${env.BUILD_NUMBER}
                            *Branch:* ${gitBranch}
                            *Commit:* ${gitCommit}
                            *Duration:* ${currentBuild.durationString}
                            
                            🚀 Successfully deployed to Firebase and Remote Server
                            📅 Deploy Date: ${env.DEPLOY_DATE}
                        """.stripIndent()
                    )
                } catch (Exception slackError) {
                    echo "⚠️ Slack notification failed: ${slackError.getMessage()}"
                }
            }
        }
        
        failure {
            echo 'Pipeline failed!'
            script {
                // Get git info before any cleanup
                def gitCommit = "unknown"
                def gitBranch = "unknown"
                
                try {
                    gitCommit = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    gitBranch = sh(script: "git rev-parse --abbrev-ref HEAD", returnStdout: true).trim()
                } catch (Exception e) {
                    echo "Could not get git info: ${e.getMessage()}"
                }
                
                try {
                    slackSend(
                        channel: env.SLACK_CHANNEL,
                        color: 'danger',
                        message: """
                            ❌ *Deployment Failed!*
                            
                            *User:* ${env.DEPLOY_USER}
                            *Job:* ${env.JOB_NAME} #${env.BUILD_NUMBER}
                            *Branch:* ${gitBranch}
                            *Commit:* ${gitCommit}
                            *Duration:* ${currentBuild.durationString}
                            
                            💥 Please check the build logs for details
                            🔗 Build URL: ${env.BUILD_URL}
                        """.stripIndent()
                    )
                } catch (Exception slackError) {
                    echo "⚠️ Slack notification failed: ${slackError.getMessage()}"
                    echo "Please check Slack configuration in Jenkins system settings"
                }
            }
        }
        
        unstable {
            echo 'Pipeline completed with warnings!'
            script {
                // Get git info before any cleanup
                def gitCommit = "unknown"
                def gitBranch = "unknown"
                
                try {
                    gitCommit = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    gitBranch = sh(script: "git rev-parse --abbrev-ref HEAD", returnStdout: true).trim()
                } catch (Exception e) {
                    echo "Could not get git info: ${e.getMessage()}"
                }
                
                try {
                    slackSend(
                        channel: env.SLACK_CHANNEL,
                        color: 'warning',
                        message: """
                            ⚠️ *Deployment Completed with Warnings*
                            
                            *User:* ${env.DEPLOY_USER}
                            *Job:* ${env.JOB_NAME} #${env.BUILD_NUMBER}
                            *Branch:* ${gitBranch}
                            *Commit:* ${gitCommit}
                            *Duration:* ${currentBuild.durationString}
                            
                            🔍 Please review the build logs
                            🔗 Build URL: ${env.BUILD_URL}
                        """.stripIndent()
                    )
                } catch (Exception slackError) {
                    echo "⚠️ Slack notification failed: ${slackError.getMessage()}"
                }
            }
        }
        
        always {
            echo 'Cleaning up workspace...'
            cleanWs()
        }
    }
    
    triggers {
        // Auto-run on SCM changes (GitHub webhook)
        githubPush()
    }
}