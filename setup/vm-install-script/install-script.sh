#!/bin/bash

set -e

echo ".........----------------#################._.-.-INSTALL-.-._.#################----------------........."

PS1='\[\e[01;36m\]\u\[\e[01;37m\]@\[\e[01;33m\]\H\[\e[01;37m\]:\[\e[01;32m\]\w\[\e[01;37m\]\$\[\033[0;37m\] '
echo "PS1='\[\e[01;36m\]\u\[\e[01;37m\]@\[\e[01;33m\]\H\[\e[01;37m\]:\[\e[01;32m\]\w\[\e[01;37m\]\$\[\033[0;37m\] '" >> ~/.bashrc
sed -i '1s/^/force_color_prompt=yes\n/' ~/.bashrc
source ~/.bashrc

[ -f /etc/needrestart/needrestart.conf ] && sed -i 's/#\$nrconf{restart} = \x27i\x27/$nrconf{restart} = \x27a\x27/' /etc/needrestart/needrestart.conf

apt-get autoremove -y
apt-get update
systemctl daemon-reload

# -------------------------------
# BASE DEPENDENCIES
# -------------------------------
apt-get install -y curl apt-transport-https ca-certificates lsb-release software-properties-common python3 python3-pip jq gnupg

pip3 install jc --break-system-packages

# -------------------------------
# DOCKER + CONTAINERD
# -------------------------------
echo ".........----------------#################._.-.-Docker Base-.-._.#################----------------........."

apt-get install -y docker.io containerd

mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "storage-driver": "overlay2"
}
EOF

mkdir -p /etc/systemd/system/docker.service.d

systemctl daemon-reload
systemctl restart docker
systemctl enable docker

systemctl restart containerd
systemctl enable containerd

# -------------------------------
# KUBERNETES REPO SETUP
# -------------------------------
echo ".........----------------#################._.-.-K8s Repo-.-._.#################----------------........."

mkdir -p /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.35/deb/Release.key \
| gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.35/deb/ /" \
> /etc/apt/sources.list.d/kubernetes.list

apt-get update

# -------------------------------
# KUBERNETES INSTALL
# -------------------------------
apt-get install -y kubelet kubectl kubernetes-cni kubeadm

systemctl enable kubelet

echo ".........----------------#################._.-.-KUBERNETES-.-._.#################----------------........."

swapoff -a

rm -f /root/.kube/config || true
kubeadm reset -f || true

mkdir -p /etc/containerd
containerd config default | sed 's/SystemdCgroup = false/SystemdCgroup = true/' > /etc/containerd/config.toml
systemctl restart containerd

kubeadm init --pod-network-cidr '10.244.0.0/16' --service-cidr '10.96.0.0/16' --ignore-preflight-errors=NumCPU --skip-token-print

mkdir -p ~/.kube
cp -i /etc/kubernetes/admin.conf ~/.kube/config

kubectl apply -f "https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s-1.11.yaml"
kubectl rollout status daemonset weave-net -n kube-system --timeout=90s || true
sleep 5

echo "untaint controlplane node"
node=$(kubectl get nodes -o=jsonpath='{.items[0].metadata.name}')
kubectl taint nodes $node node-role.kubernetes.io/control-plane- || true

kubectl get nodes -o wide

# -------------------------------
# DOCKER FINAL CONFIG
# -------------------------------
echo ".........----------------#################._.-.-Docker-.-._.#################----------------........."

systemctl restart docker
systemctl enable docker

# -------------------------------
# JAVA and MAVEN
# -------------------------------
echo ".........----------------#################._.-.-Java and MAVEN-.-._.#################----------------........."

apt install -y openjdk-21-jdk maven
java -version
mvn -v

# -------------------------------
# JENKINS
# -------------------------------
echo ".........----------------#################._.-.-JENKINS-.-._.#################----------------........."

rm -f /etc/apt/sources.list.d/jenkins.list
rm -f /usr/share/keyrings/jenkins.gpg

mkdir -p /etc/apt/keyrings

wget -O /etc/apt/keyrings/jenkins-keyring.asc \
https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key

echo "deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] \
https://pkg.jenkins.io/debian-stable binary/" \
> /etc/apt/sources.list.d/jenkins.list

apt-get update
apt-get install -y jenkins

systemctl daemon-reload
systemctl enable jenkins
systemctl start jenkins

usermod -a -G docker jenkins
echo "jenkins ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

echo ".........----------------#################._.-.-COMPLETED-.-._.#################----------------........."
