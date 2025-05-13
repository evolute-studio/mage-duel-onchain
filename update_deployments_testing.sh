slot deployments delete prxgr4mmer-evolute-duel torii
slot deployments delete prxgr4mmer-evolute-duel katana
slot deployments create prxgr4mmer-evolute-duel katana --dev --dev.no-fee --version 1.2.2
sozo build --profile testing --unity
sozo migrate --profile testing
slot deployments create prxgr4mmer-evolute-duel torii --config torii_config_testing.toml --version 1.2.2
sozo inspect --profile testing
#slot deployments logs liyard-dojo-starter torii -f

