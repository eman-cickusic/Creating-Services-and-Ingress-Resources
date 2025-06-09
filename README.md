# Creating Services and Ingress resources

This repository contains all the resources and documentation for the "Creating Services and Ingress Resources" lab, demonstrating different types of Kubernetes services in Google Kubernetes Engine (GKE) and how they integrate with Google Cloud Load Balancers.

## Overview

This lab demonstrates how to:
- Work with Kubernetes DNS resolution
- Deploy different service types (ClusterIP, NodePort, LoadBalancer)
- Create and configure Ingress resources
- Integrate with Google Cloud Network Load Balancers

## Lab Objectives

- Observe Kubernetes DNS in action
- Define various service types in manifests with label selectors
- Deploy an Ingress resource that routes traffic based on URL paths
- Verify Google Cloud network load balancer creation for LoadBalancer services

## Prerequisites

- Google Cloud Platform account with billing enabled
- Access to Google Kubernetes Engine (GKE)
- Basic knowledge of Kubernetes concepts
- `kubectl` CLI tool configured

## Architecture

The lab creates the following architecture:

```
Internet → Global HTTP(S) Load Balancer (Ingress) → GKE Cluster
                    ↓
            /v1 → hello-svc (NodePort) → hello-v1 pods
            /v2 → hello-lb-svc (LoadBalancer) → hello-v2 pods
```

## Setup Instructions

### 1. Environment Setup

```bash
# Set environment variables
export my_zone=your-zone
export my_cluster=standard-cluster-1

# Configure kubectl completion
source <(kubectl completion bash)

# Get cluster credentials
gcloud container clusters get-credentials $my_cluster --zone $my_zone
```

### 2. Clone and Navigate

```bash
# Clone the repository
git clone https://github.com/GoogleCloudPlatform/training-data-analyst
ln -s ~/training-data-analyst/courses/ak8s/v1.1 ~/ak8s
cd ~/ak8s/GKE_Services/
```

### 3. Deploy DNS Demo

```bash
# Deploy DNS demo pods and service
kubectl apply -f dns-demo.yaml

# Verify pods are running
kubectl get pods

# Test DNS resolution from inside a pod
kubectl exec -it dns-demo-1 -- /bin/bash
apt-get update && apt-get install -y iputils-ping curl
ping dns-demo-2.dns-demo.default.svc.cluster.local
ping dns-demo.default.svc.cluster.local
```

### 4. Deploy Hello Application v1 with ClusterIP

```bash
# Deploy hello-v1 application
kubectl create -f hello-v1.yaml

# Deploy ClusterIP service
kubectl apply -f hello-svc.yaml

# Verify deployment
kubectl get deployments
kubectl get service hello-svc
```

### 5. Convert to NodePort Service

```bash
# Apply NodePort service configuration
kubectl apply -f hello-nodeport-svc.yaml

# Verify service type change
kubectl get service hello-svc
```

### 6. Create Static IP Addresses

```bash
# Reserve regional static IP for LoadBalancer
gcloud compute addresses create regional-loadbalancer --region=your-region

# Reserve global static IP for Ingress
gcloud compute addresses create global-ingress --global

# Note the IP addresses for later use
gcloud compute addresses list
```

### 7. Deploy Hello Application v2 with LoadBalancer

```bash
# Deploy hello-v2 application
kubectl create -f hello-v2.yaml

# Update LoadBalancer service with static IP
export STATIC_LB=$(gcloud compute addresses describe regional-loadbalancer --region your-region --format json | jq -r '.address')
sed -i "s/10\.10\.10\.10/$STATIC_LB/g" hello-lb-svc.yaml

# Deploy LoadBalancer service
kubectl apply -f hello-lb-svc.yaml

# Verify services
kubectl get services
```

### 8. Deploy Ingress Resource

```bash
# Deploy Ingress resource
kubectl apply -f hello-ingress.yaml

# Check Ingress status
kubectl describe ingress hello-ingress

# Wait for external IP to be assigned (may take several minutes)
```

## Testing the Deployment

### Test ClusterIP Service (Internal Only)

```bash
# From inside dns-demo-1 pod
kubectl exec -it dns-demo-1 -- /bin/bash
curl hello-svc.default.svc.cluster.local
```

### Test NodePort Service

