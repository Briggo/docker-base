FROM mdillon/postgis:9.6-alpine

# Install Updates
RUN apk update
RUN apk upgrade
RUN apk add --no-cache --virtual .build-deps

# Enable track_counts and autovacuum
RUN echo "autovacuum = on" >> /var/lib/postgresql/data/postgresql.conf
RUN echo "track_counts = on" >> /var/lib/postgresql/data/postgresql.conf

# Configure Postgres Conf
RUN echo "local all postgres ident" >> /var/lib/postgresql/data/pg_hba.conf

# Set timezone to UTC by default
RUN ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime

# Clean Up
RUN rm /var/cache/apk/*
RUN rm -rf /root/.cache /tmp/*

