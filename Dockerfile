FROM crystallang/crystal:0.35.1

RUN apt-get update \
  && apt-get -y install \
  wget curl cmake libuv1-dev libssl-dev \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

RUN curl -JL -o /tmp/cpp-driver-2.14.1.tar.gz 'https://github.com/datastax/cpp-driver/archive/2.14.1.tar.gz' && \
  tar xzvf cpp-driver-2.14.1.tar.gz && \
  cd cpp-driver-2.14.1 && \
  cmake . && make install && \
  cp /usr/local/lib/x86_64-linux-gnu/* /lib/x86_64-linux-gnu/
WORKDIR /app
