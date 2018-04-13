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

## Functionality

This is very much a work in progress.  Some things to play with so far:

* Follow the directions below on initial setup
* Launch docker containers: `docker-compose up -d` (probably want to
  `docker-compose pull` if you don't have the images already).
* Launch the app with an iex shell: `iex -S mix phx.server`
* Crawl the attached sifi database: `> Cromulon.Discovery.Postgres.crawl_database("postgres://postgres@localhost:5433/simplifi-test")`
* Open the neo4j browser: http://localhost:7474/ and explore the graph.
    - Show a subset of all nodes: `MATCH (n) RETURN n`
    - Show all tables and the database: `MATCH (n) WHERE n:Table OR n:Database RETURN n`
    - Show columns with the same name in multiple tables:
        ```
        MATCH (:Table)-[r]-(c:Column)
        WITH c, count(r) as rel_count
        WHERE rel_count > 1
        MATCH (t:Table)-[]-(c:Column)
        return t,c
        ```

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
