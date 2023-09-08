#!/bin/bash

# CREDENCIAIS DO DB DO SONAR
$DB_USER=<username>
$DB_PASSWD=<senha>
$DB_IP_HOST=<IP do host>
$DB_INSTANCE=<nome da instancia>

# CREDENCIAIS DO LDAP
$ENABLE_LDAP = 0
$LDAP_IP=<Ldap ip>
$LDAP_PORT=<Ldap port>
$LDAP_USER_EMAIL=<user email>
$LDAP_PASSWD=<senha>
$ORG_NAME = <organization name>
$ORG_SUFFIX = <org name suffix>

# URL PARA FAZER DOWNLOAD DO .jar DO PLUGIN DE ANÁLISE DE BRANCHES
$PLUGIN_URL=<URL>

# CRIA GRUPO E USER SONARQUBE
sudo mkdir /opt/sonarqube/
cd /opt/sonarqube/
sudo addgroup sonarqube
sudo useradd -M -d /opt/sonarqube/ -r -s /bin/bash sonarqube
sudo usermod -aG sonarqube sonarqube
sudo chown -R sonarqube:sonarqube /opt/sonarqube
sudo chmod -R u+rwx /opt/sonarqube

# INSTALA PACOTES UTILIZADOS E O SONARQUBE 10.1
sudo apt update && apt upgrade - y
sudo apt install net-tools wget unzip vim curl ufw openjdk-17-jdk
sudo ufw allow 8080
sudo wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-10.1.0.73491.zip
sudo unzip sonarqube-*.zip
sudo mv sonarqube-*/* /opt/sonarqube/

# INSTALAR PLUGIN DE ANALISE DE BRANCHES
sudo wget $PLUGIN_URL
sudo mv sonarqube-community-branch-plugin-1.15.0-SNAPSHOT.jar extensions/plugins/

# INSERE VARS DE CONFIG NO SONAR.PROPERTIES
sudo echo "sonar.jdbc.username=$DB_USER" >> /conf/sonar.properties
sudo echo "sonar.jdbc.password=$DB_PASSWD" >> /conf/sonar.properties
sudo echo "sonar.jdbc.url=jdbc:sqlserver://$DB_IP_HOST:1434;instanceName=$DB_INSTANCE;databaseName=SONAR;integratedSecurity=false;trustServerCertificate=true" >> /conf/sonar.properties
sudo echo "sonar.web.javaOpts=-Xmx1024m -Xms512m -XX:+HeapDumpOnOutOfMemoryError" >> /conf/sonar.properties
sudo echo "sonar.web.javaAdditionalOpts=-javaagent:/opt/sonarqube/extensions/plugins/sonarqube-community-branch-plugin-1.15.0-SNAPSHOT.jar=web" >> /conf/sonar.properties
sudo echo "sonar.web.port=8080" >> /conf/sonar.properties
sudo echo "sonar.ce.javaOpts=-Xmx4096m -Xms2048m -XX:+HeapDumpOnOutOfMemoryError" >> /conf/sonar.properties
sudo echo "sonar.ce.javaAdditionalOpts=-javaagent:/opt/sonarqube/extensions/plugins/sonarqube-community-branch-plugin-1.15.0-SNAPSHOT.jar=ce" >> /conf/sonar.properties
sudo echo "sonar.search.javaOpts=-Xmx2048m -Xms2048m -XX:MaxDirectMemorySize=512m -XX:+HeapDumpOnOutOfMemoryError" >> /conf/sonar.properties
sudo echo "sonar.security.realm=LDAP" >> /conf/sonar.properties
if [[ $ENABLE_LDAP -eq 1 ]]; then
    sudo echo "ldap.url=LDAP://$LDAP_IP:$LDAP_PORT" >> /conf/sonar.properties
    sudo echo "ldap.bindDn=$LDAP_USER_EMAIL" >> /conf/sonar.properties
    sudo echo "ldap.bindPassword=$LDAP_PASSWD" >> /conf/sonar.properties
    sudo echo "ldap.user.baseDn=DC=$ORG_NAME,DC=$ORG_SUFFIX" >> /conf/sonar.properties
    sudo echo "ldap.user.request=(&(objectClass=user)(sAMAccountName={login}))" >> /conf/sonar.properties
    sudo echo "ldap.user.realNameAttribute=cn" >> /conf/sonar.properties
    sudo echo "ldap.user.emailAttribute=email" >> /conf/sonar.properties
fi

# CRIA E CONFIGURA O ARQUIVO DO SYSTEMCTL
sudo touch /etc/systemd/system/sonarqube.service
sudo cat <<EOT >> /etc/systemd/system/sonarqube.service
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonarqube
Group=sonarqube
Restart=always
RestartSec=30s
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOT

# CONFIGURA USO DE MEMÓRIA VIRTUAL MAX DA VM
sudo echo "vm.max_map_count=262144" >> /etc/sysctl.conf
sudo echo "fs.file-max=65536" >> /etc/sysctl.conf

# INICIA O SONARQUBE E HABILITA PARA INICIAR PÓS REBOOT
sudo chown -R sonarqube:sonarqube /opt/sonarqube
sudo chmod -R u+rwx /opt/sonarqube
sudo systemctl daemon-reload
sudo systemctl restart sonarqube
sudo systemctl enable sonarqube
sudo systemctl status sonarqube