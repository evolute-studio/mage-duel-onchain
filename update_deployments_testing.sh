slot deployments delete liyard-evolute-duel torii
slot deployments delete liyard-evolute-duel katana
slot deployments create -t insane liyard-evolute-duel katana --dev --dev.no-fee
sozo build --profile testing --unity
sozo migrate --profile testing
slot deployments create -t insane liyard-evolute-duel torii --config torii_config_testing
sozo inspect --profile testing
#slot deployments logs liyard-dojo-starter torii -f

