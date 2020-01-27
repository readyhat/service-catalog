# Service Catalog
A service catalog is an index or all services and methods associated with an exposed service-mesh service using an API management tool like 3scale API Management. The true value in a service catalog is combining services from multiple mesh's across multiple clusters.

## Before You Begin
Before you being you will need at least one instance of 3scale API Management installed and configured. You will need a least one cluster with service mesh configured. You will need to install the `3scale-toolbox` CLI utility.

## Tools Used
 - 3scale API Management by Red Hat 
 - `3scale-tooldbox` CLI utility
 - Red Hat Service Mesh (Istio)

This cluster includes a simple bash script.

## Cluster #2 Import

1. Authenticate with source cluster #2
```bash
oc login --token={{ token } --server={{ server }}
```

2. Execute the `import-service-catalog.sh` script.
```bash
./import-service-catalog.sh
```
