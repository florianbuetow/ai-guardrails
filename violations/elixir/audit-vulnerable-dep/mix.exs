defmodule TestOtpApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :test_otp_app,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [
        threshold: 80,
        ignore_modules: [
          Credo.Check.Custom.NoDefaultParameterValues,
          Credo.Check.Custom.NoFallbackOperator,
          Credo.Check.Custom.NoMapGetDefault,
          Credo.Check.Custom.NoDialyzerSuppress
        ]
      ],
      dialyzer: [
        plt_add_apps: [:mix, :ex_unit, :credo],
        flags: [:error_handling, :underspecs, :unmatched_returns]
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.13", only: [:dev, :test], runtime: false},
      {:plug, "~> 1.7.0"},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:ex_arch_unit, "~> 0.1.0", only: [:dev, :test], runtime: false},
      {:git_hooks, "~> 0.8", only: [:dev], runtime: false}
    ]
  end
end
