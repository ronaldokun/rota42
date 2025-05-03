# Persistência de Logs 
Agora que os desenvolvedores começaram a usar containers, um novo problema surgiu: os logs desaparecem toda vez que o container é reiniciado. O time de observabilidade está preocupado, pois não consegue monitorar os acessos ao sistema.

## Missão

Criar um volume para armazenar os logs do Nginx de forma persistente.

1. Criar um volume Docker chamado nginx_logs.
2. Executar um contêiner nginx, montando o volume nginx_logs no dirétorio /var/log/nginx do container e expondo a página web na porta 8080 da máquina local.
3. Gerar logs acessando a página hospedada no nginx executando localmente o comando curl http://localhost:8080.
4. Parar e remover o contêiner.
5. Criar um novo contêiner e validar que os logs antigos ainda existem.

## Problema
Na imagem oficial do Nginx, os arquivos de log são, por padrão, links simbólicos para /dev/stdout e /dev/stderr, o que permite que os logs sejam capturados pelo sistema de logs do Docker com o comando docker logs.

Quando você monta um volume no diretório /var/log/nginx, os links simbólicos continuam apontando para /dev/stdout e /dev/stderr dentro do contêiner, não para arquivos no volume. Por isso não há persistência dos logs quando você remove o contêiner.

## Solução 

1. Parar e remover contêineres
```
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true
```
2. Remover o volume existente
```
docker volume rm nginx_logs 2>/dev/null || true
```
3. Criar um novo volume
```
docker volume create nginx_logs
```
4. Cria um arquivo de configuração personalizado `nginx.conf` do Nginx que especifique arquivos físicos para os logs:
```
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    # Configuração de log que aponta para arquivo físico, não stdout
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    keepalive_timeout  65;

    # Configuração específica do servidor
    server {
        listen       80;
        server_name  localhost;

        location / {
            root   /usr/share/nginx/html;
            index  index.html index.htm;
        }

        # Outras configurações padrão
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   /usr/share/nginx/html;
        }
    }

    # Não inclua o diretório conf.d se vamos definir tudo aqui
    # include /etc/nginx/conf.d/*.conf;
}
```
5. Criar um script de inicialização `docker-entrypoint.sh` que remova os links simbólicos e prepare o diretório de logs:
> É importante não remover os arquivos _caso não sejam links simbólicos_, do contrário estaremos apagando os arquivos de log anteriores
```
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
```
6. Torna o script de entrada executável
```
chmod +x nginx-config/docker-entrypoint.sh
```
7. Executar o contêiner com nossa configuração personalizada
```
docker run -d --name nginx_container \
  -v nginx_logs:/var/log/nginx \
  -v $(pwd)/nginx-config/nginx.conf:/etc/nginx/nginx.conf:ro \
  -v $(pwd)/nginx-config/docker-entrypoint.sh:/docker-entrypoint.sh:ro \
  -p 8080:80 \
  nginx:1.27.5-bookworm \
  /docker-entrypoint.sh
```
8. Gerar logs
```
curl http://localhost:8080
curl http://localhost:8080
curl http://localhost:8080
```
9. Verificar geração de logs no sistema de arquivo do host
```
MOUNT_POINT=$(docker volume inspect nginx_logs --format '{{ .Mountpoint }}')
ls -la $MOUNT_POINT
cat $MOUNT_POINT/access.log
```
10. Parar e remover o contêiner e repetir o processo para verificar a persistências dos logs.
```
docker stop nginx_container
docker rm nginx_container
docker run -d --name new_nginx_container \
  -v nginx_logs:/var/log/nginx \
  -v $(pwd)/nginx-config/nginx.conf:/etc/nginx/nginx.conf:ro \
  -v $(pwd)/nginx-config/docker-entrypoint.sh:/docker-entrypoint.sh:ro \
  -p 8080:80 \
  nginx:1.27.5-bookworm \
  /docker-entrypoint.sh
sleep 10
curl http://localhost:8080
curl http://localhost:8080
curl http://localhost:8080
cat $MOUNT_POINT/access.log
```
> Devemos ter 6 registros de log nesse caso, 3 do contêiner anterior e 3 do atual
11. Limpar tudo
```
docker stop new_nginx_container
docker rm new_nginx_container
docker volume rm nginx_logs
```
