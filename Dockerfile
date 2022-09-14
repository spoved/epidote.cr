FROM crystallang/crystal:1.4.1-build

RUN rm /etc/apt/sources.list.d/crystal.list
RUN apt-get update \
  && apt-get -y install \
  wget curl cmake libuv1-dev libssl-dev \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

RUN curl -JL -o /tmp/cpp-driver-2.14.1.tar.gz 'https://github.com/datastax/cpp-driver/archive/2.14.1.tar.gz' && \
  tar xzvf cpp-driver-2.14.1.tar.gz && \
  cd cpp-driver-2.14.1 && \
  cmake . && make install && \
  cp -r /usr/local/lib/x86_64-linux-gnu/* /lib/x86_64-linux-gnu/
WORKDIR /app
