defmodule AppTemplateWeb.UserController do
  use AppTemplateWeb, :controller
  alias AppTemplate.{Auth, EmailBuilder, Mailer, User, Users}

  def new(conn, _params) do
    changeset = User.changeset(%User{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"user" => user}) do
    case Users.create_user(user) do
      {:ok, user} ->
        user
        |> EmailBuilder.welcome_email()
        |> Mailer.deliver_later()

        conn
        |> put_flash(:info, gettext("Registration successful!"))
        |> Auth.new_session(user)
        |> redirect(to: Routes.page_path(conn, :index))

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_flash(:error, gettext("Please fix the errors below."))
        |> render("new.html", changeset: changeset)
    end
  end
end
