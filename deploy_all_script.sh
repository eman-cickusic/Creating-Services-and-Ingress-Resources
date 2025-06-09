#!/bin/bash

# GKE Services and Ingress Lab Deployment Script
# This script deploys all resources for the GKE Services and Ingress lab

set -e

# Color codes for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Wait for pods to be ready
wait_for_pods() {
    local label_selector=$1
    local timeout=${2:-300}
    
    print_status "Waiting for pods with selector '$label_selector' to be ready..."
    
    if kubectl wait --for=condition=ready pod -l "$label_selector" --timeout=${timeout}s; then
        print_status "Pods are ready ✓"
    else
        print_warning "Some pods may not be ready yet"
    fi
}

# Wait for service to get external IP
wait_for_external_ip() {
    local service_name=$1
    local timeout=${2:-300}
    
    print_status "Waiting for service '$service_name' to get external IP..."
    
    local count=0
    local max_attempts=$((timeout / 10))
    
    while [ $count -lt $max_attempts ]; do
        external_ip=$(kubectl get service $service_name -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
        
        if [ ! -z "$external_ip" ] && [ "$external_ip" != "null" ]; then
            print_status "Service '$service_name' has external IP: $external_ip ✓"
            return 0
        fi
        
        sleep 10
        count=$((count + 1))
        echo -n "."
    done
    
    echo
    print_warning "Service '$service_name' did not get external IP within timeout"
    return 1
}

# Deploy DNS demo
deploy_dns_demo() {
    print_header "Deploying DNS demo pods and service..."
    
    kubectl apply -f manifests/dns-demo.yaml
    
    wait_for_pods "name=dns-demo"
    
    print_status "DNS demo deployed successfully ✓"
}

# Deploy hello v1 application
deploy_hello_v1() {
    print_header "Deploying hello-v1 application..."
    
    kubectl apply -f manifests/hello-v1.yaml
    
    wait_for_pods "run=hello-v1"
    
    print_status "hello-v1 application deployed successfully ✓"
}

# Deploy ClusterIP service
deploy_clusterip_service() {
    print_header "Deploying ClusterIP service..."
    
    kubectl apply -f manifests/hello-svc.yaml
    
    # Verify service
    kubectl get service hello-svc
    
    print_status "ClusterIP service deployed successfully ✓"
}

# Deploy NodePort service
deploy_nodeport_service() {
    print_header "Converting to NodePort service..."
    
    kubectl apply -f manifests/hello-nodeport-svc.yaml
    
    # Verify service
    kubectl get service hello-svc
    
    print_status "NodePort service deployed successfully ✓"
}

# Deploy hello v2 application
deploy_hello_v2() {
    print_header "Deploying hello-v2 application..."
    
    kubectl apply -f manifests/hello-v2.yaml
    
    wait_for_pods "run=hello-v2"
    
    print_status "hello-v2 application deployed successfully ✓"
}

# Deploy LoadBalancer service
deploy_loadbalancer_service() {
    print_header "Deploying LoadBalancer service..."
    
    # Get the region from the zone
    local region=$(echo $my_zone | sed 's/-[a-z]$//')
    
    # Get the static IP address
    local static_lb_ip=$(gcloud compute addresses describe regional-loadbalancer --region=$region --format='value(address)')
    
    if [ -z "$static_lb_ip" ]; then
        print_error "Could not retrieve regional-loadbalancer static IP address"
        return 1
    fi
    
    print_status "Using static IP: $static_lb_ip"
    
    # Replace placeholder IP in the manifest
    sed "s/10\.10\.10\.10/$static_lb_ip/g" manifests/hello-lb-svc.yaml | kubectl apply -f -
    
    # Wait for external IP
    wait_for_external_ip "hello-lb-svc"
    
    print_status "LoadBalancer service deployed successfully ✓"
}

# Deploy Ingress resource
deploy_ingress() {
    print_header "Deploying Ingress resource..."
    
    kubectl apply -f manifests/hello-ingress.yaml
    
    print_status "Ingress resource deployed ✓"
    print_warning "Note: It may take 5-10 minutes for the Global Load Balancer to be fully ready"
}

# Display service status
show_status() {
    print_header "Deployment Status Summary"
    
    echo
    echo "Pods:"
    kubectl get pods -o wide
    
    echo
    echo "Services:"
    kubectl get services
    
    echo
    echo "Ingress:"
    kubectl get ingress
    
    echo
    echo "Static IP Addresses:"
    gcloud compute addresses list --filter="name:(regional-loadbalancer OR global-ingress)"
}

# Test connectivity
test_connectivity() {
    print_header "Testing connectivity..."
    
    # Test ClusterIP service from inside cluster
    print_status "Testing ClusterIP service from inside cluster..."
    kubectl exec dns-demo-1 -- sh -c "apt-get update -qq && apt-get install -y -qq curl" >/dev/null 2>&1 || true
    
    if kubectl exec dns-demo-1 -- curl -s --connect-timeout 5 hello-svc.default.svc.cluster.local >/dev/null; then
        print_status "ClusterIP service test: PASS ✓"
    else
        print_warning "ClusterIP service test: FAIL"
    fi
    
    # Test LoadBalancer service externally
    print_status "Testing LoadBalancer service externally..."
    local lb_ip=$(kubectl get service hello-lb-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
    
    if [ ! -z "$lb_ip" ] && [ "$lb_ip" != "null" ]; then
        if curl -s --connect-timeout 10 "http://$lb_ip" >/dev/null; then
            print_status "LoadBalancer service test: PASS ✓"
        else
            print_warning "LoadBalancer service test: FAIL (may need more time)"
        fi
    else
        print_warning "LoadBalancer service: External IP not ready yet"
    fi
    
    # Test Ingress
    print_status "Testing Ingress resource..."
    local ingress_ip=$(kubectl get ingress hello-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
    
    if [ ! -z "$ingress_ip" ] && [ "$ingress_ip" != "null" ]; then
        print_status "Ingress external IP: $ingress_ip"
        print_warning "Global Load Balancer may take 5-10 minutes to be fully functional"
    else
        print_warning "Ingress: External IP not assigned yet"
    fi
}

# Main execution
main() {
    echo "=========================================="
    echo "GKE Services and Ingress Lab Deployment"
    echo "=========================================="
    echo
    
    # Check if setup was run
    if [ -z "$my_zone" ] || [ -z "$my_cluster" ]; then
        print_error "Environment not set up. Please run './scripts/setup.sh' first."
        exit 1
    fi
    
    # Verify kubectl connectivity
    if ! kubectl cluster-info &>/dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Please run './scripts/setup.sh' first."
        exit 1
    fi
    
    # Deploy resources step by step
    deploy_dns_demo
    echo
    
    deploy_hello_v1
    echo