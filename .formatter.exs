# Used by "mix format"
[
  plugins: [Phoenix.LiveView.HTMLFormatter],
  import_deps: [:ecto],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{heex,ex,exs}"],
  line_length: 150
]
