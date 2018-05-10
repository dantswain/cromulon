#!/bin/bash

# This script compiles, builds a release, and creates a docker image
# that runs the release.
#
# You can run this from scratch as long as you have docker installed. 
#
# After the initial build, you can pass the `--skip-setup` argument to this
# script to skip downloading deps, npm install, etc.  This option is useful
# once you have compiled the application once and need to compile in new
# changes.

cromulon_root=$(cd "$(dirname "$0")/.."; pwd)
usage="./scripts/build_docker_release.sh [--skip-setup]"

set -e

fullbuild=true

# argument handling
while test $# -gt 0
do
  case "$1" in
    --skip-setup) fullbuild=false
      ;;
    *)
      echo "invalid arguments"
      echo "Usage: ${usage}"
      exit 1
      ;;
  esac
  shift
done

# "full" build involves a complete clean and rebuild - this is necessary
#   if there is an existing native (non-Docker) build or if any dependencies
#   have changed
#
#  --skip-setup should be sufficient to pick up code changes after an existing
#    Docker build is in place
if [ "$fullbuild" == true ]; then
  echo "Elixir setup"
  docker-compose run --rm --no-deps -T elixir mix local.hex --force
  docker-compose run --rm --no-deps -T elixir mix local.rebar --force

  # note this has to happen before npm install because some of the
  # node modules come from the deps directory
  echo "Compile Cledos"
  mkdir -p priv/repo/migrations
  docker-compose run --rm --no-deps -T elixir mix deps.get
  docker-compose run --rm --no-deps -T elixir mix compile

  #echo "npm install"  (no node modules yet)
  #docker-compose run --rm --no-deps -T node npm install
fi

#echo "brunch build"
#docker-compose run --rm --no-deps -T node node ./node_modules/brunch/bin/brunch build -p

echo "phoenix digest"
docker-compose run --rm --no-deps -e MIX_ENV=prod -T elixir mix phx.digest

echo "compile release"
docker-compose run --rm --no-deps -e MIX_ENV=prod -T elixir mix release --env=prod

echo "build image"
cd ${cromulon_root}/release_image

releases_dir=${cromulon_root}/docker_build/prod/rel/cromulon/releases
version=$(grep "release,.*cromulon" ${releases_dir}/RELEASES | grep -o "[0-9.]\+" | head -n 1)

echo "Detected cromulon version ${version}"
echo

# untar the release tarball into this directory so that docker can COPY it
release_tarball=${releases_dir}/${version}/cromulon.tar.gz
mkdir -p cromulon
tar zxf ${release_tarball} -C cromulon

# build the image
docker build . -t cromulon

# clean up the intermediate directory
rm -rf cromulon

echo
echo "Complete"
echo
