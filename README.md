## The idea
Build a simple pipeline, deploying a Ruby on Rails application with static & dynamic application security testing. Introduce security assessment for the build and prod hosts to play out with the RB technologies. 

Demonstration: https://www.youtube.com/watch?v=lm3WLJ7i6VU

## Technologies
* AWS - EC2, S3, Security Groups, IAM
* Terraform - to deploy the infrastructure
* Ansible - to configure the infrastructure
* Jenkins - to manage the build and pipeline
* Github [rbsample](https://github.com/rbsample/) - storing the project infrastructure & app code
* Ruby on Rails - used for the sample project app [guide](https://docs.docker.com/compose/rails/)
* Docker - to build the app in containers

### Templates
* Terraform template - define the infrastructure above. [guide](https://dev.to/aakatev/deploy-ec2-instance-in-minutes-with-terraform-ip2)
* Ansible playbooks - configuration of the infrastructure above.
* Jenkinsfile - the definition of the Jenkins pipeline in the workflow below.

### Deployment Workflow
1. Create IAM User for Terraform & configure AWS Cli profile `rbsample`
```
aws configure --profile rbsample
AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
Default region name [None]: eu-west-1
Default output format [None]: json
```
2. Create SSH keypair used for the EC2 resources
```
$ ssh-keygen -t rsa
Generating public/private rsa key pair.
Enter file in which to save the key (/Users/miglen/.ssh/id_rsa): ./key_terraform
...
```
3. Create the infrastructure using Terraform
```
# Place your public ip into the template
sed -i '' "s/YOUR_PUBLIC_IP/$(curl -s ifconfig.co)/g" template.tf
# Apply
terraform apply
```
4. Configure infrastructure using Ansible `ansible-playbook playbook.yml`
5. Configure Jenkins master, authorize with Github
7. Ready to play!

### Build Workflow
1. Commit into the mainline package app initiates build - https://github.com/rbsample/app
2. Build the image
3. SAST
  3.1 PII Scan using pdscan
  3.2 Perform static ruby app scan, fail if vulnerabilities found
    2.3.1 Brakeman - https://brakemanscanner.org/
    2.3.2 Bundler-audit - https://github.com/rubysec/bundler-audit
    2.3.3 Hakiri - https://hakiri.io/
4. DAST - AV Scan, using open source Clam AV
5. DAST - XSS Scan using simple XSS vulnerability scan with [PwnXss](https://github.com/pwn0sec/PwnXSS)
6. Publish Image to Repo
7. Scan Host for compliance - [CIS](https://github.com/cloudogu/CIS-Ubuntu-18.04) & [Docker-Bench](https://github.com/docker/docker-bench-security)
8. Deploy to Prod!

### Demo Workflow
1. Clean build - Successful
2. Build with PII (sample email@example.com) - Failure at step 3.1
3. Build with Vulnerable gems (`echo "gem 'yard', '0.8.0'" >> Gemfile`) - Failure at step 3.2
4. Build with [eicar test file](https://www.eicar.org/?page_id=3950) (`echo "gem 'EICAR', '0.0.6'" >> Gemfile`) - Failure at step 4.
5. Build with xss vulnerability - Failure at step 5.
6. Rebuild clean - Successful

### Ideas for improvement
#### I. Security
* Static scan with [Clair](https://github.com/quay/clair) and [Docker Scan](https://docs.docker.com/engine/scan/)
* File integrity monitoring [Qualys](https://www.qualys.com/apps/file-integrity-monitoring/) - all dependencies and libraries integrity is not violated.
* Full Malware Scanning - using 3rd party solution to perform anti-malware scan.
* Data exfil detection - detect any unusual communication, could leverage AWS GuardDuty.
* Penetration testing (w3af or OWASP) - With custom profiles based on the application.
* DoS testing, especially [slowloris](https://github.com/gkbrk/slowloris) and intensive operations [hping3](https://tools.kali.org/information-gathering/hping3) or [GoldenEye](https://github.com/jseidl/GoldenEye)
* Host system assessment - [CIS](https://github.com/cloudogu/CIS-Ubuntu-18.04) & [Docker-Bench](https://github.com/docker/docker-bench-security)
