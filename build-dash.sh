#!/bin/sh

if [ "$#" == "0" ]; then
    echo "Please enter a version number."
    exit 1
fi

docker build -t dash_image .
docker tag -f dash_image:latest gcr.io/mythical-willow-91020/dash_image:$1
gcloud preview docker push gcr.io/mythical-willow-91020/dash_image:$1
~/Code/kubernetes/cluster/kubectl.sh stop rc,po -l name=dashboard
~/Code/kubernetes/cluster/kubectl.sh create -f ~/Code/demos/dashboard-rc.yaml



