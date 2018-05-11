# Builds a docker image that can run cromulon
#
# This is basically just a debian base image (that is what the erlang/elixir
# images use) with libssl installed.  There is no erlang/elixir runtime
# installed ahead of time because that is already packaged into the release
# tarball.
#
# Note we create an empty servers.json file so that the code can see that it
# is there.  We are not actually going to be running rsyncs from here, so
# an empty file suffices.  You could always mount a real servers.json file
# as a volume when you run the image and set the SERVERS_JSON_PATH env var
# accordingly.

FROM buildpack-deps:stretch-curl

RUN apt-get update \
  && apt-get install -y --no-install-recommends libssl1.0.2 \
  && rm -rf /var/lib/apt/lists/

COPY cromulon /cromulon

ENV REPLACE_OS_VARS true
ENV PORT 4000
ENV NODE_HOST 127.0.0.1
ENV NEO4J_URL bolt://neo4j:7687

EXPOSE 4000
EXPOSE 4369

CMD ["/cromulon/bin/cromulon", "foreground"]
