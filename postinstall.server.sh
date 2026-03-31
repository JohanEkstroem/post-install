#!/bin/bash
set -e

echo "🚀 Starting post-install setup..."

# === VARIABLES ===
USERNAME="deploy"
SSH_PORT=22
TIMEZONE="Europe/Stockholm"

# === UPDATE SYSTEM ===
echo "📦 Updating system..."
apt update && apt upgrade -y

# === INSTALL BASE PACKAGES ===
echo "🧰 Installing base packages..."
apt install -y \
  curl wget git vim htop unzip \
  ca-certificates gnupg lsb-release \
  ufw fail2ban

# === CREATE USER ===
if id "$USERNAME" &>/dev/null; then
  echo "👤 User $USERNAME already exists"
else
  echo "👤 Creating user $USERNAME..."
  adduser --disabled-password --gecos "" $USERNAME
  usermod -aG sudo $USERNAME
fi

# === SETUP SSH DIRECTORY ===
echo "🔑 Setting up SSH directory..."
mkdir -p /home/$USERNAME/.ssh
chmod 700 /home/$USERNAME/.ssh
touch /home/$USERNAME/.ssh/authorized_keys
chmod 600 /home/$USERNAME/.ssh/authorized_keys
chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh

echo "⚠️  Add your public SSH key to /home/$USERNAME/.ssh/authorized_keys"

# === SSH HARDENING ===
echo "🔐 Hardening SSH..."
SSHD_CONFIG="/etc/ssh/sshd_config"

sed -i "s/#\?PermitRootLogin .*/PermitRootLogin no/" $SSHD_CONFIG
sed -i "s/#\?PasswordAuthentication .*/PasswordAuthentication no/" $SSHD_CONFIG
sed -i "s/#\?Port .*/Port $SSH_PORT/" $SSHD_CONFIG

systemctl restart ssh

# === FIREWALL ===
echo "🔥 Configuring firewall..."
ufw allow $SSH_PORT
ufw allow OpenSSH
ufw allow 80
ufw allow 443
ufw --force enable

# === FAIL2BAN ===
echo "🛡️ Enabling fail2ban..."
systemctl enable fail2ban
systemctl start fail2ban

# === INSTALL DOCKER ===
echo "🐳 Installing Docker..."

install -m 0755 -d /etc/apt/keyrings

if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
  curl -fsSL https://download.docker.com/linux/debian/gpg | \
    gpg --dearmor -o /etc/apt/keyrings/docker.gpg
fi

chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  > /etc/apt/sources.list.d/docker.list

apt update

apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

systemctl enable docker
systemctl start docker

usermod -aG docker $USERNAME

# === INSTALL NGINX ===
echo "🌐 Installing Nginx..."
apt install -y nginx
systemctl enable nginx
systemctl start nginx

# === INSTALL CERTBOT ===
echo "🔒 Installing Certbot..."
apt install -y certbot python3-certbot-nginx

# === TIMEZONE ===
echo "🕒 Setting timezone..."
timedatectl set-timezone $TIMEZONE

# === AUTO UPDATES ===
echo "🔁 Enabling unattended upgrades..."
apt install -y unattended-upgrades
dpkg-reconfigure -f noninteractive unattended-upgrades

# === CLEANUP ===
echo "🧹 Cleaning up..."
apt autoremove -y

# === DONE ===
echo "✅ Setup complete!"
echo ""
echo "👉 NEXT STEPS:"
echo "1. Add your SSH key:"
echo "   nano /home/$USERNAME/.ssh/authorized_keys"
echo ""
echo "2. Test login in a new terminal:"
echo "   ssh $USERNAME@your-server-ip"
echo ""
echo "3. (Optional) Setup SSL:"
echo "   certbot --nginx -d your-domain.com"
echo ""
echo "4. Reboot recommended:"
echo "   reboot"