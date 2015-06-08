# DOCKER-VERSION 0.3.4
FROM        perl:latest
MAINTAINER  Peter Flanigan docker@roxsoft.co.uk

RUN apt-get update && apt-get install -yq dnsutils && apt-get clean && rm -rf /var/lib/apt/lists
RUN curl -L http://cpanmin.us | perl - App::cpanminus
RUN cpanm local::lib Carton

RUN cachebuster=b167545 git clone http://github.com/pjfl/p5-app-doh.git App-Doh
RUN cd App-Doh && carton install --deployment

EXPOSE 8080

WORKDIR App-Doh
CMD carton exec bin/doh-daemon --port 8080 start
