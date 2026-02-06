#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting OpenClaw Deployment (1G Memory Optimized)...${NC}"

# 1. Update system and install prerequisites
echo -e "${YELLOW}Updating system packages...${NC}"
sudo apt-get update && sudo apt-get install -y git curl build-essential

# 2. Install Node.js 22 (if not present)
if ! command -v node &> /dev/null || [[ $(node -v) != v22* ]]; then
    echo -e "${YELLOW}Installing Node.js 22...${NC}"
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo -e "${GREEN}Node.js $(node -v) is already installed.${NC}"
fi

# 3. Clone Repository
TARGET_DIR="$HOME/openclaw"
REPO_URL="https://github.com/808cn163/openclaw-1G-memory.git"

if [ -d "$TARGET_DIR" ]; then
    echo -e "${YELLOW}Directory $TARGET_DIR already exists. Updating...${NC}"
    cd "$TARGET_DIR"
    git pull
else
    echo -e "${YELLOW}Cloning repository...${NC}"
    git clone "$REPO_URL" "$TARGET_DIR"
    cd "$TARGET_DIR"
fi

# 4. Install Dependencies
echo -e "${YELLOW}Installing dependencies (omitting dev dependencies to save memory)...${NC}"
# Use --omit=dev to save memory and avoid installing heavy dev tools
# Use --no-audit to speed up
cd "$TARGET_DIR"
if ! npm install --omit=dev --no-audit; then
    echo -e "${RED}Error: npm install failed.${NC}"
    echo -e "${YELLOW}Tip: If this is a memory issue, try adding swap space.${NC}"
    exit 1
fi

# Verify critical dependencies (e.g. chalk)
if [ ! -d "node_modules/chalk" ]; then
    # Fallback: try to install chalk explicitly if missing (though it should be in prod deps)
    echo -e "${YELLOW}Warning: chalk not found, attempting to fix...${NC}"
    npm install chalk
fi

# 5. Build Project
echo -e "${YELLOW}Building project...${NC}"
if ! npm run build; then
    echo -e "${RED}Build failed.${NC}"
    exit 1
fi

# 6. Make binaries executable
chmod +x openclaw.mjs

# 7. Configuration Wizard
echo -e "${GREEN}Deployment successful!${NC}"
echo -e "${YELLOW}Starting configuration wizard...${NC}"

# Run onboard
./openclaw.mjs onboard

echo -e "${GREEN}Setup complete! You can now run OpenClaw using ./openclaw.mjs gateway run${NC}"
