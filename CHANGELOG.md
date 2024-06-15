# Changelog

## Next

- Add "Download graph as SVG" feature
- `Phoenix.HTML` 4.0
- Bandit.Pipeline.run as default MFA when available (it's now the default in `mix phx_new`)
- Fix issue with changeset form not honoring initial node
- Elixir 1.16 in CI
- Increase formatter line length
- Mitigate race condition in trace_started? function.

## 0.6.0

- Upgrade Dialyxir
- Upgrade Build/CI targets to Elixir 1.15 & OTP 26
- Upgrade LiveDashboard to v0.8.2
- Upgrade LiveView to v0.20
- Rework module form validation to be more reliable
- Don't require `Elixir.` prefix on Elixir modules
- Rework trace_started? to not rely on Trace GenServer
- Run module/function validations on selected node (thanks @schrockwell)
- Upgrade LiveView to v0.18

## 0.5.2

- Improve performance by not rendering blocks smaller than 0.1% of the top block width (Thanks @schrockwell)

## 0.5.1

- Support tracing functions with greater than 4 arity (Thanks @schrockwell)

## 0.5.0

- Rewrite underlying tracing/capture engine

## 0.4.0

- Allow targeting a node to run on, and honor dashboard node switcher
- Add commas to integers in tooltips for readability

## 0.3.0

- Upgrade eFlambe to 0.2.3 to resolve graph truncation and :not_mocked error
