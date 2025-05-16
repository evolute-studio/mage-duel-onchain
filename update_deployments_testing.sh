slot deployments delete liyard-evolute-duel torii
slot deployments delete liyard-evolute-duel katana
slot deployments create liyard-evolute-duel katana --dev --dev.no-fee --version 1.2.2
sozo build --profile testing --unity
sozo migrate --profile testing
slot deployments create liyard-evolute-duel torii --config torii_config_testing.toml --version 1.2.2
sozo inspect --profile testing
#slot deployments logs liyard-dojo-starter torii -f

