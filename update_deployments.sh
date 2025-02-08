slot deployments delete evolute-territory-wars torii
slot deployments delete evolute-territory-wars katana
slot deployments create evolute-territory-wars katana --dev --dev.no-fee
sozo build
sozo --release migrate
slot deployments create evolute-territory-wars torii --config torii_config
#slot deployments logs liyard-dojo-starter torii -f

