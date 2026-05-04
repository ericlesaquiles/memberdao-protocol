#!/bin/bash
mkdir -p audit
CONTRACTS=("GovToken" "MemberPassNFT" "PriceConsumer" "StakingPool" "MemberDAO")

for CONTRACT in "${CONTRACTS[@]}"; do
  echo "Analisando $CONTRACT..."
  myth analyze contracts/$CONTRACT.sol \
    --solc-json mythril.config.json \
    --execution-timeout 300 \
    --max-depth 30 \
    -o markdown > audit/mythril-$CONTRACT.md
  echo "  → audit/mythril-$CONTRACT.md"
done

echo "Auditoria concluída!"