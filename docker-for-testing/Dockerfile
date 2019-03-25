FROM ioft/i386-ubuntu:trusty

ENV FIONA_VERSION 7.0.1

RUN mkdir /fiona
WORKDIR /fiona

RUN apt-get update && apt-get install -y --no-install-recommends \
  ca-certificates \
  libmysqlclient18 \
  unzip

COPY /Infopark-CMS-Fiona-${FIONA_VERSION}-Linux.zip /tmp
RUN unzip /tmp/Infopark-CMS-Fiona-${FIONA_VERSION}-Linux.zip -d /tmp && \
  unzip /tmp/Infopark-CMS-Fiona-${FIONA_VERSION}-Linux/data.zip -d /fiona && \
  rm -f /tmp/Infopark-CMS-Fiona-${FIONA_VERSION}-Linux.zip && \
  rm -rf /tmp/Infopark-CMS-Fiona-${FIONA_VERSION}-Linux

CMD ["/bin/bash"]
ENTRYPOINT ["linux32", "--"]
