FROM node:23-alpine

WORKDIR /fabric/application

COPY package*.json ./
RUN npm install

COPY . .

EXPOSE 3000

CMD ["node", "server.js"]
