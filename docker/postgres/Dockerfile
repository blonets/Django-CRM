FROM postgres:16-alpine

COPY init-rls-user.sh /docker-entrypoint-initdb.d/
RUN chmod +x /docker-entrypoint-initdb.d/init-rls-user.sh