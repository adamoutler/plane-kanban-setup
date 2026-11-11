// Jenkinsfile for Plane Kanban Deployment (Simplified AIO)
pipeline {
    agent { label 'inferrence1' }
    environment {
        // Production Domain & Protocol Overrides
        DOMAIN_NAME = 'kanban.hackedyour.info'
        WEB_URL = 'https://kanban.hackedyour.info'
        CORS_ALLOWED_ORIGINS = 'https://kanban.hackedyour.info'
        APP_PROTOCOL = 'https'

        // Production S3/MinIO Endpoint Overrides
        AWS_S3_ENDPOINT_URL = 'https://kanban.hackedyour.info'
        MINIO_ENDPOINT_SSL = '1'

        // Production Gitea / Forgejo OAuth Overrides
        GITEA_HOST = 'https://git.adamoutler.com'
        IS_GITEA_ENABLED = '1'

        // Production MCP Server Overrides
        MCP_IMAGE = 'adamoutler/plane-mcp-server:plane-agent'
        PLANE_BASE_URL = 'https://kanban.hackedyour.info'
        PLANE_OAUTH_PROVIDER_BASE_URL = 'https://kanban.hackedyour.info/mcp/http'
    }
    stages {
        stage('Initialize Build') {
            steps {
                sh """
                    rm -f /tmp/jenkins-receipt-plane.log
                    echo '--- DEPLOYMENT STARTING #${env.BUILD_NUMBER} ---' > deployment.log
                    echo 'Build Number: ${env.BUILD_NUMBER}' >> deployment.log
                    echo "Deployment Started: \$(date)" >> deployment.log
                    cp deployment.log /tmp/jenkins-receipt-plane.log
                    sync
                """
            }
        }
        
        stage('Source Update') {
            steps {
                dir('/home/adamoutler/plane') {
                    sh '''
                        git fetch --all
                        git reset --hard origin/master
                        git submodule update --init --recursive
                        git submodule update --remote plane
                    '''
                }
            }
        }

        stage('Docker Deploy Plane AIO') {
            environment {
                PGPASSWORD = sh(script: "set +x; openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c32", returnStdout: true).trim()
                AWS_SECRET_ACCESS_KEY = sh(script: "set +x; openssl rand -hex 32", returnStdout: true).trim()
                SECRET_KEY = credentials('plane-secret-key')
            }
            steps {
                withCredentials([usernamePassword(credentialsId: 'plane-kanban-oauth-clientid-secret', passwordVariable: 'PLANE_FORGEJO_CLIENT_SECRET', usernameVariable: 'PLANE_FORGEJO_CLIENT_ID')]) {
                    dir('/home/adamoutler/plane') {
                        // Refresh every upstream image on each deployment; MCP retains its development tag.
                        sh "docker compose pull --policy always"
                        sh '''
                            # Deploy AIO stack, discarding malformed anonymous volumes from the upstream image
                            docker compose up -d --build --force-recreate --renew-anon-volumes
                            
                            echo "Waiting for services to stabilize..."
                            sleep 20
                            
                            # Update Postgres password dynamically
                            set +x
                            docker exec plane-db psql -U plane -c "ALTER USER plane WITH PASSWORD '${PGPASSWORD}';"
                        '''
                    }
                }
            }
        }
        
        stage('Verify System') {
            steps {
                sh '''
                    # Confirm bucket initialization succeeded and storage is responding.
                    test "$(docker inspect -f '{{.State.ExitCode}}' plane-minio-setup)" = 0
                    curl --fail --silent --show-error --max-time 10 http://localhost:9000/minio/health/live
                    # Check if the AIO port is responding
                    for i in {1..10}; do
                        if curl -s http://localhost:8085 | grep -q "Plane"; then
                            echo "Plane AIO is up and responding."
                            exit 0
                        fi
                        echo "Waiting for Plane AIO... ($i/10)"
                        sleep 10
                    done
                    echo "Plane AIO failed to respond after 100 seconds."
                    exit 1
                '''
            }
        }
    }
    
    post {
        always {
            withCredentials([string(credentialsId: 'Adam-Jenkins-Token', variable: 'ADAM_TOKEN')]) {
                sh """
                    curl -sL -u "adamoutler@gmail.com:${ADAM_TOKEN}" "${env.BUILD_URL}consoleText" > /tmp/jenkins-receipt-plane.log
                    echo "Finished: ${currentBuild.currentResult} #${env.BUILD_NUMBER}" >> /tmp/jenkins-receipt-plane.log
                """
            }
        }
        failure {
            echo "Plane AIO Deployment failed. Check the logs."
        }
        success {
            echo "Plane AIO Deployment successful."
        }
    }
}
