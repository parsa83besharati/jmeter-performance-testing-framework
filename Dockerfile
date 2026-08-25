FROM openjdk:17-jre-slim

LABEL maintainer="Parsa Besharati"
LABEL description="JMeter performance testing framework"
LABEL version="1.0.0"
LABEL org.opencontainers.image.source="https://github.com/pouya-besharati/jmeter-performance-testing-framework"

ENV JMETER_VERSION=5.6.3
ENV JMETER_HOME=/opt/apache-jmeter
ENV PATH="${JMETER_HOME}/bin:${PATH}"

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        wget \
        unzip \
        curl \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q "https://dlcdn.apache.org//jmeter/binaries/apache-jmeter-${JMETER_VERSION}.tgz" -O /tmp/jmeter.tgz \
    && tar -xzf /tmp/jmeter.tgz -C /opt/ \
    && mv /opt/apache-jmeter-${JMETER_VERSION} ${JMETER_HOME} \
    && rm /tmp/jmeter.tgz \
    && chmod +x ${JMETER_HOME}/bin/*.sh

WORKDIR /jmeter

COPY jmeter/ /jmeter/jmeter/
COPY scripts/ /jmeter/scripts/

RUN chmod +x /jmeter/scripts/*.sh

EXPOSE 1099 4000 4001

ENTRYPOINT ["/jmeter/scripts/docker-run.sh"]
