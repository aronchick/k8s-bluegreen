# Demo Script
Tested on Mac OS X, though there's nothing preventing it from working elsewher.

Demo Pre-setup (just to make it fast):
- From the directory in which you have cloned the repo:
```
# If k8s not already installed.
export KUBERNETES_PROVIDER=gce; wget -q -O - https://get.k8s.io | bash

# Preload all nodes with images and services
# (normally takes about 5 minutes, and is boring to watch)
cluster/kubectl.sh create -f demos
cluster/kubectl.sh resize rc client-purple --replicas=25
cluster/kubectl.sh resize rc client-blue --replicas=25
cluster/kubectl.sh resize rc client-green --replicas=25
cluster/kubectl.sh stop rc,po -l name=client
cluster/kubectl.sh create -f demos/client-purple.yml
```

Demo:
- Show info about the cluster:
```
cluster/kubectl.sh cluster-info
cluster/kubectl.sh config view
```

- Show different elements we'll be starting:
    - Replication Controller & Pod:
    ```
    cat demos/client-purple-rc.yml
    ```
    - Service:
    ```
    cat demos/client-service.yaml
    ```
  - Show running pods
    ```
    cluster/kubectl.sh get po -l name=client
    ```
  - Show running services
    ```
    cluster/kubectl.sh get se
    ```

- Access the icons as a service on the service IP
  - Refresh a bunch of times - try to get a different pod
  - Then show the dashboard as a service - pinging two instances

- Resize
  ```
    cluster/kubectl.sh resize rc client-purple --replicas=5
    cluster/kubectl.sh get po -l name=client
  ```
  - Show dashboard
  - Spin up spin down
  ```
    cluster/kubectl.sh resize rc client-purple --replicas=2
    cluster/kubectl.sh resize rc client-purple --replicas=20
    cluster/kubectl.sh resize rc client-purple --replicas=6
  ```
- Rolling Update
  - To CLI:
  ```
  cluster/kubectl.sh rolling-update client --update-period=1s -f demos/client-blue-rc.yml
  ```
  - To dashboard, show rolling update
  
- Blue/Green
  ```
  cluster/kubectl.sh create -f demos/client-green-rc.yml
  cluster/kubectl.sh resize rc client-blue --replicas=4
  cluster/kubectl.sh resize rc client-green --replicas=4
  cluster/kubectl.sh resize rc client-blue --replicas=2
  cluster/kubectl.sh resize rc client-green --replicas=6
  cluster/kubectl.sh resize rc client-blue --replicas=0
  cluster/kubectl.sh stop rc client-blue
  ```

- Shut down container, then minion
  ```
    cluster/kubectl.sh get po -l name=client
    gcloud compute ssh <node name> --zone=us-central1-b 
    sudo su
    docker ps
    docker stop <container name>
  ```
  - To dashboard, watch it die, watch it recover

- Show spinning up on AWS:
  ```
  export KUBERNETES_PROVIDER=aws; wget -q -O - https://get.k8s.io | bash
  ```
  
- Cleanup ``` cluster/kube-down.sh```
