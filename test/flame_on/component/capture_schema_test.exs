defmodule FlameOn.Component.CaptureSchemaTest do
  use ExUnit.Case

  alias FlameOn.Component.CaptureSchema
  alias Ecto.Changeset

  setup do
    Code.ensure_loaded!(FlameOnTest.ExampleModule)
    :ok
  end

  describe "Elixir module" do
    @valid_attrs %{
      module: "Elixir.FlameOnTest.ExampleModule",
      function: "foo",
      arity: 0,
      timeout: 15_000
    }
    test "valid module passes" do
      assert %Changeset{valid?: true} = CaptureSchema.changeset(Node.self(), @valid_attrs)
    end

    test "valid module without `Elixir.` fails" do
      attrs = %{@valid_attrs | module: "FlameOnTest.ExampleModule"}

      assert %Changeset{valid?: false, errors: [module: {"Elixir modules must start with \"Elixir.\"", []}]} =
               CaptureSchema.changeset(Node.self(), attrs)
    end

    test "invalid module fails" do
      attrs = %{@valid_attrs | module: "Elixir.FlameOnTest.IncorrectExampleModule"}

      assert %Changeset{valid?: false, errors: [module: {"Module does not exist", []}]} =
               CaptureSchema.changeset(Node.self(), attrs)
    end

    test "invalid function fails" do
      attrs = %{@valid_attrs | function: "foobar"}

      assert %Changeset{
               valid?: false,
               errors: [function: {"No foobar/0 function on Elixir.FlameOnTest.ExampleModule", []}]
             } = CaptureSchema.changeset(Node.self(), attrs)
    end

    test "old code function passes" do
      :ok = :meck.new(FlameOnTest.ExampleModule, [:unstick, :passthrough])
      :ok = :meck.expect(FlameOnTest.ExampleModule, :foo, fn -> :meck.passthrough() end)

      true = :erlang.check_old_code(FlameOnTest.ExampleModule)

      assert %Changeset{valid?: true} = CaptureSchema.changeset(Node.self(), @valid_attrs)
    end
  end

  describe "Erlang module" do
    @valid_attrs %{
      module: "code",
      function: "stop",
      arity: 0,
      timeout: 15_000
    }
    test "valid module passes" do
      assert %Changeset{valid?: true} = CaptureSchema.changeset(Node.self(), @valid_attrs)
    end

    test "invalid module fails" do
      attrs = %{@valid_attrs | module: "no_code"}

      assert %Changeset{valid?: false, errors: [module: {"Module does not exist", []}]} =
               CaptureSchema.changeset(Node.self(), attrs)
    end

    test "invalid function fails" do
      attrs = %{@valid_attrs | function: "foobar"}

      assert %Changeset{
               valid?: false,
               errors: [function: {"No foobar/0 function on code", []}]
             } = CaptureSchema.changeset(Node.self(), attrs)
    end
  end
end
