#!/bin/bash

read -p "⚠️  This will destroy ALL Docker resources. Continue? (y/N) " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 1; }

echo "Stopping all running containers..."
docker stop $(docker ps -aq) 2>/dev/null || echo "No containers to stop"

echo "Removing all containers..."
docker rm $(docker ps -aq) 2>/dev/null || echo "No containers to remove"

echo "Removing all images..."
docker rmi $(docker images -q) -f 2>/dev/null || echo "No images to remove"

echo "Removing all volumes..."
docker volume rm $(docker volume ls -q) 2>/dev/null || echo "No volumes to remove"

echo "Removing all custom networks..."
docker network rm $(docker network ls --filter type=custom -q) 2>/dev/null || echo "No custom networks to remove"

echo "Pruning build cache..."
docker builder prune -af

echo "Pruning buildx..."
docker buildx prune -af 2>/dev/null || echo "No buildx cache to prune"

echo "Running system prune..."
docker system prune -af --volumes

echo ""
echo "Docker cleanup complete!"
docker system df
