pipeline {
    agent any

    stages {
        stage ('Clone') {
            steps {
                git branch: 'master', url: "https://github.com/venkatesh-devops/kaniko.git"
            }
        }
        stage ('Python code zip') {
            steps {
                sh '''
                 ls -l
                 zip kaniko.zip lambda.py
                 ls -l
                 zipinfo kaniko.zip
                '''
            }
        }

        // stage ('Excluded upload') {
        //     steps {
        //         rtUpload (
        //             // Obtain an Artifactory server instance, defined in Jenkins --> Manage Jenkins --> Configure System:
        //             serverId: SERVER_ID,
        //             specPath: 'jenkins-examples/pipeline-examples/resources/exclude-upload.json'
        //         )
        //     }
        // }

        // stage ('Publish build info') {
        //     steps {
        //         rtPublishBuildInfo (
        //             serverId: SERVER_ID
        //         )
        //     }
        // }
    }
}
