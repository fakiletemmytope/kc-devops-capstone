FROM node:24.4-bookworm-slim AS builder

WORKDIR /app

COPY package.json package-lock.json* ./

RUN npm install

COPY . .  

ENV NODE_OPTIONS=--openssl-legacy-provider

RUN npm run build

# ---------- Stage 2: Serve ----------

FROM nginx:alpine

# Remove default NGINX index.html
RUN rm -rf /usr/share/nginx/html/*

COPY --from=builder /app/build /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