```bash
# Internal access
kubectl exec -it dns-demo-1 -- curl hello-svc.default.svc.cluster.local

# External access requires node IP and node port (30100)
# Not directly accessible from Cloud Shell
```

### Test LoadBalancer Service

```bash
# External access using LoadBalancer IP
curl [LOADBALANCER_EXTERNAL_IP]

# Internal access
kubectl exec -it dns-demo-1 -- curl hello-lb-svc.default.svc.cluster.local
```

### Test Ingress Resource

```bash
# Get Ingress external IP
kubectl get ingress hello-ingress

# Test v1 path (routes to NodePort service)
curl http://[INGRESS_EXTERNAL_IP]/v1

# Test v2 path (routes to LoadBalancer service)  
curl http://[INGRESS_EXTERNAL_IP]/v2
```

## File Structure

```
.
├── README.md
├── manifests/
│   ├── dns-demo.yaml           # DNS test pods and headless service
│   ├── hello-v1.yaml          # Hello app v1.0 deployment
│   ├── hello-v2.yaml          # Hello app v2.0 deployment
│   ├── hello-svc.yaml         # ClusterIP service for v1
│   ├── hello-nodeport-svc.yaml # NodePort service for v1
│   ├── hello-lb-svc.yaml      # LoadBalancer service for v2
│   └── hello-ingress.yaml     # Ingress resource
├── scripts/
│   ├── setup.sh               # Initial setup script
│   ├── deploy-all.sh          # Deploy all resources
│   └── cleanup.sh             # Clean up resources
└── docs/
    ├── service-types.md       # Explanation of Kubernetes service types
    └── troubleshooting.md     # Common issues and solutions
```

## Service Types Explained

### ClusterIP (Default)
- Internal cluster communication only
- No external access
- Uses cluster-internal IP address

### NodePort
- Extends ClusterIP functionality
- Exposes service on each node's IP at a static port
- External access via `<NodeIP>:<NodePort>`

### LoadBalancer
- Extends NodePort functionality
- Provisions external load balancer (Google Cloud Load Balancer)
- Provides external IP address

### Ingress
- Not a service type, but a resource
- Manages external HTTP(S) access to services
- Provides path-based and host-based routing
- Uses Google Cloud Global HTTP(S) Load Balancer

## Load Balancer Integration

This lab demonstrates integration with Google Cloud Load Balancers:

1. **Regional TCP Load Balancer**: Created for LoadBalancer service type
2. **Global HTTP(S) Load Balancer**: Created for Ingress resource

## Troubleshooting

### Common Issues

1. **DNS Resolution Fails**
   - Ensure pods are in the same namespace
   - Use FQDN format: `service.namespace.svc.cluster.local`

2. **External IP Pending**
   - LoadBalancer services may take 2-5 minutes to provision
   - Check Google Cloud Console for load balancer status

3. **Ingress 404/502 Errors**
   - Global load balancers can take 5-10 minutes to propagate
   - Verify backend service health in Google Cloud Console

4. **Service Not Accessible**
   - Check service selector labels match pod labels
   - Verify service and pod are in same namespace

### Verification Commands

```bash
# Check all resources
kubectl get all

# Describe services for troubleshooting
kubectl describe service hello-svc
kubectl describe service hello-lb-svc

# Check Ingress status
kubectl describe ingress hello-ingress

# View load balancers in Google Cloud
gcloud compute forwarding-rules list
gcloud compute target-pools list
```

## Cleanup

```bash
# Delete Kubernetes resources
kubectl delete -f hello-ingress.yaml
kubectl delete -f hello-lb-svc.yaml
kubectl delete -f hello-nodeport-svc.yaml
kubectl delete -f hello-svc.yaml
kubectl delete -f hello-v2.yaml
kubectl delete -f hello-v1.yaml
kubectl delete -f dns-demo.yaml

# Delete static IP addresses
gcloud compute addresses delete regional-loadbalancer --region=your-region
gcloud compute addresses delete global-ingress --global
```

## Additional Resources

- [Kubernetes Services Documentation](https://kubernetes.io/docs/concepts/services-networking/service/)
- [Kubernetes Ingress Documentation](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [GKE Ingress Documentation](https://cloud.google.com/kubernetes-engine/docs/concepts/ingress)
- [Google Cloud Load Balancing](https://cloud.google.com/load-balancing/docs)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request
