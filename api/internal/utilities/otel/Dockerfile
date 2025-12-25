FROM otel/opentelemetry-collector-contrib:latest

# Copy the config file
COPY config.yaml /etc/otelcol-contrib/config.yaml

# Set environment variables
ENV GRAFANA_CLOUD_OTLP_ENDPOINT=${GRAFANA_CLOUD_OTLP_ENDPOINT}
ENV GRAFANA_CLOUD_INSTANCE_ID=${GRAFANA_CLOUD_INSTANCE_ID}
ENV GRAFANA_CLOUD_API_KEY=${GRAFANA_CLOUD_API_KEY}

# Expose ports
EXPOSE 4317 4318
