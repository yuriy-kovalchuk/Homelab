#!/bin/bash
set -euo pipefail

# Talos Cluster Upgrade Script
# Usage: cd terraform/clusters/main && devbox run upgrade_talos -- -v v1.12.0 --all

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
TALOSCONFIG="${TALOSCONFIG:-$HOME/.talos/config}"
PRESERVE=true
DRY_RUN=false

usage() {
    cat <<EOF
Usage: cd terraform/clusters/main && devbox run upgrade_talos -- [OPTIONS]

Upgrade Talos Linux on cluster nodes.

OPTIONS:
    -v, --version VERSION     Target Talos version (e.g., v1.12.0)
    -n, --node NODE           Upgrade specific node IP (can be repeated)
    -a, --all                 Upgrade all nodes (control planes first, one at a time)
    -s, --schematic ID        Schematic ID for custom extensions (auto-detected from terraform if not set)
    -c, --talosconfig PATH    Path to talosconfig (default: \$TALOSCONFIG or ~/.talos/config)
    --no-preserve             Don't preserve ephemeral data during upgrade
    --dry-run                 Show what would be done without executing
    -h, --help                Show this help message

EXAMPLES:
    cd terraform/clusters/main
    devbox run upgrade_talos -- -v v1.12.0 --all
    devbox run upgrade_talos -- -v v1.12.0 -n 10.0.2.20
    devbox run upgrade_talos -- -v v1.12.0 --all --dry-run

NOTES:
    - Control plane nodes are upgraded one at a time to maintain etcd quorum
    - Worker nodes can be upgraded in parallel (but this script does them sequentially)
    - After upgrade, update talos_version in variables.tf to keep Terraform in sync
EOF
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

get_schematic_from_terraform() {
    terraform output -raw talos_schematic_id 2>/dev/null || echo ""
}

get_nodes_from_terraform() {
    terraform output -json control_plane_ips 2>/dev/null | jq -r '.[]' 2>/dev/null || echo ""
}

get_current_version() {
    local node=$1
    talosctl version --nodes "$node" --short 2>/dev/null | grep "Tag:" | head -1 | awk '{print $2}' || echo "unknown"
}

upgrade_node() {
    local node=$1
    local image=$2
    local current_version

    current_version=$(get_current_version "$node")
    log_info "Node $node current version: $current_version"

    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[DRY-RUN] Would upgrade node $node to image: $image"
        return 0
    fi

    log_info "Upgrading node $node..."

    local preserve_flag=""
    if [[ "$PRESERVE" == "true" ]]; then
        preserve_flag="--preserve"
    fi

    if talosctl upgrade --nodes "$node" --image "$image" $preserve_flag; then
        log_info "Node $node upgrade initiated successfully"
        log_info "Waiting for node $node to come back online..."

        local retries=60
        while [[ $retries -gt 0 ]]; do
            if talosctl health --nodes "$node" --wait-timeout 10s &>/dev/null; then
                log_info "Node $node is healthy"
                return 0
            fi
            retries=$((retries - 1))
            sleep 10
        done

        log_error "Node $node did not become healthy in time"
        return 1
    else
        log_error "Failed to upgrade node $node"
        return 1
    fi
}

# Check we're in the right directory
if [[ ! -f "main.tf" ]] && [[ ! -f "versions.tf" ]]; then
    echo "Error: No terraform files found in current directory"
    echo "Usage: cd terraform/clusters/main && devbox run upgrade_talos -- -v v1.12.0 --all"
    exit 1
fi

# Parse arguments
NODES=()
TARGET_VERSION=""
SCHEMATIC_ID=""
UPGRADE_ALL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            TARGET_VERSION="$2"
            shift 2
            ;;
        -n|--node)
            NODES+=("$2")
            shift 2
            ;;
        -a|--all)
            UPGRADE_ALL=true
            shift
            ;;
        -s|--schematic)
            SCHEMATIC_ID="$2"
            shift 2
            ;;
        -c|--talosconfig)
            TALOSCONFIG="$2"
            shift 2
            ;;
        --no-preserve)
            PRESERVE=false
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ -z "$TARGET_VERSION" ]]; then
    log_error "Target version is required. Use -v or --version"
    usage
    exit 1
fi

if [[ ! "$TARGET_VERSION" =~ ^v ]]; then
    TARGET_VERSION="v$TARGET_VERSION"
fi

if [[ -z "$SCHEMATIC_ID" ]]; then
    log_info "Detecting schematic ID from Terraform..."
    SCHEMATIC_ID=$(get_schematic_from_terraform)
    if [[ -z "$SCHEMATIC_ID" ]]; then
        log_error "Could not detect schematic ID. Please provide with -s flag"
        exit 1
    fi
fi

log_info "Using schematic ID: $SCHEMATIC_ID"

UPGRADE_IMAGE="factory.talos.dev/installer/${SCHEMATIC_ID}:${TARGET_VERSION}"
log_info "Upgrade image: $UPGRADE_IMAGE"

if [[ "$UPGRADE_ALL" == "true" ]]; then
    log_info "Getting nodes from Terraform..."
    mapfile -t NODES < <(get_nodes_from_terraform)
    if [[ ${#NODES[@]} -eq 0 ]]; then
        log_error "No nodes found. Please specify nodes with -n flag"
        exit 1
    fi
fi

if [[ ${#NODES[@]} -eq 0 ]]; then
    log_error "No nodes specified. Use -n or --all"
    usage
    exit 1
fi

log_info "Nodes to upgrade: ${NODES[*]}"

if [[ "$DRY_RUN" == "false" ]]; then
    echo ""
    log_warn "This will upgrade ${#NODES[@]} node(s) to Talos $TARGET_VERSION"
    read -p "Continue? [y/N] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Upgrade cancelled"
        exit 0
    fi
fi

FAILED_NODES=()
for node in "${NODES[@]}"; do
    echo ""
    log_info "========================================="
    log_info "Processing node: $node"
    log_info "========================================="

    if ! upgrade_node "$node" "$UPGRADE_IMAGE"; then
        FAILED_NODES+=("$node")
        log_error "Node $node upgrade failed. Stopping to prevent cluster issues."
        break
    fi
done

echo ""
log_info "========================================="
log_info "Upgrade Summary"
log_info "========================================="

if [[ ${#FAILED_NODES[@]} -eq 0 ]]; then
    log_info "All nodes upgraded successfully!"
    echo ""
    log_warn "Don't forget to update talos_version in variables.tf:"
    echo "    variable \"talos_version\" {"
    echo "      default = \"$TARGET_VERSION\""
    echo "    }"
else
    log_error "Failed nodes: ${FAILED_NODES[*]}"
    exit 1
fi
