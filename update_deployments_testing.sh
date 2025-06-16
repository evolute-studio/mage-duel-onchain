slot deployments delete dev-evolute-duel torii
slot deployments delete dev-evolute-duel katana
slot deployments create dev-evolute-duel katana --dev --dev.no-fee
sozo build --profile testing 
sozo migrate --profile testing
slot deployments create dev-evolute-duel torii --config torii_config_testing.toml #--version 1.5.4-preview.0 
sozo inspect --profile testing
#slot deployments logs liyard-dojo-starter torii -f

