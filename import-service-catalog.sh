#!/bin/bash

API_ENDPOINT="https://3scale-admin.apps.experian.demo.readyhat.guru/admin/api/services"
API_ACCESS_TOKEN="dd8d3852c7da85f59ec8b47a6563f7d5bd844ce28609444ee67c6495ced5399c"

# 3scale Service Import 
#
# Import from OpenAPI Spec v2.0
#
# @service_name
# @swagger_spec path
importOpenApiSpec () {

  # Begin import
  echo "Importing OpenAPI Specification $1 ($2)..."
  3scale import openapi \
    --destination catalog $2 \
    --override-private-base-url="https://echo-api.3scale.net" \
    --default-credentials-userkey=userkey \
    --target_system_name $1 

  # Ceate a plan
  echo "Creating a default application plan..."
  3scale application-plan apply catalog $1 Default \
    --name "Default Plan" \
    --default \
    --enabled \
    --publish

  echo "Creating the application..."    
  3scale application apply catalog $1 \
    --account admin+test@3scale.apps.experian.demo.readyhat.guru \
    --name "$1" \
    --description "Imported service." \
    --plan Default \
    --service=$1

  # local sandbox_endpoint=$(3scale proxy-config show catalog $1 sandbox | jq -r ".content.proxy.sandbox_endpoint")

  local service_id=$(3scale service list catalog | grep $1 | awk '{print $1}') 
  # Patch the 3scale adapter handler with the updated service id
  oc patch handler petstore-handler \
    --type='json' \
    -p='[{"op": "replace", "path": "/spec/params/service_id", "value":"'$service_id\"'}]'

  # Update deployment option to istio
  curl -X PUT "https://3scale-admin.apps.experian.demo.readyhat.guru/admin/api/services/$service_id.xml" \
    -d 'access_token=d85fa7da04f2324feb0a77e2eaf565ae27e5203b2d4a7ef13ed39c193b4556e9&deployment_option=service_mesh_istio' \
    --silent --output /dev/null

  # Enable access to service from developer portal
  # local application_plan_id=$(3scale application-plan list catalog 47 | tail -n +2 | awk '{print $1}')
  # curl -X POST "https://3scale-admin.apps.experian.demo.readyhat.guru/admin/api/account_plans/$application_plan_id/features

  echo "Promoting service to production..."
  3scale proxy-config promote catalog $1

  local production_endpoint=$(3scale proxy-config show catalog $1 production | jq -r ".content.proxy.endpoint")
  echo "Production endpoint: $production_endpoint/api/findByStatus?status=available,sold&user_key=$1"
}

# Import via 3scale API
#
# @service_name
importVia3ScaleApi () {
  echo "Importing service $1 via 3scale API..."

  local access_token=$API_ACCESS_TOKEN
  local name=$1
  local description=$1-service
  local deployment_option="service_mesh_istio"
  local backend_version=1
  local system_name=$name

  # Create the service
  curl \
    -H "Accept: */*" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -X POST "$API_ENDPOINT.xml" \
    -d "access_token=$access_token&name=$name&description=$description&deployment_option=$deployment_option&backend_version=$backend_version&system_name=$system_name" \
    --silent --output /dev/null

  # Query the service id
  local service_id=$(3scale service list catalog | grep $name | awk '{print $1}')

  # Quert metric id
  local metric_id=$(3scale metric list catalog $service_id | tail -n +2 | awk '{print $1}')

  # Create the endpoint
  curl \
    -H "Accept: */*" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -X POST "$API_ENDPOINT/$service_id/proxy/mapping_rules.xml" \
    -d "access_token=$access_token&http_method=GET&pattern=/&delta=1&metric_id=$metric_id" \
    --silent --output /dev/null

  # Ceate a plan
  echo "Creating a default application plan..."
  3scale application-plan apply catalog $1 Default \
    --name "Default Plan" \
    --default \
    --enabled \
    --publish

  echo "Creating the application..."    
  3scale application apply catalog $1 \
    --account admin+test@3scale.apps.experian.demo.readyhat.guru \
    --name "$1" \
    --description "Imported service." \
    --plan Default \
    --service=$1
}

# TODO: Describe
echo "Discovering service mesh services..."
SERVICE_MESH_CONFIGURED_MEMBERS=$(oc get ServiceMeshMemberRoll default --namespace istio-system -o json | jq '.status.configuredMembers' -c | jq -r '.[]')

# Iterate over services to import
for service_name in $SERVICE_MESH_CONFIGURED_MEMBERS; do

  # Get the VS endpoint and remove quotes
  echo "Discovering hosts for $service_name service..."
  virtual_service=$(oc get virtualservice --namespace $service_name --output json | jq '.items[0].spec.hosts[0]' | sed -e 's/^"//' -e 's/"$//');

  # Swagger spec
  swagger_spec=http://$virtual_service/api/swagger.json

  # Evaluate swagger access
  if [ $(curl -s -o /dev/null -w "%{http_code}" $swagger_spec) = "200" ]; then
    echo "Valid API Spec for $service_name!"
    importOpenApiSpec $service_name $swagger_spec
  else 
    # TODO: Need to do the manual creation of service and backend
    echo "Invalid API Spec for: $service_name!"
    # importVia3ScaleApi $service_name
  fi
done;

echo "Import complete!";