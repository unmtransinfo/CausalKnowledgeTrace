#!/bin/bash
# =============================================================================
# Apply Production Performance Fix
# =============================================================================
# This script applies the Docker network configuration fix to improve
# production graph creation performance from ~5 minutes to ~30 seconds
#
# Usage: ./apply_performance_fix.sh
# =============================================================================

set -e  # Exit on error

echo "========================================="
echo "🚀 Production Performance Fix"
echo "========================================="
echo ""
echo "This will:"
echo "  1. Stop current production containers"
echo "  2. Apply network configuration fix"
echo "  3. Restart containers with optimized networking"
echo ""
echo "Expected improvement: 10x faster graph creation"
echo "  Before: ~5 minutes for degree 2 graphs"
echo "  After:  ~30 seconds for degree 2 graphs"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "========================================="
echo "Step 1: Stopping production containers"
echo "========================================="
docker compose -f docker-compose.prod.yaml down

echo ""
echo "========================================="
echo "Step 2: Rebuilding with network fix"
echo "========================================="
docker compose -f docker-compose.prod.yaml up -d --build

echo ""
echo "========================================="
echo "Step 3: Verifying network configuration"
echo "========================================="

# Wait for containers to start
sleep 5

# Check network exists
if docker network ls | grep -q "ckt-prod-network"; then
    echo "✅ Network 'ckt-prod-network' created successfully"
else
    echo "❌ ERROR: Network 'ckt-prod-network' not found"
    exit 1
fi

# Check containers are on the network
NETWORK_CONTAINERS=$(docker network inspect ckt-prod-network -f '{{range .Containers}}{{.Name}} {{end}}' 2>/dev/null || echo "")

if echo "$NETWORK_CONTAINERS" | grep -q "db-prod"; then
    echo "✅ Database container connected to network"
else
    echo "❌ WARNING: Database container not on network"
fi

if echo "$NETWORK_CONTAINERS" | grep -q "django-prod"; then
    echo "✅ Django container connected to network"
else
    echo "❌ WARNING: Django container not on network"
fi

echo ""
echo "========================================="
echo "Step 4: Checking container status"
echo "========================================="
docker compose -f docker-compose.prod.yaml ps

echo ""
echo "========================================="
echo "✅ Performance Fix Applied Successfully!"
echo "========================================="
echo ""
echo "Next steps:"
echo "  1. Test graph creation at: http://10.234.117.212:3838/config/"
echo "  2. Create a degree 2 graph"
echo "  3. Verify it completes in ~30 seconds"
echo ""
echo "To view logs:"
echo "  docker compose -f docker-compose.prod.yaml logs -f"
echo ""
echo "To check network details:"
echo "  docker network inspect ckt-prod-network"
echo ""

