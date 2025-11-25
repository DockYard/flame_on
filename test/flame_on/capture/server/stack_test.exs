defmodule FlameOn.Capture.Server.StackTest do
  use ExUnit.Case, async: true

  alias FlameOn.Capture.Block
  alias FlameOn.Capture.Server.Stack
  alias FlameOn.Fixtures

  describe "handle_trace_call/3" do
    test "adds a new block to the stack" do
      stack = []
      function = {:example, :foo, 0}
      timestamp = 1000

      result = Stack.handle_trace_call(stack, function, timestamp)

      assert [%Block{} = block] = result
      assert block.function == function
      assert block.absolute_start == timestamp
      assert block.level == 0
      assert block.children == []
      assert is_binary(block.id)
    end

    test "adds block to existing stack" do
      parent = Fixtures.simple_block(function: {:example, :parent, 0})
      stack = [parent]
      function = {:example, :child, 0}
      timestamp = 2000

      result = Stack.handle_trace_call(stack, function, timestamp)

      assert [%Block{} = child_block, ^parent] = result
      assert child_block.function == function
      assert child_block.absolute_start == timestamp
      assert child_block.level == 1
    end

    test "generates unique IDs for each block" do
      stack = []
      function = {:example, :foo, 0}

      stack1 = Stack.handle_trace_call(stack, function, 1000)
      stack2 = Stack.handle_trace_call(stack, function, 1000)

      [block1] = stack1
      [block2] = stack2

      assert block1.id != block2.id
    end
  end

  describe "handle_trace_return_to/3" do
    test "pops a block from the stack and attaches it to parent" do
      stack =
        Fixtures.build_stack_from_trace_events([
          {:call, {:example, :parent, 0}, 1000},
          {:call, {:example, :child, 0}, 1100}
        ])

      result = Stack.handle_trace_return_to(stack, {:example, :parent, 0}, 1200)

      assert [%Block{function: {:example, :parent, 0}} = parent] = result
      assert [%Block{function: {:example, :child, 0}} = child] = parent.children
      assert child.duration == 100
      assert child.absolute_start == 1100
    end

    test "reverses children when popping" do
      stack =
        Fixtures.build_stack_from_trace_events([
          {:call, {:example, :parent, 0}, 1000},
          {:call, {:example, :child1, 0}, 1100},
          {:return_to, {:example, :parent, 0}, 1200},
          {:call, {:example, :child2, 0}, 1300}
        ])

      result = Stack.handle_trace_return_to(stack, {:example, :parent, 0}, 1400)

      assert [%Block{function: {:example, :parent, 0}} = parent] = result
      assert [child2, child1] = parent.children
      assert child1.function == {:example, :child1, 0}
      assert child2.function == {:example, :child2, 0}
    end

    test "handles sleep/sleep return pattern" do
      stack =
        Fixtures.build_stack_from_trace_events([
          {:call, {:example, :foo, 0}, 1000},
          {:call, :sleep, 1100}
        ])

      result = Stack.handle_trace_return_to(stack, :sleep, 1200)

      assert [%Block{function: {:example, :foo, 0}} = parent] = result
      assert [%Block{function: :sleep} = sleep_block] = parent.children
      assert sleep_block.duration == 100
    end

    test "handles returning to starter block" do
      stack =
        Fixtures.build_stack_from_trace_events([
          {:call, {:example, :starter, 0}, 1000},
          {:call, {:example, :child, 0}, 1100}
        ])

      result = Stack.handle_trace_return_to(stack, {:example, :different, 0}, 1200)

      assert [%Block{function: {:example, :starter, 0}}] = result
    end

    test "handles tail recursion with pruning" do
      stack =
        Fixtures.build_stack_from_trace_events([
          {:call, {:example, :recursive, 1}, 1000},
          {:call, {:example, :recursive, 1}, 1100},
          {:call, {:example, :recursive, 1}, 1200}
        ])

      result = Stack.handle_trace_return_to(stack, {:example, :recursive, 1}, 1300)

      assert length(result) == 2
      [second, first] = result
      assert first.function == {:example, :recursive, 1}
      assert second.function == {:example, :recursive, 1}
      assert [%Block{function: {:example, :recursive, 1}}] = second.children
    end
  end

  describe "finalize_stack/1" do
    test "finalizes a single root block with children" do
      stack =
        Fixtures.build_stack_from_trace_events([
          {:call, {:example, :root, 0}, 1000},
          {:call, {:example, :child1, 0}, 1100},
          {:return_to, {:example, :root, 0}, 1200},
          {:call, {:example, :child2, 0}, 1300},
          {:return_to, {:example, :root, 0}, 1400}
        ])

      [root] = Stack.finalize_stack(stack)

      assert root.function == {:example, :root, 0}
      assert root.absolute_start == 1100
      assert root.duration == 300
      assert length(root.children) == 2
      assert root.level == 1
      assert root.max_child_level == 1
    end

    test "reverses children in final stack" do
      stack =
        Fixtures.build_stack_from_trace_events([
          {:call, {:example, :root, 0}, 1000},
          {:call, {:example, :child1, 0}, 1100},
          {:return_to, {:example, :root, 0}, 1200},
          {:call, {:example, :child2, 0}, 1300},
          {:return_to, {:example, :root, 0}, 1400}
        ])

      [root] = Stack.finalize_stack(stack)

      [first_child, second_child] = root.children
      assert first_child.function == {:example, :child1, 0}
      assert second_child.function == {:example, :child2, 0}
    end

    test "collapses leftover stack nodes to root" do
      stack =
        Fixtures.build_stack_from_trace_events([
          {:call, {:example, :root, 0}, 1000},
          {:call, {:example, :child, 0}, 1100}
        ])

      [root] = Stack.finalize_stack(stack)

      assert root.function == {:example, :root, 0}
      assert [child] = root.children
      assert child.function == {:example, :child, 0}
    end

    test "calculates correct duration from children" do
      stack =
        Fixtures.build_stack_from_trace_events([
          {:call, {:example, :root, 0}, 1000},
          {:call, {:example, :child1, 0}, 1100},
          {:return_to, {:example, :root, 0}, 1250},
          {:call, {:example, :child2, 0}, 1300},
          {:return_to, {:example, :root, 0}, 1500}
        ])

      [root] = Stack.finalize_stack(stack)

      assert root.absolute_start == 1100
      assert root.duration == 400
    end

    test "handles deeply nested blocks" do
      stack =
        Fixtures.build_stack_from_trace_events([
          {:call, {:example, :level1, 0}, 1000},
          {:call, {:example, :level2, 0}, 1100},
          {:call, {:example, :level3, 0}, 1200},
          {:return_to, {:example, :level2, 0}, 1300},
          {:return_to, {:example, :level1, 0}, 1400}
        ])

      [root] = Stack.finalize_stack(stack)

      assert root.level == 1
      assert root.max_child_level == 2

      [level2] = root.children
      assert level2.level == 2
      assert level2.max_child_level == 1

      [level3] = level2.children
      assert level3.level == 3
      assert level3.max_child_level == 0
    end

    test "handles block with single child" do
      child =
        Fixtures.simple_block(
          function: {:example, :child, 0},
          absolute_start: 1100,
          duration: 100,
          children: []
        )

      block =
        Fixtures.simple_block(
          function: {:example, :root, 0},
          absolute_start: 1000,
          duration: 200,
          children: [child]
        )

      [root] = Stack.finalize_stack([block])

      assert root.level == 1
      assert root.max_child_level == 1
      assert length(root.children) == 1
    end
  end

  describe "populate_levels" do
    test "assigns level 1 to root with child" do
      child =
        Fixtures.simple_block(
          function: {:example, :child, 0},
          absolute_start: 1100,
          duration: 100,
          children: []
        )

      block =
        Fixtures.simple_block(
          function: {:example, :root, 0},
          absolute_start: 1000,
          duration: 200,
          children: [child]
        )

      [result] = Stack.finalize_stack([block])

      assert result.level == 1
      assert result.max_child_level == 1
    end

    test "assigns incrementing levels to nested blocks" do
      stack =
        Fixtures.build_stack_from_trace_events([
          {:call, {:example, :parent, 0}, 1000},
          {:call, {:example, :child, 0}, 1100},
          {:return_to, {:example, :parent, 0}, 1200}
        ])

      [root] = Stack.finalize_stack(stack)

      assert root.level == 1
      [child] = root.children
      assert child.level == 2
    end

    test "calculates max_child_level correctly" do
      stack =
        Fixtures.build_stack_from_trace_events([
          {:call, {:example, :root, 0}, 1000},
          {:call, {:example, :child1, 0}, 1100},
          {:call, {:example, :grandchild, 0}, 1150},
          {:return_to, {:example, :child1, 0}, 1175},
          {:return_to, {:example, :root, 0}, 1200},
          {:call, {:example, :child2, 0}, 1300},
          {:return_to, {:example, :root, 0}, 1400}
        ])

      [root] = Stack.finalize_stack(stack)

      assert root.max_child_level == 2

      [child1, child2] = root.children
      assert child1.max_child_level == 1
      assert child2.max_child_level == 0
    end
  end

  describe "recursive call pruning" do
    test "prunes when returning to non-parent with recursive pattern" do
      stack =
        Fixtures.build_stack_from_trace_events([
          {:call, {:example, :base, 0}, 1000},
          {:call, {:example, :recursive, 1}, 1100},
          {:call, {:example, :recursive, 1}, 1200},
          {:call, {:example, :recursive, 1}, 1300}
        ])

      result = Stack.handle_trace_return_to(stack, {:example, :base, 0}, 1400)

      assert [%Block{function: {:example, :base, 0}} = base] = result
      assert [%Block{function: {:example, :recursive, 1}} = top_recursive] = base.children
      assert top_recursive.children == []
    end

    test "prunes multiple levels of recursion" do
      stack =
        Fixtures.build_stack_from_trace_events([
          {:call, {:example, :base, 0}, 1000},
          {:call, {:example, :recursive, 1}, 1100},
          {:call, {:example, :recursive, 1}, 1200},
          {:call, {:example, :recursive, 1}, 1300},
          {:call, {:example, :recursive, 1}, 1400}
        ])

      result = Stack.handle_trace_return_to(stack, {:example, :base, 0}, 1500)

      assert [%Block{function: {:example, :base, 0}} = base] = result
      assert [%Block{function: {:example, :recursive, 1}} = top_recursive] = base.children
      assert top_recursive.children == []
    end

    test "does not prune when child has different function" do
      child =
        Fixtures.simple_block(
          function: {:example, :different, 0},
          absolute_start: 1100,
          duration: 100,
          children: []
        )

      parent =
        Fixtures.simple_block(
          function: {:example, :recursive, 1},
          absolute_start: 1000,
          children: [child]
        )

      other_block =
        Fixtures.simple_block(
          function: {:example, :base, 0},
          absolute_start: 900
        )

      stack = [parent, other_block]

      result = Stack.handle_trace_return_to(stack, {:example, :base, 0}, 1300)

      assert [%Block{function: {:example, :base, 0}} = base] = result
      assert [%Block{function: {:example, :recursive, 1}} = recursive] = base.children
      assert [%Block{function: {:example, :different, 0}}] = recursive.children
    end

    test "does not prune when parent has multiple children" do
      child1 =
        Fixtures.simple_block(
          function: {:example, :recursive, 1},
          absolute_start: 1100,
          duration: 50,
          children: []
        )

      child2 =
        Fixtures.simple_block(
          function: {:example, :other, 0},
          absolute_start: 1200,
          duration: 50,
          children: []
        )

      parent =
        Fixtures.simple_block(
          function: {:example, :recursive, 1},
          absolute_start: 1000,
          children: [child1, child2]
        )

      base =
        Fixtures.simple_block(
          function: {:example, :base, 0},
          absolute_start: 900
        )

      stack = [parent, base]

      result = Stack.handle_trace_return_to(stack, {:example, :base, 0}, 1300)

      assert [%Block{function: {:example, :base, 0}} = base_result] = result
      assert [%Block{function: {:example, :recursive, 1}} = recursive] = base_result.children
      assert length(recursive.children) == 2
    end
  end

  describe "edge cases" do
    test "handles single call/return pair" do
      stack =
        Fixtures.build_stack_from_trace_events([
          {:call, {:example, :root, 0}, 1000},
          {:call, {:example, :foo, 0}, 1500}
        ])

      result = Stack.handle_trace_return_to(stack, {:example, :root, 0}, 2000)
      [root] = Stack.finalize_stack(result)

      assert root.function == {:example, :root, 0}
      [child] = root.children
      assert child.function == {:example, :foo, 0}
      assert child.duration == 500
    end

    test "handles zero duration blocks" do
      stack =
        Fixtures.build_stack_from_trace_events([
          {:call, {:example, :parent, 0}, 1000},
          {:call, {:example, :child, 0}, 1000},
          {:return_to, {:example, :parent, 0}, 1000}
        ])

      [root] = Stack.finalize_stack(stack)

      [child] = root.children
      assert child.duration == 0
    end

    test "handles erlang module functions" do
      stack =
        Fixtures.build_stack_from_trace_events([
          {:call, {:example, :root, 0}, 1000},
          {:call, {:timer, :sleep, 1}, 1500}
        ])

      result = Stack.handle_trace_return_to(stack, {:example, :root, 0}, 2000)
      [root] = Stack.finalize_stack(result)

      assert root.function == {:example, :root, 0}
      [child] = root.children
      assert child.function == {:timer, :sleep, 1}
    end

    test "handles complex call patterns" do
      events = [
        {:call, {:example, :root, 0}, 1000},
        {:call, {:example, :child1, 0}, 1100},
        {:call, {:example, :grandchild1, 0}, 1150},
        {:return_to, {:example, :child1, 0}, 1200},
        {:return_to, {:example, :root, 0}, 1250},
        {:call, {:example, :child2, 0}, 1300},
        {:call, {:example, :grandchild2, 0}, 1350},
        {:return_to, {:example, :child2, 0}, 1400},
        {:return_to, {:example, :root, 0}, 1450}
      ]

      stack = Fixtures.build_stack_from_trace_events(events)
      [root] = Stack.finalize_stack(stack)

      assert root.function == {:example, :root, 0}
      assert length(root.children) == 2

      [child1, child2] = root.children
      assert length(child1.children) == 1
      assert length(child2.children) == 1
    end
  end
end
