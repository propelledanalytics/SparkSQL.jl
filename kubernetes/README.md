# SparkSQL.jl on Kubernetes 

Setup instructions for SparkSQL.jl on Kubernetes. 

## 1.) Install Podman
Podman is a container engine similar to Docker. This document shows how to install podman on an Ubuntu Linux distribution.
```
wget -nv https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_21.04/Release.key -O- | apt-key add -
apt-get update -qq -y
apt-get -qq --yes install podman
```
## 2.) Install Kubernetes
Kubernetes provides automatic management of containerized applications.
```
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```
## 3.) Install Minikube
Minikube enables running local Kubernetes clusters. 
```
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
minikube config set driver podman
```
Enable dashboard and metrics server.

```
minikube addons enable metrics-server
minikube addons enable dashboard
minikube addons enable ingress
minikube addons enable storage-provisioner

```
## 4.) Start MiniKube
```
minikube start --driver=podman --container-runtime=cri-o
minikube dashboard &
```
## 5.) Deploy Kubernetes cluster on MiniKube using local Podman images
Enable Minikube to use local images.
```
eval $(minikube podman-env)
```
Build the Spark podman image. 
```
podman-remote build -t spark-3.2.1 -f Containerfile .
```
Optionally, run the container (type "exit" to leave the container):
```
podman-remote run -it localhost/spark-3.2.1:latest
```
Use kubectl to provision storage.
```
kubectl apply -f spark-persistent-volume.yaml
kubectl apply -f spark-persistent-volume-claim.yaml
```
Use kubectl to deploy your Spark cluster.
```
kubectl apply -f spark-master-deployment-pvc.yaml
kubectl apply -f spark-master-service.yaml
```
Check the kubernetes pod status.
```
kubectl get pods
```
If pods are up, deploy the Spark worker.
```
kubectl apply -f spark-worker-deployment-pvc.yaml
```
Enable horizontal pod autoscaler.
```
kubectl apply -f spark-worker-hpa.yaml
```
You can login to the Spark Kubernetes cluster. (type "exit" to return)
```
kubectl get pods
kubectl exec --stdin --tty spark-master -- /bin/bash
```
Expose Spark master.
```
kubectl expose deployment spark-master --name spark-master-connection --type=NodePort --port=7077 --target-port=7077
```
## 6.) Connect Julia to Kubernetes Spark Cluster
Get minikube IP address for spark master
```
minikube service spark-master-connection --url
```
Export environmental variables for JAVA_HOME, SPARK_HOME.
```
export SPARK_HOME='/path/to/spark'
export JAVA_HOME='/path/to/java'
```
If using OpenJDK 11 on Linux set processReaperUseDefaultStackSize to true.
```
export _JAVA_OPTIONS='-Djdk.lang.processReaperUseDefaultStackSize=true'
```
Start Julia.
```
JULIA_COPY_STACKS=yes julia
```
Submit application to the Kubernetes Spark cluster in the Julia REPL.
```
using SparkSQL, DataFrames, Dates, Decimals
SparkSQL.initJVM()
sprk = SparkSQL.SparkSession("spark://SPARK_MASTER_CONNECTION_URL", "Julia on Spark with K8s")
```
