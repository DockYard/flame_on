defmodule FlameOn.Format do
  @moduledoc """
  Utility functions for converting data to display as a string.
  """

  def mfa_to_string({m, f, a}) do
    m =
      case "#{m}" do
        "Elixir." <> rest -> rest
        other -> other
      end

    "#{m}.#{f}/#{a}"
  end

  def mfa_to_string(mfa) do
    inspect(mfa)
  end
end
