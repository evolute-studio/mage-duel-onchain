slot deployments delete evolute-duel torii
slot deployments delete evolute-duel katana
slot deployments create evolute-duel katana --dev --dev.no-fee --version 1.2.2
sozo build --release --unity
sozo migrate --release
slot deployments create evolute-duel torii --config torii_config_release.toml --version 1.2.2
sozo inspect --release
#slot deployments logs liyard-dojo-starter torii -f

