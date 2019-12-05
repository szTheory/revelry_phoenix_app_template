defmodule AppTemplateWeb.Router do
  use AppTemplateWeb, :router
  use Pow.Phoenix.Router
  use Plug.ErrorHandler
  alias AppTemplateWeb.{RequireAdmin, LoadUser}

  defp handle_errors(conn, error_data) do
    AppTemplateWeb.ErrorReporter.handle_errors(conn, error_data)
  end

  if Mix.env() == :dev do
    forward "/sent_emails", Bamboo.SentEmailViewerPlug
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug LoadUser, otp_app: :my_app
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug LoadUser, otp_app: :my_app
  end

  pipeline :require_admin do
    plug RequireAdmin
  end

  pipeline :protected do
    plug Pow.Plug.RequireAuthenticated,
      error_handler: Pow.Phoenix.PlugErrorHandler
  end

  pipeline :anonymous do
    plug Pow.Plug.RequireNotAuthenticated, error_handler: Pow.Phoenix.PlugErrorHandler
  end

  scope "/" do
    pipe_through :browser

    pow_routes()
  end

  scope "/", AppTemplateWeb do
    # Use the default browser stack
    pipe_through [:browser]
    get "/", PageController, :index
    get "/styleguide", PageController, :styleguide
    get "/email/verify", EmailVerificationController, :verify
  end

  scope "/admin" do
    pipe_through [:browser, :protected, :require_admin]

    forward("/", Adminable.Plug,
      otp_app: :app_template,
      repo: AppTemplate.Repo,
      schemas: [AppTemplate.User],
      layout: {AppTemplateWeb.LayoutView, "app.html"}
    )
  end

  scope "/images" do
    pipe_through([:browser, :protected])

    forward("/sign", Transmit,
      signer: Transmit.S3Signer,
      bucket: "app-template",
      path: "uploads"
    )
  end

  scope "/api", AppTemplateWeb.API, as: :api do
    pipe_through [:browser, :anonymous]

    post("/authenticate", AuthenticationController, :authenticate)
  end

  scope "/api", AppTemplateWeb.API, as: :api do
    pipe_through [:browser, :protected]
  end
end
