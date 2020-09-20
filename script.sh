#!/bin/bash
# Some commands reference and notes
# cd $(mktemp -d)
git clone https://github.com/rbsample/app ./
docker-compose build
docker build --no-cache -t app_web:latest .
docker image prune --force

# Scan dependencies for vulnerabilities
docker-compose up -d 
web_container=$(docker ps  | grep web_1 | awk '{print $NF}')
docker exec ${web_container} gem install bundle-audit # brakeman hakiri
docker exec ${web_container} bundle-audit | tee output
docker-compose down
if grep "Vulnerabilities found!" output; then exit 1;fi 

# Xss Scan
# install preerquisites
git clone https://github.com/pwn0sec/PwnXSS
apt-get install -y python3-pip
pip3 install bs4 requests
# Start container
docker-compose up -d
docker-compose run web rake db:create
# Scan
> output
python3 PwnXSS/pwnxss.py -u http://localhost:3000/ | tee output
# Stop container
docker-compose down
docker container prune --force
# Cleanup
rm -rf ./PwnXSS
# Send signal
if grep "CRITICAL" output; then exit 1;fi 

# DLP Scan
# Download pdscan & sample file
# wget https://github.com/openbridge/clamav/blob/master/tests/pii/Identity_Finder_Test_Data.zip -P app/
wget https://github.com/ankane/pdscan/releases/download/v0.1.1/pdscan_0.1.1_Linux_x86_64.zip
# install unzip
apt install unzip
unzip -p pdscan_0.1.1_Linux_x86_64.zip pdscan > pdscan
chmod +x ./pdscan
# scan all files (doesn't work well recursively so we are doing it with find )
> output
find ./app -type f -exec ./pdscan file://{} \; | tee -a output
if grep ": found" output; then exit 1;fi 

# Anti Malware Scan
# Install clamdscan
docker-compose up -d 
# Start ClamAV container & create network
docker run -d -p 3310:3310 --name clamav openbridge/clamav 
docker network create clamav
docker network connect clamav clamav
# get web container name
web_container=$(docker ps  | grep web_1 | awk '{print $NF}')
docker network connect clamav ${web_container}
clam_ip=$(docker inspect -f "{{ .NetworkSettings.Networks.clamav.IPAddress }}" clamav)

# Create config file
cat << EOF > ./clamd.conf
LogSyslog yes
PidFile /var/run/clamd.pid
FixStaleSocket true
LocalSocketGroup clamav
LocalSocketMode 666
TemporaryDirectory /tmp
DatabaseDirectory /var/lib/clamav
TCPSocket 3310
TCPAddr ${clam_ip}
MaxConnectionQueueLength 200
MaxThreads 10
ReadTimeout 400
Foreground true
StreamMaxLength 100M
HeuristicScanPrecedence yes
StructuredDataDetection no
#StructuredSSNFormatNormal yes
ScanPE yes
ScanELF yes
ScanOLE2 yes
ScanPDF yes
ScanSWF yes
ScanMail yes
PhishingSignatures yes
PhishingScanURLs yes
ScanArchive yes
ArchiveBlockEncrypted no
MaxScanSize 1000M
MaxFileSize 1000M
Bytecode yes
BytecodeSecurity TrustSigned
BytecodeTimeout 240000
EOF

# Scan inside the container
docker exec ${web_container} apt-get install -y clamdscan
docker cp ./clamd.conf ${web_container}:/etc/clamav/clamd.conf
sleep 60 # takse time for the clamav to start
docker exec ${web_container} clamdscan --version
# Create eicar file
# echo 'X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*' > eicar
# gem install EICAR
# Scan current application folder
cat << EOF > ./scan.sh
clamdscan --stream /myapp
# Scan gem installed paths
gem_paths=\$(gem environment | sed -n '/GEM PATHS/,/GEM/p' | grep -v GEM | awk '{ print \$NF }')
for gem_path in \${gem_paths}
do
  echo "Scanning \${gem_path}/gems/"
  clamdscan --stream \${gem_path}/gems/
done 
EOF
docker cp ./scan.sh ${web_container}:/scan.sh
> output
docker exec ${web_container} bash /scan.sh | tee output
docker-compose down
docker container prune --force
# Send signal
if grep "FOUND" output; then exit 1;fi 

# Run CIS Check for the Ubuntu host
git clone https://github.com/bats-core/bats-core.git
cd bats-core/
./install.sh /usr/local
git clone https://github.com/cloudogu/CIS-Ubuntu-18.04.git
bats CIS-Ubuntu-18.04/*/
# Cleanup
cd ../
rm -rf ./bats-core

# Run docker-bench-security for security assesment
git clone https://github.com/docker/docker-bench-security.git
cd docker-bench-security
sh docker-bench-security.sh
# Cleanup
cd ../
rm -rf ./docker-bench-security
