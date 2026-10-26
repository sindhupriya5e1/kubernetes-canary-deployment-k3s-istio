FROM node:20-alpine
WORKDIR /app
COPY app/package.json ./package.json
COPY app/server.js ./server.js
ARG APP_VERSION=stable
ENV APP_VERSION=${APP_VERSION}
ENV PORT=3000
EXPOSE 3000
USER node
CMD ["npm", "start"]
