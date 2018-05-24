defmodule CromulonWeb.Router do
  use CromulonWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", CromulonWeb do
    # Use the default browser stack
    pipe_through(:browser)

    get("/", PageController, :index)

    # HACK should use a real resource controller
    post("/database", PageController, :new_database)
    get("/database", PageController, :database)
    get("/database/:database_id", PageController, :database)
    get("/table/:table_id", PageController, :table)
  end

  # Other scopes may use custom stacks.
  # scope "/api", CromulonWeb do
  #   pipe_through :api
  # end
end
