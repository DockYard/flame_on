defmodule FlameOn.SVGTest do
  use ExUnit.Case, async: true

  alias FlameOn.SVG

  describe "mfa_to_string/1" do
    test "formats Elixir module function" do
      result = SVG.mfa_to_string({Elixir.MyApp.MyModule, :my_function, 2})

      assert result == "MyApp.MyModule.my_function/2"
    end

    test "formats top-level Elixir module" do
      result = SVG.mfa_to_string({MyModule, :foo, 0})

      assert result == "MyModule.foo/0"
    end

    test "formats Erlang module function" do
      result = SVG.mfa_to_string({:timer, :sleep, 1})

      assert result == "timer.sleep/1"
    end

    test "formats nested Elixir module" do
      result = SVG.mfa_to_string({MyApp.Deeply.Nested.Module, :func, 3})

      assert result == "MyApp.Deeply.Nested.Module.func/3"
    end

    test "handles non-tuple functions" do
      result = SVG.mfa_to_string(:sleep)

      assert result == ":sleep"
    end

    test "handles arity 0" do
      result = SVG.mfa_to_string({MyModule, :no_args, 0})

      assert result == "MyModule.no_args/0"
    end

    test "handles large arity" do
      result = SVG.mfa_to_string({MyModule, :many_args, 10})

      assert result == "MyModule.many_args/10"
    end

    test "handles single word module" do
      result = SVG.mfa_to_string({String, :upcase, 1})

      assert result == "String.upcase/1"
    end

    test "handles erlang atoms as modules" do
      result = SVG.mfa_to_string({:lists, :reverse, 1})

      assert result == "lists.reverse/1"
    end
  end
end
