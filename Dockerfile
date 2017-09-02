FROM wiiaam/android-docker-scala

COPY . /sources/tox4j/

RUN apt-get update && apt-get -y install pkg-config python 

ENTRYPOINT ["/sources/tox4j/buildscripts/dockerscript.sh"]
