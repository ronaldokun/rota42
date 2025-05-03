docker stop $(docker ps -aq) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true
docker volume rm nginx_logs 2>/dev/null || true
docker volume create nginx_logs
chmod +x nginx-config/docker-entrypoint.sh
docker run -d --name nginx_container -v nginx_logs:/var/log/nginx -v $(pwd)/nginx-config/nginx.conf:/etc/nginx/nginx.conf:ro -v $(pwd)/nginx-config/docker-entrypoint.sh:/docker-entrypoint.sh:ro -p 8080:80 nginx:1.27.5-bookworm /docker-entrypoint.sh
sleep 10	
curl http://localhost:8080
curl http://localhost:8080
curl http://localhost:8080
# Obter o local de montagem do volume no sistema host
MOUNT_POINT=$(docker volume inspect nginx_logs --format '{{ .Mountpoint }}')
ls -la $MOUNT_POINT
cat $MOUNT_POINT/access.log
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
docker stop new_nginx_container
docker rm new_nginx_container
docker volume rm nginx_logs
