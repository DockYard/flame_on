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

  def changeset(node, attrs \\ @default_attrs) do
    %__MODULE__{}
    |> cast(attrs, [:module, :function, :arity, :timeout])
    |> validate_required([:module, :function, :arity, :timeout])
    |> validate_module(node)
    |> validate_function_arity(node)
  end

  defp validate_module(%Changeset{valid?: false} = changeset, _node), do: changeset

  defp validate_module(changeset, node) do
    module_str = get_field(changeset, :module)

    module = rpc_to_existing_atom(node, module_str)

    if is_nil(module) or
         not (rpc_function_exported?(node, module, :__info__, 1) or
                rpc_check_old_code(node, module) or
                rpc_module_loaded(node, module)) do
      if String.contains?(module_str, ".") and !String.starts_with?(module_str, "Elixir.") do
        add_error(changeset, :module, "Elixir modules must start with \"Elixir.\"")
      else
        add_error(changeset, :module, "Module does not exist")
      end
    else
      changeset
    end
  end

  defp validate_function_arity(%Changeset{valid?: false} = changeset, _node), do: changeset

  defp validate_function_arity(changeset, node) do
    module = changeset |> get_field(:module) |> String.to_existing_atom()
    function_str = get_field(changeset, :function)
    arity = get_field(changeset, :arity)

    function = rpc_to_existing_atom(node, function_str)

    if !is_nil(function) and rpc_check_old_code(node, module) do
      Code.ensure_loaded(module)
    end

    if is_nil(function) or not rpc_function_exported?(node, module, function, arity) do
      add_error(changeset, :function, "No #{function_str}/#{arity} function on #{module}")
    else
      changeset
    end
  end

  defp rpc_to_existing_atom(node, string) do
    case :rpc.call(node, String, :to_existing_atom, [string]) do
      atom when is_atom(atom) -> atom
      {:badrpc, {:EXIT, {:badarg, _}}} -> nil
    end
  end

  defp rpc_function_exported?(node, module, function, arity) do
    :rpc.call(node, Kernel, :function_exported?, [module, function, arity])
  end

  defp rpc_check_old_code(node, module) do
    :rpc.call(node, :erlang, :check_old_code, [module])
  end

  defp rpc_module_loaded(node, module) do
    :rpc.call(node, :erlang, :module_loaded, [module])
  end
end
