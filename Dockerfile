FROM node:22-alpine AS build
WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM nginx:alpine

COPY --from=build /app/dist /tmp/dist

RUN set -e; \
  rm -rf /usr/share/nginx/html/*; \
  if [ -f /tmp/dist/index.html ]; then \
    cp -r /tmp/dist/* /usr/share/nginx/html/; \
  elif [ -f /tmp/dist/frontend/index.html ]; then \
    cp -r /tmp/dist/frontend/* /usr/share/nginx/html/; \
  elif [ -f /tmp/dist/frontend/browser/index.html ]; then \
    cp -r /tmp/dist/frontend/browser/* /usr/share/nginx/html/; \
  else \
    APP_DIR="$(find /tmp/dist -maxdepth 3 -type f -name index.html -print -quit | xargs -r dirname)"; \
    echo "Detected Angular output dir: $APP_DIR"; \
    test -n "$APP_DIR"; \
    cp -r "$APP_DIR"/* /usr/share/nginx/html/; \
  fi; \
  rm -rf /tmp/dist

RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
