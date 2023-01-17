defmodule FlameOn.Component.CaptureSchema do
  use Ecto.Schema
  import Ecto.Changeset
  alias Ecto.Changeset

  schema "capture" do
    field :module, :string
    field :function, :string
    field :arity, :integer
    field :timeout, :integer
  end

  @default_attrs %{module: "cowboy_handler", function: "execute", arity: 2, timeout: 15000}

  def changeset(attrs \\ @default_attrs) do
    %__MODULE__{}
    |> cast(attrs, [:module, :function, :arity, :timeout])
    |> validate_required([:module, :function, :arity, :timeout])
    |> validate_module()
    |> validate_function_arity()
  end

  defp validate_module(%Changeset{valid?: false} = changeset), do: changeset

  defp validate_module(changeset) do
    module_str = get_field(changeset, :module)

    module =
      try do
        String.to_existing_atom(module_str)
      rescue
        ArgumentError -> nil
      end

    if is_nil(module) or
         not (function_exported?(module, :__info__, 1) or :erlang.check_old_code(module) or
                :erlang.module_loaded(module)) do
      if String.contains?(module_str, ".") and !String.starts_with?(module_str, "Elixir.") do
        add_error(changeset, :module, "Elixir modules must start with \"Elixir.\"")
      else
        add_error(changeset, :module, "Module does not exist")
      end
    else
      changeset
    end
  end

  defp validate_function_arity(%Changeset{valid?: false} = changeset), do: changeset

  defp validate_function_arity(changeset) do
    module = changeset |> get_field(:module) |> String.to_existing_atom()
    function_str = get_field(changeset, :function)
    arity = get_field(changeset, :arity)

    function =
      try do
        String.to_existing_atom(function_str)
      rescue
        ArgumentError -> nil
      end

    if !is_nil(function) and :erlang.check_old_code(module) do
      Code.ensure_loaded(module)
    end

    if is_nil(function) or !function_exported?(module, function, arity) do
      add_error(changeset, :function, "No #{function_str}/#{arity} function on #{module}")
    else
      changeset
    end
  end
end
