FROM node:18-alpine

RUN apk add --no-cache caddy curl

WORKDIR /app
COPY package.json ./
RUN npm install --production
COPY server.js apps.config.json ./
ENV PORT=4000
CMD ["npm", "start"]
