# Cromulon

![Show me what you got](https://ih0.redbubble.net/image.331723047.6376/flat,800x800,070,f.jpg)

This is a playground repo for building a data portal.

## Initial setup

You should have Elixir >= 1.6 with OTP >= 20.

Standard Phoenix workflow applies here:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.create && mix ecto.migrate`
  * Install Node.js dependencies with `cd assets && npm install`
  * Compile with `mix compile`

You can run the application tests by running

```
mix test
```

**CAUTION** The tests currently delete everything from the graph database.

## Functionality

This is very much a work in progress.  You can launch the app by running

```
iex -S mix phx.server
```

Then open your browser to http://localhost:4000 and enter the URI of a database
to crawl - for example `postgres://postgres@localhost/simplifi-development`.
After a minute or so, refreshing the page should show your database.

## Deployment to K8s

This assumes you have set up access to the dev k8s and set yourself into
whatever namespace you want to use.

```
kubectl -f k8s/neo4j-deployment.yml
kubectl -f k8s/neo4j-service.yml
```

Then run `kubectl get services` to find the port that neo4j is exposed on
and update the port in `k8s/cromulon-deployment.yml` (this step may not be
necessary if we get some DNS issues worked out).  Then

```
kubectl -f k8s/cromulon-deployment.yml
kubectl -f k8s/cromulon-service.yml
```

Run `kubectl get services` again to find the port that cromulon is exposed on.
It should be accessible via `http://dal10kubewdev1.int.simpli.fi:<port>/`.

A new version of the image can be built using
`./scripts/build_docker_image.sh`.

## Graph model

This is very much up in flux.  Currently there are three types of nodes:

1. Database - With `name` and `url` properties
2. Table - With `name` property
3. Column - With `name` and `data_type` properties

## Original Phoenix-generated README below

To start your Phoenix server:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.create && mix ecto.migrate`
  * Install Node.js dependencies with `cd assets && npm install`
  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](http://www.phoenixframework.org/docs/deployment).

## Learn more

  * Official website: http://www.phoenixframework.org/
  * Guides: http://phoenixframework.org/docs/overview
  * Docs: https://hexdocs.pm/phoenix
  * Mailing list: http://groups.google.com/group/phoenix-talk
  * Source: https://github.com/phoenixframework/phoenix
