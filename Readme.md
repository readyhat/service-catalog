# Multi-cluster Service Catalog

 - 3scale API Management
 - Istio Service Mesh

 ## Cluster #1 Import

`TODO: What do we need to put here?`

## Cluster #2 Import

1. Authenticate with source cluster #2
```bash
oc login --token={{ token } --server=https://api.ocp4demo.sc.osecloud.com:6443
```

2. Execute the `import-service-catalog.sh` script.
```bash
./import-service-catalog.sh
```
