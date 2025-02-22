slot deployments delete liyard-evolute-duel torii
slot deployments delete liyard-evolute-duel katana
slot deployments create liyard-evolute-duel katana --dev --dev.no-fee
sozo build --release --unity
sozo --release migrate
slot deployments create liyard-evolute-duel torii --config torii_config
#slot deployments logs liyard-dojo-starter torii -f

