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
    module =
      changeset
      |> get_field(:module)
      |> maybe_prepend_elixir()
      |> rpc_to_existing_atom(node)

    if is_nil(module) or !rpc_code_ensure_loaded?(module, node) do
      add_error(changeset, :module, "Module not found")
    else
      changeset
    end
  end

  @doc """
  Since we support both Elixir and Erlang modules, and are taking a string argument, modules have to be
  converted to the Erlang notation before being passed to various checks and to :meck. This means an Elixir module like
  Phoenix.LiveView would have to be converted to the atom :"Elixir.Phoenix.LiveView", but cowboy_handler remains
  :cowboy_handler. If they already prepended `Elixir.` then we pass the module as is.
  """
  def maybe_prepend_elixir(""), do: ""
  def maybe_prepend_elixir("Elixir." <> _ = module_str), do: module_str

  def maybe_prepend_elixir(module_str) do
    first = String.at(module_str, 0)

    if String.upcase(first) == first do
      "Elixir." <> module_str
    else
      module_str
    end
  end

  defp validate_function_arity(%Changeset{valid?: false} = changeset, _node), do: changeset

  defp validate_function_arity(changeset, node) do
    module = changeset |> get_field(:module) |> maybe_prepend_elixir() |> String.to_existing_atom()

    function_str = get_field(changeset, :function)
    arity = get_field(changeset, :arity)

    function = rpc_to_existing_atom(function_str, node)

    if is_nil(function) or not rpc_function_exported?(module, function, arity, node) do
      add_error(changeset, :function, "No #{function_str}/#{arity} function on #{module}")
    else
      changeset
    end
  end

  defp rpc_to_existing_atom(string, node) do
    case :rpc.call(node, String, :to_existing_atom, [string]) do
      atom when is_atom(atom) -> atom
      {:badrpc, {:EXIT, {:badarg, _}}} -> nil
    end
  end

  defp rpc_code_ensure_loaded?(module, node) do
    :rpc.call(node, Code, :ensure_loaded?, [module])
  end

  defp rpc_function_exported?(module, function, arity, node) do
    :rpc.call(node, Kernel, :function_exported?, [module, function, arity])
  end
end
