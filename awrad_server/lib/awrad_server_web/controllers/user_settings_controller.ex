defmodule AwradServerWeb.UserSettingsController do
  use AwradServerWeb, :controller

  alias AwradServer.Accounts
  alias AwradServer.PracticeSettings
  alias AwradServer.PracticeSettings.AccountPracticePolicy
  alias AwradServerWeb.PublicUrls
  alias AwradServerWeb.UserAuth

  import AwradServerWeb.UserAuth, only: [require_sudo_mode: 2]

  plug :require_sudo_mode
  plug :assign_email_and_password_changesets

  def edit(conn, _params) do
    render(conn, :edit)
  end

  def update(conn, %{"action" => "update_email"} = params) do
    %{"user" => user_params} = params
    user = conn.assigns.current_scope.user

    case Accounts.change_user_email(user, user_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_user_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          user.email,
          &PublicUrls.web(~p"/users/settings/confirm-email/#{&1}")
        )

        conn
        |> put_flash(
          :info,
          "A link to confirm your email change has been sent to the new address."
        )
        |> redirect(to: ~p"/users/settings")

      changeset ->
        render(conn, :edit, email_changeset: %{changeset | action: :insert})
    end
  end

  def update(conn, %{"action" => "update_practice_policy"} = params) do
    policy_params = Map.get(params, "practice_policy", %{})

    case PracticeSettings.update_policy(conn.assigns.current_scope, policy_params) do
      {:ok, _policy} ->
        conn
        |> put_flash(:info, "Practice settings updated successfully.")
        |> redirect(to: ~p"/users/settings")

      {:error, changeset} ->
        render(conn, :edit,
          practice_policy_form:
            Phoenix.Component.to_form(%{changeset | action: :update}, as: "practice_policy")
        )
    end
  end

  def update(conn, %{"action" => "update_password"} = params) do
    %{"user" => user_params} = params
    user = conn.assigns.current_scope.user

    case Accounts.update_user_password(user, user_params) do
      {:ok, {user, _}} ->
        conn
        |> put_flash(:info, "Password updated successfully.")
        |> put_session(:user_return_to, ~p"/users/settings")
        |> UserAuth.log_in_user(user)

      {:error, changeset} ->
        render(conn, :edit, password_changeset: changeset)
    end
  end

  def confirm_email(conn, %{"token" => token}) do
    case Accounts.update_user_email(conn.assigns.current_scope.user, token) do
      {:ok, _user} ->
        conn
        |> put_flash(:info, "Email changed successfully.")
        |> redirect(to: ~p"/users/settings")

      {:error, _} ->
        conn
        |> put_flash(:error, "Email change link is invalid or it has expired.")
        |> redirect(to: ~p"/users/settings")
    end
  end

  defp assign_email_and_password_changesets(conn, _opts) do
    user = conn.assigns.current_scope.user
    policy = PracticeSettings.policy(conn.assigns.current_scope)

    conn
    |> assign(:email_changeset, Accounts.change_user_email(user))
    |> assign(:password_changeset, Accounts.change_user_password(user))
    |> assign(:password_setup_required, Accounts.password_setup_required?(user.email))
    |> assign(:practice_policy, policy)
    |> assign(
      :practice_policy_form,
      Phoenix.Component.to_form(PracticeSettings.policy_changeset(policy, %{}),
        as: "practice_policy"
      )
    )
    |> assign(:practice_day_resets, AccountPracticePolicy.day_resets())
    |> assign(:practice_calculation_methods, AccountPracticePolicy.calculation_methods())
    |> assign(:practice_madhabs, AccountPracticePolicy.madhabs())
  end
end
