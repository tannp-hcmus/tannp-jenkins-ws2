pipeline {
    agent any

    triggers {
        // Trigger build on GitHub push events
        githubPush()
        // Poll SCM every 5 minutes as backup
        pollSCM('H/5 * * * *')
    }

    parameters {
        choice(
            name: 'DEPLOY_ENVIRONMENT',
            choices: ['both', 'firebase', 'remote', 'local'],
            description: 'Choose deployment environment: both (Firebase + Remote), firebase (Hosting), remote (Server), or local (template2)'
        )
        string(
            name: 'YOUR_NAME',
            defaultValue: 'tannp',
            description: 'Your name for creating personal deployment folder (e.g., tannp)'
        )
        string(
            name: 'KEEP_DEPLOYMENTS',
            defaultValue: '5',
            description: 'Number of deployment folders to keep (older ones will be deleted)'
        )
        string(
            name: 'SLACK_CHANNEL',
            defaultValue: '#lnd-2025-workshop2-tannp',
            description: 'Slack channel for notifications (e.g., #jenkins-notifications)'
        )
        string(
            name: 'SLACK_TEAM_DOMAIN',
            defaultValue: 'ventura-vn',
            description: 'Slack workspace domain (e.g., your-company)'
        )
    }

    environment {
        // Firebase credentials
        FIREBASE_TOKEN = credentials('firebase-token')
        FIREBASE_PROJECT = 'jenkins-ws2-b6b91'

        // Remote server credentials
        SSH_USER = 'newbie'              // SSH user for connection
        DEPLOY_SERVER = '118.69.34.46'   // SSH server
        SSH_PORT = '3334'                // SSH port
        WEB_SERVER = '10.1.1.195'        // Web server for HTTP access
        SSH_KEY = credentials('remote-server-key')  // Should be newbie_id_rsa

        // Deployment paths
        REMOTE_BASE_PATH = "/usr/share/nginx/html/jenkins"
        DEPLOY_USER = "${params.YOUR_NAME}"      // Directory name based on YOUR_NAME parameter
        TIMESTAMP = sh(script: 'date +%Y%m%d%H%M%S', returnStdout: true).trim()
        KEEP_DEPLOYMENTS = "${params.KEEP_DEPLOYMENTS}"  // Number of deployments to keep

        // Slack notification
        SLACK_WEBHOOK_URL = credentials('slack-token')  // Slack webhook URL credential
        SLACK_CHANNEL = "${params.SLACK_CHANNEL}"      // Slack channel from parameters
        SLACK_TEAM_DOMAIN = "${params.SLACK_TEAM_DOMAIN}"  // Slack workspace from parameters
    }

    stages {
        stage('Branch Check') {
            steps {
                script {
                    def currentBranch = env.GIT_BRANCH ?: sh(script: 'git rev-parse --abbrev-ref HEAD', returnStdout: true).trim()
                    echo "🌿 Current branch: ${currentBranch}"

                    // Remove origin/ prefix if present
                    currentBranch = currentBranch.replaceAll(/^origin\//, '')
                    if (currentBranch != 'main') {
                        echo "⚠️ Skipping deployment - not on main branch (current: ${currentBranch})"
                        env.SKIP_DEPLOYMENT = 'true'
                    } else {
                        echo "✅ On main branch - proceeding with deployment"
                        env.SKIP_DEPLOYMENT = 'false'
                    }
                }
            }
        }

        stage('Environment Check') {
            steps {
                echo "🔍 Kiểm tra môi trường build..."

                sh '''
                    # Kiểm tra phiên bản Node.js (cần >= 20.0.0 cho Firebase CLI)
                    NODE_VERSION=$(node --version | cut -d'v' -f2)
                    NODE_MAJOR=$(echo $NODE_VERSION | cut -d'.' -f1)
                    echo "📋 Node.js version: $NODE_VERSION"

                    if [ "$NODE_MAJOR" -lt 20 ]; then
                        echo "❌ LỖI: Node.js version $NODE_VERSION không tương thích với Firebase CLI (yêu cầu: >= 20.0.0)"
                        exit 1
                    fi

                    # Kiểm tra Firebase CLI
                    if ! command -v firebase >/dev/null 2>&1; then
                        echo "❌ Không tìm thấy Firebase CLI"
                        exit 1
                    fi

                    # Hiển thị thông tin môi trường
                    echo "✅ Kiểm tra môi trường thành công"
                    echo "📦 npm version: $(npm --version)"
                    echo "🔥 Firebase CLI version: $(firebase --version)"
                '''
            }
        }

        stage('Checkout & Verify') {
            steps {
                echo "📥 Lấy source code từ repository..."
                checkout scm

                sh '''
                    # Kiểm tra các file quan trọng
                    echo "🔍 Kiểm tra các file cần thiết..."
                    for file in package.json index.html js css images; do
                        if [ -e "$file" ]; then
                            echo "✅ Tìm thấy: $file"
                        else
                            echo "❌ Thiếu file/thư mục quan trọng: $file"
                            exit 1
                        fi
                    done
                    echo "✅ Tất cả file cần thiết đã có đầy đủ"
                '''
            }
        }

        stage('Build') {
            steps {
                echo "📦 Cài đặt dependencies và build project..."
                sh '''
                    # Cài đặt dependencies
                    echo "📦 Đang cài đặt npm dependencies..."
                    npm ci --silent
                    echo "✅ Dependencies đã được cài đặt"
                '''
            }
        }

        stage('Quality Check') {
            steps {
                echo "🧪 Chạy kiểm tra chất lượng code và tests..."
                sh '''
                    echo "🔍 Đang chạy linting và tests..."
                    npm run test:ci
                    echo "✅ Tất cả tests đã pass"
                '''
            }
            post {
                always {
                    // Archive test results if available
                    script {
                        if (fileExists('coverage/')) {
                            echo "📊 Lưu trữ kết quả test coverage..."
                            publishHTML([
                                allowMissing: false,
                                alwaysLinkToLastBuild: true,
                                keepAll: true,
                                reportDir: 'coverage/lcov-report',
                                reportFiles: 'index.html',
                                reportName: 'Báo cáo Test Coverage'
                            ])
                        }
                    }
                }
            }
        }

        stage('Deploy') {
            when {
                allOf {
                    // Only deploy if tests pass
                    expression { currentBuild.currentResult == null || currentBuild.currentResult == 'SUCCESS' }
                    // Only deploy on main branch
                    expression { env.SKIP_DEPLOYMENT != 'true' }
                }
            }

            steps {
                script {
                    // Xác định target deployment
                    def deployTarget = params.DEPLOY_ENVIRONMENT

                    echo "🚀 Bắt đầu deployment đến: ${deployTarget}"

                    // Chuẩn bị các file deployment
                    sh '''
                        # Tạo thư mục staging cho deployment
                        echo "📁 Tạo deployment staging area..."
                        rm -rf deploy-staging
                        mkdir -p deploy-staging

                        # Copy các file cần thiết
                        echo "📋 Copy files cho deployment..."
                        cp index.html 404.html deploy-staging/
                        cp -r css js images deploy-staging/
                        [ -f firebase.json ] && cp firebase.json deploy-staging/
                        [ -f .firebaserc ] && cp .firebaserc deploy-staging/
                        [ -f eslint.config.js ] && cp eslint.config.js deploy-staging/
                        [ -f package.json ] && cp package.json deploy-staging/

                        echo "✅ Deployment package đã sẵn sàng"
                    '''

                    // Deploy to local environment
                    if (deployTarget == 'local' || deployTarget == 'both') {
                        echo "📱 Deploy đến Local environment..."

                        sh '''
                            chmod +x deploy-local.sh
                            ./deploy-local.sh
                            echo "✅ Local deployment hoàn thành"
                        '''
                    }

                    // Deploy to Firebase Hosting
                    if (deployTarget == 'firebase' || deployTarget == 'both') {
                        echo "🔥 Deploy đến Firebase Hosting..."

                        sh '''
                            chmod +x deploy-firebase.sh
                            ./deploy-firebase.sh
                            echo "✅ Firebase deployment hoàn thành"
                        '''
                    }

                    // Deploy to remote server
                    if (deployTarget == 'remote' || deployTarget == 'both') {
                        echo "🌐 Deploy đến Remote Server..."

                        sh '''
                            echo "🔧 Chạy remote deployment script..."
                            chmod +x deploy-remote.sh
                            echo "🚀 Thực thi deploy-remote.sh..."
                            ./deploy-remote.sh
                            echo "✅ Remote deployment hoàn thành"
                        '''
                    }
                }
            }
        }
    }

    post {
        always {
            // Clean up
            sh 'rm -rf deploy-staging'

            // Archive artifacts
            archiveArtifacts artifacts: 'index.html,404.html,css/**,js/**,images/**,eslint.config.js,package.json', allowEmptyArchive: true
        }
        success {
            script {
                sendSlackNotification(true)
            }
        }
        failure {
            script {
                sendSlackNotification(false)
            }
        }
    }
}

def sendSlackNotification(boolean isSuccess) {
    try {
        // Get git info safely
        def author = sh(script: 'git log -1 --pretty=format:"%an" 2>/dev/null || echo "Unknown"', returnStdout: true).trim()
        def releaseDate = sh(script: 'date +%Y%m%d', returnStdout: true).trim()

        // Build message and set color
        def message = ""
        def color = ""

        if (isSuccess) {
            message = ":white_check_mark: *BUILD SUCCESS*\n" +
                     "Author: ${author}\n" +
                     "Job: ${env.JOB_NAME} #${env.BUILD_NUMBER}\n" +
                     "Release: ${releaseDate}" +
                     getDeploymentLinks()
            color = "good"  // Green color
        } else {
            message = ":x: *BUILD FAILED*\n" +
                     "Author: ${author}\n" +
                     "Job: ${env.JOB_NAME} #${env.BUILD_NUMBER}\n" +
                     "Console: ${env.BUILD_URL}console"
            color = "danger"  // Red color
        }

        // Send notification using Slack plugin
        slackSend(
            channel: env.SLACK_CHANNEL,     // Use environment variable
            color: color,
            message: message,
            teamDomain: env.SLACK_TEAM_DOMAIN,  // Use environment variable
            token: env.SLACK_WEBHOOK_URL    // Use existing environment variable
        )

        echo "✅ Slack notification sent successfully using plugin"

    } catch (Exception e) {
        echo "⚠️ Slack notification error: ${e.getMessage()}"
    }
}

def getDeploymentLinks() {
    def target = params.DEPLOY_ENVIRONMENT
    def links = ""

    if (target == 'firebase' || target == 'both') {
        links += "\n:fire: Firebase: https://${env.FIREBASE_PROJECT}.web.app"
    }
    if (target == 'remote' || target == 'both') {
        links += "\n:globe_with_meridians: Remote: http://${env.WEB_SERVER}/jenkins/${env.DEPLOY_USER}/current/"
    }
    if (target == 'local') {
        links += "\n:computer: Local: Deployment completed"
    }

    return links
}