#!/bin/bash

API_ENDPOINT="https://3scale-admin.apps.experian.demo.readyhat.guru/admin/api/services.xml"
API_ACCESS_TOKEN="dd8d3852c7da85f59ec8b47a6563f7d5bd844ce28609444ee67c6495ced5399c"

# 
3scale_import () {
  echo "Importing $1 ($2) to catalog via 3scale-toolbox..."
  3scale import openapi --destination catalog $2 --override-private-base-url="https://echo-api.3scale.net" --default-credentials-userkey=userkey
}

# Playbook Import
playbook_import () {
  echo "Importing $1 to catalog via ansible-playbook..."

  local access_token=$API_ACCESS_TOKEN
  local name=$1
  local description=$1-service
  local deployment_option="service_mesh_istio"
  local backend_version=1
  local system_name=$name

  # Create the service
  ansible-playbook playbooks/create-api-service.yaml \
    --extra-vars "api_endpoint=$API_ENDPOINT service_name=$name body=access_token=$access_token&name=$name&description=$description&deployment_option=$deployment_option&backend_version=$backend_version&system_name=$system_name"
}

# TODO: Describe
echo "Discovering service mesh services..."
SERVICE_MESH_CONFIGURED_MEMBERS=$(oc get ServiceMeshMemberRoll default --namespace istio-system -o json | jq '.status.configuredMembers' -c | jq -r '.[]')

# Iterate over services to import
for service_name in $SERVICE_MESH_CONFIGURED_MEMBERS; do

  # Get the VS endpoint and remove quotes
  echo "Discovery hosts for $service_name service..."
  virtual_service=$(oc get virtualservice --namespace $service_name --output json | jq '.items[0].spec.hosts[0]' | sed -e 's/^"//' -e 's/"$//');

  swagger_spec=http://$virtual_service/api/swagger.json

  # Evaluate swagger access
  if [ $(curl -s -o /dev/null -w "%{http_code}" $swagger_spec) = "200" ]; then
    echo "Valid API Spec for: $service_name!"
    3scale_import $service_name $swagger_spec
  else 
    # TODO: Need to do the manual creation of service and backend
    echo "Invalid API Spec for: $service_name!"
    playbook_import $service_name
  fi
done;

echo "Import complete!";