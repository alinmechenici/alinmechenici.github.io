#!/bin/bash
# Quick fix for Proxmox repository 401 errors

echo "=== Proxmox Repository Quick Fix ==="
echo "Fixing 401 Unauthorized errors from enterprise repositories..."

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Find and disable all enterprise repositories
echo "Searching for active enterprise repositories..."

# Check all repository files
for repo_file in /etc/apt/sources.list /etc/apt/sources.list.d/*; do
    if [[ -f "$repo_file" ]]; then
        # Check if file contains enterprise repos
        if grep -q "enterprise.proxmox.com" "$repo_file" 2>/dev/null; then
            echo "Found enterprise repo in: $repo_file"
            # Create backup
            cp "$repo_file" "${repo_file}.backup.$(date +%Y%m%d-%H%M%S)"
            # Comment out enterprise lines
            sed -i 's|^[^#]*enterprise\.proxmox\.com|# &|g' "$repo_file"
            echo "  ✅ Disabled enterprise repositories in $repo_file"
        fi
    fi
done

# Remove any problematic .sources files completely
for sources_file in /etc/apt/sources.list.d/*.sources; do
    if [[ -f "$sources_file" ]] && grep -q "enterprise.proxmox.com" "$sources_file" 2>/dev/null; then
        echo "Removing problematic sources file: $sources_file"
        mv "$sources_file" "${sources_file}.disabled.$(date +%Y%m%d-%H%M%S)"
    fi
done

echo ""
echo "=== Cleaning apt cache and updating ==="
apt clean
apt update

echo ""
echo "✅ Repository fix completed!"
echo "Enterprise repositories have been disabled."
echo "Backups created with timestamp suffixes."