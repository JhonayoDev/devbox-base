#!/bin/bash
set -e

USERNAME="${USERNAME:-user}"
USER_HOME="/home/$USERNAME"

echo "[devbox] Iniciando entorno para usuario: $USERNAME"

if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
    echo "[devbox] Generando SSH host keys..."
    ssh-keygen -A
fi

chmod 600 /etc/ssh/ssh_host_*_key
chmod 644 /etc/ssh/ssh_host_*_key.pub

chown -R "$USERNAME:$USERNAME" "$USER_HOME/.cache" "$USER_HOME/.local" 2>/dev/null || true

MOUNTED_KEYS="/run/secrets/authorized_keys"
TARGET_KEYS="$USER_HOME/.ssh/authorized_keys"

if [ -f "$MOUNTED_KEYS" ]; then
    echo "[devbox] Copiando authorized_keys desde secrets..."
    cp "$MOUNTED_KEYS" "$TARGET_KEYS"
    chown "$USERNAME:$USERNAME" "$TARGET_KEYS"
    chmod 600 "$TARGET_KEYS"
elif [ ! -f "$TARGET_KEYS" ]; then
    echo "[devbox] ADVERTENCIA: No se encontro authorized_keys."
fi

echo "[devbox] Arrancando sshd..."
exec /usr/sbin/sshd -D -e
