pipeline {
    agent any
    
    environment {
        // Firebase project configuration
        FIREBASE_PROJECT = 'tannp-jenkins-ws2'
        
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
                        dir("${PROJECT_NAME}") {
                            script {
                                // Check if Firebase token is available
                                withCredentials([string(credentialsId: 'firebase-token', variable: 'FIREBASE_TOKEN')]) {
                                    sh '''
                                        echo "Deploying to Firebase project: ${FIREBASE_PROJECT}"
                                        firebase deploy --token "$FIREBASE_TOKEN" --only hosting --project="${FIREBASE_PROJECT}"
                                    '''
                                }
                            }
                        }
                    }
                }
                
                stage('Deploy to Remote Server') {
                    steps {
                        echo 'Deploying to remote server...'
                        script {
                            withCredentials([sshUserPrivateKey(credentialsId: 'remote-server-key', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
                                sh '''
                                    # Create deployment directory structure on remote server
                                    ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} -p ${REMOTE_PORT} ${REMOTE_USER}@${REMOTE_HOST} "
                                        mkdir -p ${REMOTE_DEPLOY_PATH}/${PROJECT_NAME}
                                        mkdir -p ${REMOTE_DEPLOY_PATH}/deploy/${DEPLOY_DATE}
                                    "
                                    
                                    # Copy necessary files to remote server
                                    cd ${PROJECT_NAME}
                                    for file in ${DEPLOY_FILES}; do
                                        if [ -e "$file" ]; then
                                            scp -o StrictHostKeyChecking=no -i ${SSH_KEY} -P ${REMOTE_PORT} -r "$file" ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DEPLOY_PATH}/${PROJECT_NAME}/
                                            scp -o StrictHostKeyChecking=no -i ${SSH_KEY} -P ${REMOTE_PORT} -r "$file" ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DEPLOY_PATH}/deploy/${DEPLOY_DATE}/
                                        fi
                                    done
                                    
                                    # Create/update symlink and cleanup old deployments
                                    ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} -p ${REMOTE_PORT} ${REMOTE_USER}@${REMOTE_HOST} "
                                        cd ${REMOTE_DEPLOY_PATH}/deploy
                                        rm -f current
                                        ln -sf ${DEPLOY_DATE} current
                                        
                                        # Keep only 5 most recent deployments
                                        ls -t | grep -E '^[0-9]{8}$' | tail -n +6 | xargs rm -rf
                                        
                                        echo 'Deployment structure:'
                                        ls -la ${REMOTE_DEPLOY_PATH}/
                                        echo 'Deploy versions:'
                                        ls -la ${REMOTE_DEPLOY_PATH}/deploy/
                                    "
                                '''
                            }
                        }
                    }
                }
            }
        }
    }
    
    post {
        always {
            echo 'Cleaning up workspace...'
            cleanWs()
        }
        
        success {
            echo 'Pipeline completed successfully!'
            script {
                def gitCommit = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                def gitBranch = sh(script: "git rev-parse --abbrev-ref HEAD", returnStdout: true).trim()
                
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
            }
        }
        
        failure {
            echo 'Pipeline failed!'
            script {
                def gitCommit = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                def gitBranch = sh(script: "git rev-parse --abbrev-ref HEAD", returnStdout: true).trim()
                
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
            }
        }
        
        unstable {
            echo 'Pipeline completed with warnings!'
            script {
                def gitCommit = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                def gitBranch = sh(script: "git rev-parse --abbrev-ref HEAD", returnStdout: true).trim()
                
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
            }
        }
    }
    
    triggers {
        // Auto-run on SCM changes (GitHub webhook)
        githubPush()
    }
}