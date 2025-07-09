slot deployments delete dev-evolute-duel torii
slot deployments delete dev-evolute-duel katana
slot deployments create dev-evolute-duel --team evolute --tier pro katana --dev --dev.no-fee
sozo build --profile testing 
sozo migrate --profile testing
slot deployments create dev-evolute-duel --team evolute --tier pro torii --config torii_config_testing.toml --version v1.6.0-alpha.1
sozo inspect --profile testing
#slot deployments logs liyard-dojo-starter torii -f