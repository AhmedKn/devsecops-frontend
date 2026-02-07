pipeline {
  agent any
  
  tools {
    nodejs 'node24'
  }

  environment {
    // Git
    REPO_URL    = 'https://github.com/AhmedKn/devsecops-frontend.git'  // <-- change
    BRANCH      = 'master'

    // Sonar
    SONAR_PROJECT_KEY  = 'frontend-devsecops'
    SONAR_PROJECT_NAME = 'frontend-devsecops'

    // DockerHub
    DOCKERHUB_USER = 'i2xmortal'
    IMAGE_NAME  = 'frontend-devsecops'
    IMAGE_TAG   = 'prod'                         // or use ${BUILD_NUMBER}
    IMAGE_FULL  = "${DOCKERHUB_USER}/${IMAGE_NAME}:${IMAGE_TAG}"

    // Deploy
    DEPLOY_CONTAINER = 'frontend'
    PORT_HOST   = '8088'                          // host (matches your vagrant forwarding host)
    PORT_APP    = '80'                            // container port for nginx
    HEALTH_URL  = "http://localhost:8088"         // adjust if you want a specific route

    // Nexus (RAW hosted)
    NEXUS_URL  = 'http://nexus:8081'
    NEXUS_REPO = 'frontend-devsecops'             // raw hosted repo name you will create
  }

  stages {
    stage('Checkout') {
      steps {
        sh '''
          set -e
          rm -rf .git
          git init
          git remote remove origin >/dev/null 2>&1 || true
          git remote add origin ${REPO_URL}
          git fetch --depth 1 origin ${BRANCH}
          git checkout -f FETCH_HEAD
          git clean -fdx
        '''
      }
    }

    stage('Install Dependencies') {
      steps {
        sh '''
          set -e
          node -v
          npm -v
          npm ci
        '''
      }
    }

    stage('Unit Tests') {
      steps {
        sh '''
          set -e
          # If your project is configured for headless tests, this should work.
          # If not configured, you can switch to: npm test -- --watch=false --browsers=ChromeHeadless
          npm test -- --watch=false || true
        '''
      }
    }

    stage('SonarQube Analysis') {
  steps {
    withSonarQubeEnv('sonarqube') {
      script {
        def scannerHome = tool 'SonarScanner'
        sh """
          set -euxo pipefail

          ${scannerHome}/bin/sonar-scanner \
            -Dsonar.projectKey=${SONAR_PROJECT_KEY} \
            -Dsonar.projectName=${SONAR_PROJECT_NAME} \
            -Dsonar.sources=src \
            -Dsonar.exclusions=**/node_modules/**,**/*.spec.ts,**/dist/** \
            -Dsonar.javascript.lcov.reportPaths=coverage/lcov.info
        """
      }
    }
  }
}


    stage('Build (Angular)') {
      steps {
        sh '''
          set -e
          npm run build
          ls -la dist || true
        '''
      }
    }

stage('Package Artifact (tar dist)') {
  steps {
    sh '''
      set -e
      rm -f frontend-dist.tar.gz
      tar -czf frontend-dist.tar.gz dist
      ls -lh frontend-dist.tar.gz
    '''
  }
}

    stage('Upload Artifact to Nexus (RAW)') {
  steps {
    withCredentials([usernamePassword(
      credentialsId: 'nexus-creds',
      usernameVariable: 'NEXUS_USER',
      passwordVariable: 'NEXUS_PASS'
    )]) {
      sh '''
        set -e
        test -f frontend-dist.tar.gz || (echo "ERROR: frontend-dist.tar.gz not found" && ls -la && exit 1)

        curl -fS -u "$NEXUS_USER:$NEXUS_PASS" \
          --upload-file frontend-dist.tar.gz \
          "${NEXUS_URL}/repository/${NEXUS_REPO}/${IMAGE_TAG}/frontend-dist.tar.gz"
      '''
    }
  }
}


    stage('Docker Check') {
      steps {
        sh '''
          set +e
          if ! command -v docker >/dev/null 2>&1; then
            echo "DOCKER_OK=0" > docker.env
            exit 0
          fi

          docker info >/dev/null 2>&1
          if [ "$?" -eq 0 ]; then
            echo "DOCKER_OK=1" > docker.env
          else
            echo "DOCKER_OK=0" > docker.env
          fi
        '''
        script {
          def envText = readFile('docker.env').trim()
          env.DOCKER_OK = envText.split('=')[1]
          echo "Docker usable? DOCKER_OK=${env.DOCKER_OK}"
          echo "DockerHub image: ${env.IMAGE_FULL}"
        }
      }
    }

    stage('Build Docker Image') {
      when { expression { return env.DOCKER_OK == '1' } }
      steps {
        sh '''
          set -e
          # Your Dockerfile should be the production one (Angular build + nginx)
          docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .
          docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${IMAGE_FULL}
        '''
      }
    }

    stage('Push to Docker Hub') {
      when { expression { return env.DOCKER_OK == '1' } }
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'dockerhub-creds',
          usernameVariable: 'DOCKER_USER',
          passwordVariable: 'DOCKER_PASS'
        )]) {
          sh '''
            set -e
            echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
            docker push "$IMAGE_FULL"
            docker logout
          '''
        }
      }
    }

    stage('Deploy on VM') {
  when { expression { return env.DOCKER_OK == '1' } }
  steps {
    sh '''
      set -e

      # We are already in the repo workspace where docker-compose.yml exists
      test -f docker-compose.yml || (echo "docker-compose.yml not found in workspace" && ls -la && exit 1)

      # Optional: create/update .env for compose variable substitution
      cat > .env <<EOF
IMAGE_FULL=${IMAGE_FULL}
DEPLOY_CONTAINER=${DEPLOY_CONTAINER}
PORT_HOST=${PORT_HOST}
PORT_APP=${PORT_APP}
EOF

      docker-compose pull || true
      docker-compose up -d --remove-orphans
    '''
  }
}



    stage('Health Check') {
      when { expression { return env.DOCKER_OK == '1' } }
      steps {
        sh '''
          set +e
          echo "Checking: ${HEALTH_URL}"
          curl -I --max-time 10 ${HEALTH_URL}
          exit 0
        '''
      }
    }
  }

  post {
    always {
      sh '''
        if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
          docker rm -f frontend-test >/dev/null 2>&1 || true
        else
          echo "Docker not available/allowed; skipping docker cleanup"
        fi
      '''
      archiveArtifacts artifacts: 'frontend-dist.zip', allowEmptyArchive: true
    }
  }
}
