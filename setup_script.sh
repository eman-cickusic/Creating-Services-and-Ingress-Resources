#!/bin/bash

# GKE Services and Ingress Lab Setup Script
# This script sets up the environment for the GKE Services and Ingress lab

set -e

echo "🚀 Starting GKE Services and Ingress Lab Setup..."

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

# Check if required tools are installed
check_prerequisites() {
    print_header "Checking prerequisites..."
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud is not installed or not in PATH"
        exit 1
    fi
    
    print_status "Prerequisites check passed ✓"
}

# Set environment variables
setup_environment() {
    print_header "Setting up environment variables..."
    
    # Prompt for zone if not set
    if [ -z "$my_zone" ]; then
        read -p "Enter your GCP zone (e.g., us-central1-a): " my_zone
        export my_zone
    fi
    
    # Set cluster name
    export my_cluster=${my_cluster:-"standard-cluster-1"}
    
    print_status "Zone: $my_zone"
    print_status "Cluster: $my_cluster"
    
    # Configure kubectl completion
    source <(kubectl completion bash)
    print_status "kubectl completion configured ✓"
}

# Connect to GKE cluster
connect_to_cluster() {
    print_header "Connecting to GKE cluster..."
    
    # Get cluster credentials
    if gcloud container clusters get-credentials $my_cluster --zone $my_zone; then
        print_status "Successfully connected to cluster $my_cluster ✓"
    else
        print_error "Failed to connect to cluster. Please check if the cluster exists."
        exit 1
    fi
    
    # Verify connection
    if kubectl cluster-info &> /dev/null; then
        print_status "Cluster connection verified ✓"
    else
        print_error "Unable to communicate with cluster"
        exit 1
    fi
}

# Create static IP addresses
create_static_ips() {
    print_header "Creating static IP addresses..."
    
    # Get the region from zone
    region=$(echo $my_zone | sed 's/-[a-z]$//')
    
    # Create regional static IP for LoadBalancer
    print_status "Creating regional static IP address..."
    if gcloud compute addresses create regional-loadbalancer --region=$region 2>/dev/null; then
        print_status "Regional static IP 'regional-loadbalancer' created ✓"
    else
        print_warning "Regional static IP 'regional-loadbalancer' may already exist"
    fi
    
    # Create global static IP for Ingress
    print_status "Creating global static IP address..."
    if gcloud compute addresses create global-ingress --global 2>/dev/null; then
        print_status "Global static IP 'global-ingress' created ✓"
    else
        print_warning "Global static IP 'global-ingress' may already exist"
    fi
    
    # Display created IP addresses
    print_status "Static IP addresses:"
    gcloud compute addresses list --filter="name:(regional-loadbalancer OR global-ingress)"
}

# Verify manifests directory
verify_manifests() {
    print_header "Verifying manifest files..."
    
    manifest_files=(
        "manifests/dns-demo.yaml"
        "manifests/hello-v1.yaml"
        "manifests/hello-v2.yaml"
        "manifests/hello-svc.yaml"
        "manifests/hello-nodeport-svc.yaml"
        "manifests/hello-lb-svc.yaml"
        "manifests/hello-ingress.yaml"
    )
    
    for file in "${manifest_files[@]}"; do
        if [ -f "$file" ]; then
            print_status "$file exists ✓"
        else
            print_error "$file not found"
            exit 1
        fi
    done
}

# Main execution
main() {
    echo "=================================="
    echo "GKE Services and Ingress Lab Setup"
    echo "=================================="
    echo
    
    check_prerequisites
    setup_environment
    connect_to_cluster
    create_static_ips
    verify_manifests
    
    echo
    print_status "Setup completed successfully! 🎉"
    echo
    echo "Next steps:"
    echo "1. Run './scripts/deploy-all.sh' to deploy all resources"
    echo "2. Follow the README.md for testing instructions"
    echo
    echo "Environment variables set:"
    echo "  my_zone=$my_zone"
    echo "  my_cluster=$my_cluster"
    echo
}

# Run main function
main "$@"