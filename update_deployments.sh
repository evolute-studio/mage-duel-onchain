slot deployments delete evolute-duel torii
slot deployments delete evolute-duel katana
slot deployments create evolute-duel katana --dev --dev.no-fee
sozo build --release --unity
sozo --release migrate
slot deployments create evolute-duel torii --config torii_config
#slot deployments logs liyard-dojo-starter torii -f

