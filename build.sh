#!/bin/sh
set -x

if [ "$#" -lt "3" ]; then
    echo "Please enter an replicate controller name, service label and a version number."
    exit 1
fi

if [ ! -f "./Dockerfile" ]; then
  echo "Please execute from the directory that contains the Dockerfile for $1."
  exit 1
fi

NAME="$1"
LABEL="$2"
IMAGENAME=$LABEL"_image"
VERSION="$3"
PROJECT="linear-pointer-95422"

cp ../utility_files/* .
docker build -t "$IMAGENAME" .
docker tag -f $IMAGENAME:latest gcr.io/$PROJECT/$IMAGENAME:$VERSION
gcloud docker push gcr.io/$PROJECT/$IMAGENAME:$VERSION
sed -e "s/RCNAME/$NAME/g; s/VERSION/$VERSION/g; s/IMAGENAME/$IMAGENAME/g; s/LABEL/$LABEL/g" ../rc-template.yml > ../$NAME-rc.yml
~/Code/kubernetes/cluster/kubectl.sh stop rc,po -l name=$LABEL
cat ../$NAME-rc.yml | ~/Code/kubernetes/cluster/kubectl.sh create -f -
