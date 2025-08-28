#!/bin/bash
# Enhanced Proxmox VE Setup Script
# This script configures repositories, removes subscription nag, installs essential tools, and sets up Tailscale

set -e  # Exit on any error

echo "=== Enhanced Proxmox VE Setup Script ==="
echo "This will:"
echo "- Remove enterprise repositories"
echo "- Add community repositories"
echo "- Remove subscription nag popup"
echo "- Install tailscale, emacs, neovim, tmux"
echo "- Configure and start Tailscale"
echo "- Install custom logo"
echo "⚠️  System upgrade is DISABLED for safety (see Step 5 to enable)"
echo ""

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

echo "=== Step 1: Configuring Proxmox Repositories ==="

# Check if repositories are already configured
if [[ -f /etc/apt/sources.list.d/pve-no-subscription.sources ]]; then
    echo "ℹ️  Proxmox repositories already configured. Skipping repository setup."
else
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
    echo "✅ Proxmox repositories configured."
fi

echo "=== Step 2: Removing Subscription Nag ==="

# Function to remove subscription nag
remove_subscription_nag() {
    local js_file="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"
    
    if [[ -f "$js_file" ]]; then
        # Check if nag is already removed
        if grep -q "void({ //Ext.Msg.show" "$js_file"; then
            echo "ℹ️  Subscription nag already removed. Skipping."
            return 0
        fi
        
        echo "Backing up original proxmoxlib.js..."
        cp "$js_file" "${js_file}.bak.$(date +%Y%m%d-%H%M%S)"
        
        echo "Removing subscription nag popup..."
        # Use sed to comment out the subscription popup
        sed -Ezi "s/(Ext\.Msg\.show\(\{\s+title: gettext\('No valid subscription)/void\({ \/\/\1/g" "$js_file"
        
        echo "✅ Subscription nag removed successfully."
    else
        echo "⚠️  proxmoxlib.js not found at expected location. Skipping nag removal."
        return 1
    fi
}

# Create persistent nag removal script for updates
create_nag_removal_script() {
    if [[ -f /usr/local/bin/remove-proxmox-nag.sh ]]; then
        echo "ℹ️  Nag removal script already exists. Skipping creation."
        return 0
    fi
    
    echo "Creating persistent nag removal script..."
    
    cat > /usr/local/bin/remove-proxmox-nag.sh << 'EOF'
#!/bin/bash
# Persistent Proxmox subscription nag removal script

JS_FILE="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"

if [[ -f "$JS_FILE" ]]; then
    # Check if nag is already removed
    if grep -q "void({ //Ext.Msg.show" "$JS_FILE"; then
        echo "Subscription nag already removed."
        exit 0
    fi
    
    echo "Removing subscription nag..."
    cp "$JS_FILE" "${JS_FILE}.bak.$(date +%Y%m%d-%H%M%S)"
    sed -Ezi "s/(Ext\.Msg\.show\(\{\s+title: gettext\('No valid subscription)/void\({ \/\/\1/g" "$JS_FILE"
    
    # Restart proxy service
    systemctl restart pveproxy
    echo "Subscription nag removed and service restarted."
else
    echo "Error: proxmoxlib.js not found!"
    exit 1
fi
EOF

    chmod +x /usr/local/bin/remove-proxmox-nag.sh
    echo "Nag removal script created at /usr/local/bin/remove-proxmox-nag.sh"
}

# Create systemd service to run after package updates
create_nag_removal_service() {
    if [[ -f /etc/systemd/system/remove-proxmox-nag.service ]]; then
        echo "ℹ️  Nag removal systemd service already exists. Skipping creation."
        return 0
    fi
    
    echo "Creating systemd service for automatic nag removal..."
    
    cat > /etc/systemd/system/remove-proxmox-nag.service << 'EOF'
[Unit]
Description=Remove Proxmox subscription nag
After=apt-daily.service apt-daily-upgrade.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/remove-proxmox-nag.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable remove-proxmox-nag.service
    echo "Systemd service created and enabled."
}

# Execute nag removal functions
remove_subscription_nag
create_nag_removal_script
create_nag_removal_service

echo "=== Step 3: Adding Tailscale Repository ==="

# Check if Tailscale is already installed
if command -v tailscale >/dev/null 2>&1; then
    echo "ℹ️  Tailscale already installed. Skipping Tailscale repository setup."
else
    # Add Tailscale GPG key
    echo "Adding Tailscale GPG key..."
    curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null

    # Add Tailscale repository
    echo "Adding Tailscale repository..."
    echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/debian trixie main" > /etc/apt/sources.list.d/tailscale.list
    echo "✅ Tailscale repository added."
