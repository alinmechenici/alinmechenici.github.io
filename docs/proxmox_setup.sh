#!/bin/bash
# Proxmox VE Setup Script
# This script configures repositories, installs essential tools, and sets up Tailscale

set -e  # Exit on any error

echo "=== Proxmox VE Setup Script ==="
echo "This will:"
echo "- Remove enterprise repositories"
echo "- Add community repositories"
echo "- Install tailscale, emacs, neovim, tmux"
echo "- Configure and start Tailscale"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

echo "=== Step 1: Configuring Proxmox Repositories ==="

# Backup existing repository files
mkdir -p /root/repo-backup
cp -r /etc/apt/sources.list.d/ /root/repo-backup/ 2>/dev/null || true

# Remove/disable enterprise repositories
echo "Disabling enterprise repositories..."

# Remove broken files if they exist
rm -f /etc/apt/sources.list.d/pve-enterprise.sources
rm -f /etc/apt/sources.list.d/ceph.sources

# Recreate them as disabled (commented out)
cat > /etc/apt/sources.list.d/pve-enterprise.sources << 'EOF'
# Proxmox VE pve-enterprise repository provided by proxmox.com,
# NOT recommended for production use
# Types: deb
# URIs: https://enterprise.proxmox.com/debian/pve
# Suites: trixie
# Components: pve-enterprise
EOF

cat > /etc/apt/sources.list.d/ceph.sources << 'EOF'
# Proxmox VE ceph-enterprise repository provided by proxmox.com,
# NOT recommended for production use
# Types: deb
# URIs: https://enterprise.proxmox.com/debian/ceph-squid
# Suites: trixie
# Components: enterprise
EOF

# Add community repository
echo "Adding Proxmox community repository..."
cat > /etc/apt/sources.list.d/pve-no-subscription.sources << 'EOF'
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-release-trixie.gpg
EOF

echo "=== Step 2: Adding Tailscale Repository ==="

# Add Tailscale GPG key
echo "Adding Tailscale GPG key..."
curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null

# Add Tailscale repository
echo "Adding Tailscale repository..."
echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/debian trixie main" > /etc/apt/sources.list.d/tailscale.list

echo "=== Step 3: Updating Package Lists ==="
apt update

echo "=== Step 4: Upgrading System ==="
apt upgrade -y

echo "=== Step 5: Installing Packages ==="
echo "Installing tailscale, emacs, neovim, tmux..."

# Install packages
apt install -y tailscale emacs neovim tmux

echo "=== Step 6: Configuring Tailscale ==="

# Start and enable Tailscale
systemctl start tailscaled
systemctl enable tailscaled

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "Next steps:"
echo "1. Run 'tailscale up' to authenticate Tailscale"
echo "2. Visit the URL provided to complete setup"
echo "3. Access Proxmox via Tailscale IP: https://[tailscale-ip]:8006"
echo ""
echo "Installed packages:"
echo "- Tailscale: $(tailscale version 2>/dev/null || echo 'installed')"
echo "- Emacs: $(emacs --version | head -1)"
echo "- Neovim: $(nvim --version | head -1)"
echo "- Tmux: $(tmux -V)"
echo ""
echo "Repository backup saved to: /root/repo-backup/"
echo ""
echo "Run 'tailscale up' when ready to connect to your Tailscale network!"
