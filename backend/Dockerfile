# stage 1
FROM node:24.4-bookworm-slim AS builder

WORKDIR /app
COPY ./package*.json .
RUN npm install

# Stage 2: Copy source code and dependencies
FROM node:24.4-bookworm-slim
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY . .
EXPOSE 3001
CMD [ "node", "server.js" ]
