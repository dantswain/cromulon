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

    resources("/sources", SourceController, param: "source_uuid", except: [:delete])
    resources("/nodes", NodeController, param: "node_uuid", only: [:show])
    resources("/samples", SampleController, param: "node_uuid", only: [:show])
  end

  # Other scopes may use custom stacks.
  # scope "/api", CromulonWeb do
  #   pipe_through :api
  # end
end
