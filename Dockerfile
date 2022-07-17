# docker build . -t soodesune/node-18-vitejs
FROM node:18-alpine3.15

RUN apk update
RUN npm update -g npm yarn

WORKDIR /www
RUN yarn global add vite sass
# RUN mkdir /node_modules
# ENV NODE_PATH=/node_modules
# COPY package.json /package.json
RUN yarn install
RUN yarn create vite app -- --template vanilla-ts

ENTRYPOINT ["yarn"]
