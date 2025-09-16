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

    parameters {
        choice(name: 'DEPLOY_TYPE', choices: ['all', 'firebase', 'remote'], description: 'The type of deployment')
        string(name: 'MAX_RELEASE', defaultValue: '5', description: 'Maximum number of releases to keep')
    }

    stages {
        stage('Checkout(scm)') {
            steps {
                echo '*************** Checkout ***************'
                checkout scm
                
                // Display current branch and commit info
                script {
                    def gitCommit = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    def gitBranch = sh(script: "git rev-parse --abbrev-ref HEAD", returnStdout: true).trim()
                    echo "Building commit: ${gitCommit} on branch: ${gitBranch}"
                    
                    // Get author email for notifications
                    env.GIT_AUTHOR_EMAIL = sh(
                        script: "git log -1 --pretty=format:'%ae' ${env.GIT_COMMIT}",
                        returnStdout: true
                    ).trim()
                }
            }
        }
        
        stage('Build') {
            steps {
                echo '*************** Build ***************'
                dir("${PROJECT_NAME}") {
                    sh 'npm install'
                }
            }
        }
        
        stage('Lint & Test') {
            steps {
                echo '*************** Lint/Test ***************'
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
            steps {
                echo '*************** Deploy ***************'
                script {
                    def deployTypes = []

                    if (params.DEPLOY_TYPE == 'all') {
                        deployTypes = ['firebase', 'remote']
                    } else {
                        deployTypes = [params.DEPLOY_TYPE]
                    }

                    for (deployType in deployTypes) {
                        echo "========> Deploying to ${deployType} <========="
                        
                        if (deployType == 'firebase') {
                            deployFirebase()
                        } else if (deployType == 'remote') {
                            deployRemote()
                        }
                    }
                }
            }
        }
    }
    
    post {
        success {
            echo '*************** Build SUCCESS ***************'
            script {
                def authorEmail = env.GIT_AUTHOR_EMAIL ?: 'Unknown'
                def gitCommit = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                def gitBranch = sh(script: "git rev-parse --abbrev-ref HEAD", returnStdout: true).trim()
                def repoUrl = env.GIT_URL.replaceFirst(/\.git$/, '')
                def commitUrl = "${repoUrl}/commit/${env.GIT_COMMIT}"
                def buildTime = new Date().format("yyyy-MM-dd HH:mm:ss", TimeZone.getTimeZone('Asia/Ho_Chi_Minh'))
                def deployTypeDisplay = params.DEPLOY_TYPE == 'all' ? 'all (firebase, remote)' : params.DEPLOY_TYPE

                def message = """
:unleashed-smite: *BUILD SUCCESS*
*Author*: ${authorEmail}
*User*: ${env.DEPLOY_USER}
*Job*: ${env.JOB_NAME}#${env.BUILD_NUMBER}
*Branch*: ${gitBranch}
*Commit*: ${commitUrl}
*Time*: ${buildTime}
*Deploy type*: ${deployTypeDisplay}
*Duration*: ${currentBuild.durationString}
""".trim()

                if (params.DEPLOY_TYPE == 'firebase') {
                    message += '\n*Firebase*: https://' + env.FIREBASE_PROJECT + '.web.app/'
                } else if (params.DEPLOY_TYPE == 'remote') {
                    message += '\n*Remote*: http://' + env.REMOTE_HOST + '/jenkins/tannp/template2/deploy/current/'
                } else if (params.DEPLOY_TYPE == 'all') {
                    message += '\n*Firebase*: https://' + env.FIREBASE_PROJECT + '.web.app/'
                    message += '\n*Remote*: http://' + env.REMOTE_HOST + '/jenkins/tannp/template2/deploy/current/'
                }

                try {
                    slackSend(
                        channel: env.SLACK_CHANNEL,
                        color: 'good',
                        message: message
                    )
                } catch (Exception slackError) {
                    echo "⚠️ Slack notification failed: ${slackError.getMessage()}"
                }
                echo message
            }
        }
        
        failure {
            echo '*************** Build FAILURE ***************'
            script {
                def authorEmail = env.GIT_AUTHOR_EMAIL ?: 'Unknown'
                def gitCommit = "unknown"
                def gitBranch = "unknown"
                
                try {
                    gitCommit = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    gitBranch = sh(script: "git rev-parse --abbrev-ref HEAD", returnStdout: true).trim()
                } catch (Exception e) {
                    echo "Could not get git info: ${e.getMessage()}"
                }
                
                def repoUrl = env.GIT_URL.replaceFirst(/\.git$/, '')
                def commitUrl = "${repoUrl}/commit/${env.GIT_COMMIT}"
                def buildTime = new Date().format("yyyy-MM-dd HH:mm:ss", TimeZone.getTimeZone('Asia/Ho_Chi_Minh'))
                def deployTypeDisplay = params.DEPLOY_TYPE == 'all' ? 'all (firebase, remote)' : params.DEPLOY_TYPE
                def logUrl = "${env.BUILD_URL}console"

                def message = """
:soc-dien: *BUILD FAILED*
*Author*: ${authorEmail}
*User*: ${env.DEPLOY_USER}
*Job*: ${env.JOB_NAME}#${env.BUILD_NUMBER}
*Branch*: ${gitBranch}
*Commit*: ${commitUrl}
*Time*: ${buildTime}
*Deploy type*: ${deployTypeDisplay}
*Duration*: ${currentBuild.durationString}
*Log*: ${logUrl}
""".trim()

                try {
                    slackSend(
                        channel: env.SLACK_CHANNEL,
                        color: 'danger',
                        message: message
                    )
                } catch (Exception slackError) {
                    echo "⚠️ Slack notification failed: ${slackError.getMessage()}"
                }
                echo message
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

// Firebase deployment function
def deployFirebase() {
    dir("${PROJECT_NAME}") {
        try {
            echo "Deploying to Firebase project: ${FIREBASE_PROJECT}"
            
            // Try Service Account first, fallback to token
            try {
                echo "Attempting Firebase deployment with Service Account..."
                withCredentials([file(credentialsId: 'firebase-service-account', variable: 'GOOGLE_APPLICATION_CREDENTIALS')]) {
                    sh '''
                        echo "Using Service Account (ADC)..."
                        firebase deploy --only hosting --project="${FIREBASE_PROJECT}"
                    '''
                }
                echo "✅ Firebase deployment successful using Service Account!"
            } catch (Exception serviceAccountError) {
                echo "Service Account failed, trying token method..."
                withCredentials([string(credentialsId: 'firebase-token', variable: 'FIREBASE_TOKEN')]) {
                    sh '''
                        echo "Using Firebase Token authentication..."
                        firebase deploy --token "$FIREBASE_TOKEN" --only hosting --project="${FIREBASE_PROJECT}"
                    '''
                }
                echo "✅ Firebase deployment successful using Token!"
            }
        } catch (Exception e) {
            echo "⚠️ Firebase deployment failed: ${e.getMessage()}"
            currentBuild.result = 'UNSTABLE'
        }
    }
}

// Remote server deployment function
def deployRemote() {
    try {
        def RELEASE_DATE = new Date().format("yyyyMMddHHmmss")
        def RELEASE_FOLDER = "${REMOTE_DEPLOY_PATH}/deploy/${RELEASE_DATE}"
        
        echo "Deploying to remote server..."
        echo "Release folder: ${RELEASE_FOLDER}"
        
        sshagent(credentials: ['remote-server-key']) {
            // Create deployment directories
            sh """
                ssh -o StrictHostKeyChecking=no -p ${REMOTE_PORT} ${REMOTE_USER}@${REMOTE_HOST} '
                    mkdir -p ${REMOTE_DEPLOY_PATH}/${PROJECT_NAME}
                    mkdir -p ${RELEASE_FOLDER}
                '
            """
            
            // Copy files to remote server
            dir("${PROJECT_NAME}") {
                sh """
                    echo "Copying files to remote server..."
                    scp -o StrictHostKeyChecking=no -P ${REMOTE_PORT} -r ${DEPLOY_FILES} ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DEPLOY_PATH}/${PROJECT_NAME}/
                    scp -o StrictHostKeyChecking=no -P ${REMOTE_PORT} -r ${DEPLOY_FILES} ${REMOTE_USER}@${REMOTE_HOST}:${RELEASE_FOLDER}/
                """
            }
            
            // Create symlink and cleanup
            sh """
                ssh -o StrictHostKeyChecking=no -p ${REMOTE_PORT} ${REMOTE_USER}@${REMOTE_HOST} '
                    cd ${REMOTE_DEPLOY_PATH}/deploy
                    rm -f current
                    ln -sf ${RELEASE_DATE} current
                    
                    # Keep only specified number of releases
                    ls -1t | grep -v "^current\$" | tail -n +\$((${params.MAX_RELEASE} + 1)) | xargs -r rm -rf
                    
                    echo "Deployment completed successfully!"
                    echo "Current structure:"
                    ls -la
                '
            """
        }
        echo "✅ Remote server deployment successful!"
    } catch (Exception e) {
        echo "⚠️ Remote server deployment failed: ${e.getMessage()}"
        currentBuild.result = 'UNSTABLE'
    }
}