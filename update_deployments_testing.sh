project=dev-evolute-duel
skip_deployments=false
tier=pro

# Print help message
print_help() {
  echo "Usage: $0 [OPTIONS]"
  echo "\nOptions:"
  echo "  --project NAME, -p NAME         Set project name (default: dev-evolute-duel)"
  echo "  --tier TIER, -t TIER            Set deployment tier: basic or pro (default: pro)"
  echo "  --skip-deployments, -sd          Skip deleting and creating deployments"
  echo "  --help, -h                      Show this help message and exit"
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --project)
      project="$2"
      shift 2
      ;;
    -p)
      project="$2"
      shift 2
      ;;
    --tier)
      tier="$2"
      shift 2
      ;;
    -t)
      tier="$2"
      shift 2
      ;;
    --skip-deployments)
      skip_deployments=true
      shift
      ;;
    -sd)
      skip_deployments=true
      shift
      ;;
    --help|-h)
      print_help
      exit 0
      ;;
    *)
      shift
      ;;
  esac
done

if [[ "$tier" != "pro" && "$tier" != "basic" ]]; then
  echo "Error: --tier/-t must be either 'basic' or 'pro'" >&2
  exit 1
fi

if [ "$skip_deployments" = false ]; then
  slot deployments delete "$project" torii
  slot deployments delete "$project" katana
  slot deployments create "$project" --team evolute --tier "$tier" katana --dev --dev.no-fee
fi
sozo build --profile testing 
sozo migrate --profile testing
if [ "$skip_deployments" = false ]; then
  slot deployments create "$project" --team evolute --tier "$tier" torii --config torii_config_testing.toml #--version v1.6.0-alpha.1
fi
sozo inspect --profile testing
#slot deployments logs liyard-dojo-starter torii -f
