#!/usr/bin/env bash

# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Variables

if [[ $OSTYPE == "linux-gnu" && $CLOUD_SHELL == true ]]; then
    export PROJECT_ID=$(gcloud config get-value project)
    export WORK_DIR=${WORK_DIR:="${PWD}/workdir"}

    echo "๐งน Cleaning up Anthos environment in project: ${PROJECT_ID}"
    source ./env


    echo "โ๏ธ Unregistering clusters from Anthos..."
    gcloud container hub memberships delete gcp --quiet
    gcloud container hub memberships delete onprem --quiet


    echo "โ๏ธ Removing Kubernetes clusters from your project. This may take a few minutes ."
    ./kops/cleanup-remote-gce.sh &> ${WORK_DIR}/cleanup-remote.log &
    ./gke/cleanup-gke.sh &> ${WORK_DIR}/cleanup-gke.log &
    wait

    echo "๐ฅ Cleaning up forwarding and firewall rules."
    gcloud compute forwarding-rules delete $(gcloud compute forwarding-rules list --format="value(name)") --region us-central1 --quiet
    gcloud compute target-pools delete $(gcloud compute target-pools list --format="value(name)") --region us-central1 --quiet
    NODE_RULE="`gcloud compute firewall-rules list --format="table(name,targetTags.list():label=TARGET_TAGS)" | grep onprem-k8s-local-k8s-io-role-node | awk '{print $1}'`"
    gcloud compute firewall-rules delete ${NODE_RULE} --quiet

    echo "๐ Deleting CSR repos."
    gcloud source repos delete config-repo --quiet
    gcloud source repos delete app-config-repo --quiet
    gcloud source repos delete source-repo --quiet

    echo "โธ๏ธ Deleting onprem context from Secret Manager"
    gcloud secrets delete onprem-context --quiet

    echo "๐ Deleting Cloud Build trigger for app config repo"
    gcloud beta builds triggers delete trigger --quiet


    echo "๐ Deleting Firewall updater service account..."
    gcloud iam service-accounts delete kops-firewall-updater@${PROJECT_ID}.iam.gserviceaccount.com --quiet

    gcloud projects remove-iam-policy-binding ${PROJECT_ID} \
    --member serviceAccount:${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com \
    --role roles/compute.securityAdmin


    echo "๐ Deleting GCP cluster Hub service account..."
    gcloud iam service-accounts delete gcp-connect@${PROJECT_ID}.iam.gserviceaccount.com --quiet
    SVC_ACCT_NAME="gcp-connect"

    gcloud projects remove-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SVC_ACCT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/gkehub.connect"

    gcloud projects remove-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:${SVC_ACCT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/gkehub.connect"


    echo "๐ Deleting onprem cluster Hub service account..."
    gcloud iam service-accounts delete anthos-connect@${PROJECT_ID}.iam.gserviceaccount.com --quiet

    gcloud projects remove-iam-policy-binding ${PROJECT_ID} \
    --member="serviceAccount:anthos-connect@${PROJECT_ID}.iam.gserviceaccount.com" \
    --role="roles/gkehub.connect"


    echo "๐ Finishing up."
    rm -rf $HOME/.kube/config \
           $HOME/hybrid-sme/app-config-repo \
           $HOME/hybrid-sme/config-repo \
           $HOME/hybrid-sme/source-repo \
           $HOME/hybrid-sme/cloud-builders-community \
           $HOME/.ssh/id_rsa.nomos.*

    rm -f $HOME/.customize_environment
    rm -rf $WORK_DIR

    echo "โ Cleanup complete. You can continue using ${PROJECT_ID}."

else
    echo "This has only been tested in GCP Cloud Shell.  Only Linux (debian) is supported".
fi
