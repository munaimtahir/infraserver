#!/bin/bash
set -e

echo "=============================="
echo " Docker FULL RESET SCRIPT"
echo "=============================="

echo "[1/8] Stopping all running containers..."
docker stop $(docker ps -q) 2>/dev/null || true

echo "[2/8] Removing all containers..."
docker rm -f $(docker ps -aq) 2>/dev/null || true

echo "[3/8] Removing all images..."
docker rmi -f $(docker images -aq) 2>/dev/null || true

echo "[4/8] Removing all volumes..."
docker volume rm $(docker volume ls -q) 2>/dev/null || true

echo "[5/8] Removing all networks (except default)..."
docker network prune -f

echo "[6/8] Clearing build cache..."
docker builder prune -a -f

echo "[7/8] System prune (final sweep)..."
docker system prune -a --volumes -f

echo "[8/8] Verifying cleanup..."
docker system df

echo "=============================="
echo " Docker RESET COMPLETE"
echo " Server is now CLEAN"
echo "=============================="

