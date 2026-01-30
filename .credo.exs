%{
  configs: [
    %{
      name: "default",
      strict: true,
      color: true,
      files: %{
        included: [
          "lib/",
          "test/",
          "priv/repo/migrations/",
          "priv/repo/seeds.exs"
        ],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      checks: %{
        enabled: [
          # Readability
          {Credo.Check.Readability.ModuleDoc, []},
          {Credo.Check.Readability.MaxLineLength, [max_length: 98]},
          {Credo.Check.Readability.ParenthesesOnZeroArityDefs, []},
          {Credo.Check.Readability.PredicateFunctionNames, []},
          {Credo.Check.Readability.TrailingBlankLine, []},
          {Credo.Check.Readability.TrailingWhiteSpace, []},

          # Refactoring
          {Credo.Check.Refactor.CyclomaticComplexity, [max_complexity: 12]},
          {Credo.Check.Refactor.FunctionArity, [max_arity: 5]},
          {Credo.Check.Refactor.Nesting, [max_nesting: 3]},

          # Warnings
          {Credo.Check.Warning.BoolOperationOnSameValues, []},
          {Credo.Check.Warning.UnusedEnumOperation, []},
          {Credo.Check.Warning.UnusedKeywordOperation, []},
          {Credo.Check.Warning.UnusedListOperation, []},
          {Credo.Check.Warning.UnusedTupleOperation, []}
        ],
        disabled: [
          # Migrations n'ont pas besoin de @moduledoc
          {Credo.Check.Readability.ModuleDoc, files: %{excluded: [~r"/priv/repo/migrations/"]}},
          # Specs pas obligatoires pour MVP
          {Credo.Check.Readability.Specs, []}
        ]
      }
    }
  ]
}
