docker pull nginx:latest
docker run -d -p 8080:80 --name "meu-servidor" nginx:latest
docker ps
docker container stop "meu-servidor"
docker container rm "meu-servidor"
docker container ls --all
