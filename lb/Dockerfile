FROM debian:stretch
MAINTAINER STI-IT ops <stiitops@groupes.epfl.ch>
RUN apt -y update && apt -y install nginx nginx-extras luarocks
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log
RUN luarocks install nginx-lua-prometheus
EXPOSE 80

STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]
