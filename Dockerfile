FROM node:14-alpine

WORKDIR /app

COPY package.json .

RUN npm install

COPY . .

EXPOSE 80

RUN apk add curl

HEALTHCHECK CMD curl --fail http://localhost:80 || exit 1 

CMD ["node", "app.js"]