fi

echo "=== Step 4: Updating Package Lists ==="
apt update

echo "=== Step 5: System Upgrade (Optional) ==="
echo "ℹ️  System upgrade commented out for safety on production systems."
echo "   Uncomment the line below if you want automatic system upgrade:"
echo "   # apt upgrade -y"
echo ""
echo "🔧 To upgrade manually when ready:"
echo "   apt list --upgradable    # See what will be upgraded"
echo "   apt upgrade              # Upgrade with confirmation prompts"
echo "   apt upgrade -y           # Upgrade automatically (use with caution)"
echo ""

# Commented out for safety - uncomment if you want automatic upgrades
# apt upgrade -y

echo "=== Step 6: Installing Packages ==="

# Check which packages need to be installed
packages_to_install=()
check_packages=("tailscale" "emacs" "neovim" "tmux")

for pkg in "${check_packages[@]}"; do
    if ! command -v "$pkg" >/dev/null 2>&1; then
        packages_to_install+=("$pkg")
    fi
done

if [[ ${#packages_to_install[@]} -eq 0 ]]; then
    echo "ℹ️  All packages already installed. Skipping package installation."
else
    echo "Installing missing packages: ${packages_to_install[*]}"
    apt install -y "${packages_to_install[@]}"
    echo "✅ Packages installed successfully."
fi

echo "=== Step 7: Configuring Tailscale ==="

# Check if Tailscale is already configured
if systemctl is-enabled tailscaled >/dev/null 2>&1 && systemctl is-active tailscaled >/dev/null 2>&1; then
    echo "ℹ️  Tailscale already configured and running. Skipping Tailscale setup."
else
    # Start and enable Tailscale
    systemctl start tailscaled
    systemctl enable tailscaled
    echo "✅ Tailscale service started and enabled."
fi

echo "=== Step 8: Customizing Proxmox Logo ==="

# Function to replace Proxmox logo
replace_proxmox_logo() {
    local logo_url="https://raw.githubusercontent.com/alinmechenici/alinmechenici.github.io/main/docs/proxmox.png"
    local logo_dir="/usr/share/pve-manager/images"
    local original_logo="$logo_dir/proxmox_logo.png"
    local backup_logo="$logo_dir/proxmox_logo.png.original"
    
    echo "Replacing Proxmox logo with custom logo..."
    
    # Create backup directory if it doesn't exist
    mkdir -p /root/logo-backup
    
    # Check if logo has already been customized
    if [[ -f "$backup_logo" ]]; then
        echo "ℹ️  Custom logo already installed. Skipping logo replacement."
        echo "   Use /usr/local/bin/update-custom-logo.sh to change it."
        return 0
    fi
    
    # Backup original logo if it exists
    if [[ -f "$original_logo" ]]; then
        echo "Backing up original Proxmox logo..."
        cp "$original_logo" "$backup_logo"
        cp "$original_logo" /root/logo-backup/proxmox_logo.png.$(date +%Y%m%d-%H%M%S)
    else
        echo "⚠️  Original logo not found at $original_logo"
        return 1
    fi
    
    # Download and replace logo
    if command -v wget >/dev/null 2>&1; then
        echo "Downloading custom logo from: $logo_url"
        if wget -q --timeout=10 --tries=3 "$logo_url" -O /tmp/custom_logo.png; then
            # Verify it's a valid PNG file
            if file /tmp/custom_logo.png | grep -q "PNG image"; then
                cp /tmp/custom_logo.png "$original_logo"
                echo "✅ Custom logo installed successfully."
                rm -f /tmp/custom_logo.png
            else
                echo "⚠️  Downloaded file is not a valid PNG image. Skipping logo replacement."
                rm -f /tmp/custom_logo.png
                return 1
            fi
        else
            echo "⚠️  Failed to download custom logo. Using default Proxmox logo."
            return 1
        fi
    else
        echo "⚠️  wget not found. Installing wget first..."
        apt install -y wget
        # Retry logo download
        replace_proxmox_logo
        return
    fi
}

# Function to create logo restoration script
create_logo_restoration_script() {
    if [[ -f /usr/local/bin/restore-proxmox-logo.sh && -f /usr/local/bin/update-custom-logo.sh ]]; then
        echo "ℹ️  Logo management scripts already exist. Skipping creation."
        return 0
    fi
    
    echo "Creating logo management scripts..."
    
    # Script to restore original logo
    cat > /usr/local/bin/restore-proxmox-logo.sh << 'EOF'
#!/bin/bash
# Restore original Proxmox logo

LOGO_DIR="/usr/share/pve-manager/images"
ORIGINAL_LOGO="$LOGO_DIR/proxmox_logo.png"
BACKUP_LOGO="$LOGO_DIR/proxmox_logo.png.original"

if [[ -f "$BACKUP_LOGO" ]]; then
    cp "$BACKUP_LOGO" "$ORIGINAL_LOGO"
    systemctl restart pveproxy
    echo "Original Proxmox logo restored."
else
    echo "No backup logo found. Cannot restore original."
    exit 1
fi
EOF

    # Script to update custom logo
    cat > /usr/local/bin/update-custom-logo.sh << 'EOF'
#!/bin/bash
# Update custom Proxmox logo

LOGO_URL="${1:-https://raw.githubusercontent.com/alinmechenici/alinmechenici.github.io/main/docs/proxmox.png}"
LOGO_DIR="/usr/share/pve-manager/images"
ORIGINAL_LOGO="$LOGO_DIR/proxmox_logo.png"

if [[ -z "$1" ]]; then
    echo "Usage: $0 <logo_url>"
    echo "Example: $0 https://yourcompany.com/new-logo.png"
    echo ""
    echo "Current default URL: https://raw.githubusercontent.com/alinmechenici/alinmechenici.github.io/main/docs/proxmox.png"
    exit 1
fi

echo "Downloading logo from: $LOGO_URL"

if wget -q --timeout=10 --tries=3 "$LOGO_URL" -O /tmp/new_custom_logo.png; then
    if file /tmp/new_custom_logo.png | grep -q "PNG image"; then
        cp /tmp/new_custom_logo.png "$ORIGINAL_LOGO"
        systemctl restart pveproxy
        echo "✅ Custom logo updated successfully."
        echo "🔄 Proxmox web interface restarted."
        echo "💡 Clear browser cache and reload to see changes."
        rm -f /tmp/new_custom_logo.png
    else
        echo "❌ Downloaded file is not a valid PNG image."
        rm -f /tmp/new_custom_logo.png
        exit 1
    fi
else
    echo "❌ Failed to download logo from: $LOGO_URL"
    exit 1
fi
EOF

    chmod +x /usr/local/bin/restore-proxmox-logo.sh
    chmod +x /usr/local/bin/update-custom-logo.sh
    echo "Logo management scripts created."
}

# Execute logo customization
replace_proxmox_logo
create_logo_restoration_script

echo "=== Step 9: Final Configuration ==="

# Restart pveproxy to apply all changes
echo "Restarting Proxmox web proxy..."
systemctl restart pveproxy

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "✅ Configurations applied:"
echo "   - Enterprise repositories disabled"
echo "   - Community repository enabled"
echo "   - Subscription nag popup removed"
echo "   - Automatic nag removal after updates enabled"
echo "   - Custom company logo installed"
echo "   - Essential tools installed"
echo "   - Tailscale configured"
echo ""
echo "📋 Next steps:"
echo "1. Run 'tailscale up' to authenticate Tailscale"
echo "2. Visit the URL provided to complete setup"
echo "3. Access Proxmox via Tailscale IP: https://[tailscale-ip]:8006"
echo "4. Clear browser cache and reload Proxmox web interface"
echo "5. Update logo URL: /usr/local/bin/update-custom-logo.sh https://your-domain.com/logo.png"
echo "   Current logo URL: https://raw.githubusercontent.com/alinmechenici/alinmechenici.github.io/main/docs/proxmox.png"
echo ""
echo "📦 Installed packages:"
echo "- Tailscale: $(tailscale version 2>/dev/null || echo 'installed')"
echo "- Emacs: $(emacs --version | head -1)"
echo "- Neovim: $(nvim --version | head -1)"
echo "- Tmux: $(tmux -V)"
echo ""
echo "🛠️  Maintenance commands:"
echo "- Manual nag removal: /usr/local/bin/remove-proxmox-nag.sh"
echo "- Update custom logo: /usr/local/bin/update-custom-logo.sh <url>"
echo "- Restore original logo: /usr/local/bin/restore-proxmox-logo.sh"
echo "- Manual system upgrade: apt upgrade (or apt upgrade -y for auto)"
echo "- Repository backup location: /root/repo-backup/"
echo "- Logo backup location: /root/logo-backup/"
echo ""
echo "⚠️  Note: The subscription nag removal is cosmetic only."
echo "    Consider a proper subscription for production environments."
echo "    System upgrades are disabled by default - run manually when ready."
echo ""
echo "🚀 Run 'tailscale up' when ready to connect to your Tailscale network!"