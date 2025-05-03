#!/bin/sh
set -e

# Remover os links simbólicos padrão de log
if [ -L /var/log/nginx/access.log ]; then
  rm -f /var/log/nginx/access.log
  touch /var/log/nginx/access.log
fi
if [ -L /var/log/nginx/error.log ]; then
  rm -f /var/log/nginx/error.log
  touch /var/log/nginx/error.log
fi

# Garantir permissões corretas
chown -R nginx:nginx /var/log/nginx

# Iniciar o Nginx com os argumentos recebidos
exec nginx -g "daemon off;"