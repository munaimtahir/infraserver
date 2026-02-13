#!/bin/bash
# Environment Variable Validation Script
# Validates that all required environment variables are set

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "Environment Variable Validation"
echo "========================================="

# Check if .env file exists
if [ ! -f .env ]; then
    echo -e "${RED}ERROR: .env file not found${NC}"
    echo "Copy .env.example to .env and fill in the values"
    exit 1
fi

# Source .env file
set -a
source .env
set +a

# Required variables
REQUIRED_VARS=(
    "PUBLIC_IP"
    "DB_HOST"
    "DB_NAME"
    "DB_USER"
    "DB_PASSWORD"
    "REDIS_HOST"
    "CONSULT_SECRET_KEY"
)

# Optional but recommended variables
RECOMMENDED_VARS=(
    "CONSULT_CORS_ALLOWED_ORIGINS"
    "CONSULT_CSRF_TRUSTED_ORIGINS"
)

# Check required variables
MISSING_VARS=()
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        MISSING_VARS+=("$var")
    fi
done

# Check recommended variables
MISSING_RECOMMENDED=()
for var in "${RECOMMENDED_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        MISSING_RECOMMENDED+=("$var")
    fi
done

# Report results
if [ ${#MISSING_VARS[@]} -eq 0 ]; then
    echo -e "${GREEN}✓ All required variables are set${NC}"
else
    echo -e "${RED}✗ Missing required variables:${NC}"
    for var in "${MISSING_VARS[@]}"; do
        echo -e "  ${RED}- $var${NC}"
    done
    exit 1
fi

if [ ${#MISSING_RECOMMENDED[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠ Missing recommended variables:${NC}"
    for var in "${MISSING_RECOMMENDED[@]}"; do
        echo -e "  ${YELLOW}- $var${NC}"
    done
fi

# Validate IP format (basic check)
if [[ ! $PUBLIC_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo -e "${YELLOW}⚠ Warning: PUBLIC_IP format may be invalid: $PUBLIC_IP${NC}"
fi

# Check secret key strength
if [ ${#CONSULT_SECRET_KEY} -lt 50 ]; then
    echo -e "${YELLOW}⚠ Warning: CONSULT_SECRET_KEY is too short (should be at least 50 characters)${NC}"
fi

if [ "$CONSULT_SECRET_KEY" = "change_me_in_prod" ]; then
    echo -e "${YELLOW}⚠ Warning: Using default SECRET_KEY. Change this in production!${NC}"
fi

# Check database password strength
if [ ${#DB_PASSWORD} -lt 8 ]; then
    echo -e "${YELLOW}⚠ Warning: DB_PASSWORD is too short (should be at least 8 characters)${NC}"
fi

echo ""
echo "========================================="
echo -e "${GREEN}Validation Complete${NC}"
echo "========================================="
