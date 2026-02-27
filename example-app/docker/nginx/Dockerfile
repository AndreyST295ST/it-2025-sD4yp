FROM nginx:1.29

RUN apt-get update && apt-get install mc -y

RUN usermod -u 1000 nginx && groupmod -g 1000 nginx