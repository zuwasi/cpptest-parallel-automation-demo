pipeline {
    agent any

    options {
        timestamps()
    }

    stages {
        stage('Parallel C++test analysis') {
            parallel {
                stage('Project Alpha') {
                    steps {
                        powershell '.\\scripts\\run-analysis.ps1 -Project project-alpha'
                    }
                }
                stage('Project Beta') {
                    steps {
                        powershell '.\\scripts\\run-analysis.ps1 -Project project-beta'
                    }
                }
                stage('Project Gamma') {
                    steps {
                        powershell '.\\scripts\\run-analysis.ps1 -Project project-gamma'
                    }
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'reports/**', allowEmptyArchive: true
        }
    }
}
