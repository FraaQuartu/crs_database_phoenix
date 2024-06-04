defmodule Waf.Repo do
  use Ecto.Repo,
    otp_app: :waf,
    adapter: Ecto.Adapters.Postgres
end
