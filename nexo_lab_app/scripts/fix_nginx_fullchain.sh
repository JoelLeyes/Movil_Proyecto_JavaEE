#!/bin/bash
# fix_nginx_fullchain.sh
# Uso: subir cert.pem chain.pem privkey.pem a /tmp y ejecutar:
# sudo bash fix_nginx_fullchain.sh /tmp/cert.pem /tmp/chain.pem /tmp/privkey.pem

set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Uso: sudo $0 /ruta/cert.pem /ruta/chain.pem /ruta/privkey.pem"
  exit 2
fi

CERT="$1"
CHAIN="$2"
KEY="$3"

DEST_DIR="/etc/ssl/nexolab"
FULLCHAIN="$DEST_DIR/fullchain.pem"
KEY_DEST="$DEST_DIR/privkey.pem"

echo "Creando directorio $DEST_DIR (si no existe)"
sudo mkdir -p "$DEST_DIR"

echo "Verificando archivos de entrada"
if [ ! -f "$CERT" ]; then echo "Certificado servidor no encontrado: $CERT"; exit 3; fi
if [ ! -f "$CHAIN" ]; then echo "Archivo intermedio no encontrado: $CHAIN"; exit 3; fi
if [ ! -f "$KEY" ]; then echo "Clave privada no encontrada: $KEY"; exit 3; fi

echo "Creando fullchain concatenando servidor + intermedios"
sudo bash -c "cat '$CERT' '$CHAIN' > '$FULLCHAIN'"

echo "Copiando clave privada"
sudo bash -c "cp '$KEY' '$KEY_DEST'"

echo "Ajustando permisos"
sudo chown root:root "$FULLCHAIN" "$KEY_DEST"
sudo chmod 644 "$FULLCHAIN"
sudo chmod 600 "$KEY_DEST"

# Buscar configuración de nginx que use ssl_certificate
NGINX_CONF=$(sudo nginx -T 2>/dev/null | grep -m1 -oP '(?<=ssl_certificate\s)\S+' || true)
if [ -n "$NGINX_CONF" ]; then
  echo "nginx parece apuntar a $NGINX_CONF (mostrar y comparar)"
  sudo echo "--- nginx config excerpt ---"
  sudo nginx -T | sed -n '/ssl_certificate/,+2p' || true
else
  echo "No encontré ssl_certificate en la configuración nginx con nginx -T"
  echo "Asegúrate de editar el server block con ssl_certificate pointing a $FULLCHAIN y ssl_certificate_key a $KEY_DEST"
fi

# Hacer backup de cualquier archivo anterior si existen
if [ -f "$NGINX_CONF" ] && [ "$NGINX_CONF" != "$FULLCHAIN" ]; then
  echo "Creando backup del archivo ssl_certificate actual: $NGINX_CONF.bak"
  sudo cp "$NGINX_CONF" "$NGINX_CONF.bak"
fi

# Recomendar editar nginx config si no apunta al fullchain
if [ -n "$NGINX_CONF" ] && [ "$NGINX_CONF" != "$FULLCHAIN" ]; then
  echo "Reemplaza ssl_certificate en nginx por: $FULLCHAIN"
  echo "Reemplaza ssl_certificate_key por: $KEY_DEST"
  echo "Luego prueba: sudo nginx -t && sudo systemctl reload nginx"
else
  echo "Intentando probar y recargar nginx..."
  sudo nginx -t
  sudo systemctl reload nginx
  echo "nginx recargado. Comprueba con: openssl s_client -connect localhost:443 -showcerts"
fi

echo "Hecho. Si algo falla, pega aquí la salida de: sudo nginx -T  y sudo openssl s_client -connect localhost:443 -showcerts"
