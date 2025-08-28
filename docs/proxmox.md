# Enhanced Proxmox VE Setup Script

![Proxmox Logo](https://raw.githubusercontent.com/alinmechenici/alinmechenici.github.io/main/docs/proxmox.png)

A comprehensive script to configure Proxmox VE with community repositories, remove subscription nag, install essential tools, and apply custom branding.

## ⚡ Quick Start

### One-liner installation and execution:
```bash
curl -fsSL https://raw.githubusercontent.com/alinmechenici/alinmechenici.github.io/main/docs/proxmox.sh | bash
```

### Manual installation:
```bash
# Download the script
wget https://raw.githubusercontent.com/alinmechenici/alinmechenici.github.io/main/docs/proxmox.sh

# Make it executable
chmod +x proxmox.sh

# Run the script
./proxmox.sh
```

## 🚀 What This Script Does

### ✅ Repository Configuration
- Disables enterprise repositories (requires subscription)
- Enables community repositories (free)
- Safely backs up original configurations

### 🔧 System Enhancements
- **Removes subscription nag popup** (cosmetic fix)
- **Installs essential tools**: Tailscale, Emacs, Neovim, Tmux
- **Custom logo branding** with your organization's logo
- **Automatic backup system** for all modifications

### 🌐 Networking
- Configures Tailscale VPN for secure remote access
- Sets up repositories and GPG keys automatically

### 🛡️ Safety Features
- **System upgrades disabled by default** (production-safe)
- Comprehensive backup system with timestamps
- Skip logic prevents re-running completed steps
- Easy restoration commands for all changes

## 📋 Requirements

- **Proxmox VE 8.x** (Debian 12 "Bookworm" based)
- **Root access** (script must run as root)
- **Internet connection** for downloading packages and logo

## 🔧 Post-Installation Steps

### 1. Complete Tailscale Setup
```bash
# Authenticate with Tailscale
tailscale up

# Follow the URL provided to complete setup
```

### 2. Access Proxmox via Tailscale
Once Tailscale is configured:
```
https://[your-tailscale-ip]:8006
```

### 3. Manual System Upgrade (When Ready)
The script disables automatic upgrades for safety. Upgrade manually:
```bash
# See what will be upgraded
apt list --upgradable

# Upgrade with confirmation prompts (recommended)
apt upgrade

# Or automatic upgrade (use with caution)
apt upgrade -y
```

## 🛠️ Management Commands

The script creates several utility commands for ongoing management:

### Subscription Nag Management
```bash
# Remove nag popup (if it returns after updates)
/usr/local/bin/remove-proxmox-nag.sh
```

### Logo Management
```bash
# Update to a new logo
/usr/local/bin/update-custom-logo.sh https://yourcompany.com/logo.png

# Restore original Proxmox logo
/usr/local/bin/restore-proxmox-logo.sh
```

### Backup Locations
```bash
# Repository backups
ls /root/repo-backup/

# Logo backups
ls /root/logo-backup/

# JavaScript file backups (nag removal)
ls /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js.bak.*
```

## ⚠️ Important Notes

### Production Safety
- **System upgrades are disabled by default** to prevent unexpected changes
- All modifications are backed up with timestamps
- Script can be run multiple times safely (skip logic included)
- Test on development systems first when possible

### Subscription Warning
- The nag removal is **cosmetic only** - it doesn't provide enterprise features
- Consider purchasing a proper Proxmox subscription for:
  - Production environments
  - Commercial use
  - Access to enterprise repositories
  - Professional support

### File Modifications
The script modifies these files (with backups):
- `/etc/apt/sources.list.d/` - Repository configurations
- `/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js` - Subscription nag
- `/usr/share/pve-manager/images/proxmox_logo.png` - Custom logo

## 🔄 Updates and Maintenance

### After Proxmox Updates
Some modifications may need to be reapplied after system updates:

```bash
# Check if nag removal is still active
grep -q "void({ //Ext.Msg.show" /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js && echo "Nag removal active" || echo "Nag removal needs reapplication"

# Reapply nag removal if needed
/usr/local/bin/remove-proxmox-nag.sh

# Check if custom logo is still active
ls -la /usr/share/pve-manager/images/proxmox_logo.png*
```

### Logo Updates
To change your logo to a different image:
```bash
/usr/local/bin/update-custom-logo.sh https://newdomain.com/newlogo.png
```

## 🐛 Troubleshooting

### Web Interface Issues
If the web interface becomes unresponsive after running the script:
```bash
# Restart the web proxy
systemctl restart pveproxy

# Check service status
systemctl status pveproxy

# View logs
journalctl -u pveproxy -f
```

### Restore Original State
To completely restore original Proxmox state:
```bash
# Restore repositories
cp -r /root/repo-backup/* /etc/apt/sources.list.d/

# Restore JavaScript file
cp /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js.bak.* /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js

# Restore original logo
/usr/local/bin/restore-proxmox-logo.sh

# Restart services
systemctl restart pveproxy
```

### Logo Display Issues
```bash
# Check if logo file exists and is valid
file /usr/share/pve-manager/images/proxmox_logo.png

# Clear browser cache and hard refresh (Ctrl+F5)
# Or try incognito/private browsing mode
```

## 📞 Support

For issues with this script:
1. Check the troubleshooting section above
2. Verify you're running as root
3. Ensure internet connectivity
4. Check Proxmox version compatibility

For Proxmox VE issues:
- [Official Proxmox Documentation](https://pve.proxmox.com/wiki/Main_Page)
- [Proxmox Community Forum](https://forum.proxmox.com/)

## 📝 License

This script is provided as-is for educational and convenience purposes. Use at your own risk.

**Disclaimer**: This script modifies system files. While it includes safety measures and backups, always test in non-production environments first.

---

**Made with ❤️ for the Proxmox community**
