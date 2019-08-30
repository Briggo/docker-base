FROM vault:1.1.2

RUN apk update
RUN apk add curl jq

RUN rm /var/cache/apk/*
RUN rm -rf /root/.cache /tmp/*


#reference:  https://github.com/hashicorp/docker-vault/blob/7d372e399d5d8b8ecd9b0f84cc599bb2759f5e1b/0.X/Dockerfile
