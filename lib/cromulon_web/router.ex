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
    get("/sources/:source_uuid", PageController, :source)
    get("/nodes/:node_uuid", PageController, :node)
  end

  # Other scopes may use custom stacks.
  # scope "/api", CromulonWeb do
  #   pipe_through :api
  # end
end
