slot deployments delete evolute-duel torii
slot deployments delete evolute-duel katana
slot deployments create -t insane evolute-duel katana --dev --dev.no-fee
sozo build --release --unity
sozo migrate --release
slot deployments create -t insane evolute-duel torii --config torii_config_release
sozo inspect --release
#slot deployments logs liyard-dojo-starter torii -f

