slot deployments delete evolute-duel-provable torii
slot deployments delete evolute-duel-provable katana
slot deployments create evolute-duel-provable katana --provable --version 1.2.2 --chain-id 0 --block-time 30000
sozo build --profile provable --unity
sozo --profile provable migrate
slot deployments create evolute-duel-provable torii --config torii_config
#slot deployments logs liyard-dojo-starter torii -f

