#!/bin/bash

RED_COLOR='\033[0;31m'
GREEN_COLOR='\033[0;32m'
NO_COLOR='\033[0m'

if [ "$RPC_URL" = "" ]; then echo -e "${RED_COLOR}- Missing RPC_URL env variable"; return 1; fi
if [ "$WALLET_ADDRESS" = "" ]; then echo -e "${RED_COLOR}- Missing WALLET_ADDRESS env variable"; return 1; fi
if [ "$PRIVATE_KEY" = "" ]; then echo -e "${RED_COLOR}- Missing PRIVATE_KEY env variable"; return 1; fi
if [ "$VERIFIER_URL" = "" ]; then echo -e "${RED_COLOR}- Missing VERIFIER_URL env variable"; return 1; fi

if [ "$WETH_ADDR" = "" ]; then echo -e "${RED_COLOR}- Missing WETH_ADDR env variable"; return 1; fi
if [ "$ROYALTY_ENGINE_ADDR" = "" ]; then echo -e "${RED_COLOR}- Missing ROYALTY_ENGINE_ADDR env variable"; return 1; fi
if [ "$ERC20_TRANSFER_HELPER_ADDR" = "" ]; then echo -e "${RED_COLOR}- Missing ERC20_TRANSFER_HELPER_ADDR env variable"; return 1; fi
if [ "$ERC721_TRANSFER_HELPER_ADDR" = "" ]; then echo -e "${RED_COLOR}- Missing ERC721_TRANSFER_HELPER_ADDR env variable"; return 1; fi
if [ "$FEE_SETTINGS_ADDR" = "" ]; then echo -e "${RED_COLOR}- Missing FEE_SETTINGS_ADDR env variable"; return 1; fi
if [ "$MODULE_MANAGER_ADDR" = "" ]; then echo -e "${RED_COLOR}- Missing MODULE_MANAGER_ADDR env variable"; return 1; fi

# ====

if [ "$ASK_CONTRACT_ADDR" = "" ]
then
  echo -e "${NO_COLOR}Deploy AsksV1_1..."
  ASK_CONTRACT_DEPLOY_OUTPUT=$(forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY AsksV1_1 \
    --constructor-args $ERC20_TRANSFER_HELPER_ADDR $ERC721_TRANSFER_HELPER_ADDR $ROYALTY_ENGINE_ADDR $FEE_SETTINGS_ADDR $WETH_ADDR \
    --verify --verifier sourcify --verifier-url $VERIFIER_URL)
  ASK_CONTRACT_ADDR=$(echo ${ASK_CONTRACT_DEPLOY_OUTPUT#*"Deployed to: "} | head -c 42)
  echo -e "${GREEN_COLOR}- deployed to: $ASK_CONTRACT_ADDR"

  if [[ $ASK_CONTRACT_DEPLOY_OUTPUT == *"Contract successfully verified"* ]]; then
    echo -e "${GREEN_COLOR}- verification result: success"
  else
    echo -e "${RED_COLOR}- fail to verify contract $ASK_CONTRACT_ADDR"
    echo "$ASK_CONTRACT_DEPLOY_OUTPUT"
  fi
else
  echo -e "${NO_COLOR}Skip deploying AsksV1_1. Contract address provided ($ASK_CONTRACT_ADDR)"
fi

# ====
declare -a CONTRACT_ADDRESSES=( $ASK_CONTRACT_ADDR )
declare -a CONTRACT_NAMES=( "AsksV1_1" )

CONTRACT_ADDRESS_LENGTH=${#CONTRACT_ADDRESSES[@]}
for i in $( seq 1 $CONTRACT_ADDRESS_LENGTH ); do
  echo -e "${NO_COLOR}Register module ${CONTRACT_NAMES[$i]}..."
  OUTPUT=$(cast send --rpc-url $RPC_URL --from $WALLET_ADDRESS --private-key $PRIVATE_KEY $MODULE_MANAGER_ADDR "registerModule(address)" ${CONTRACT_ADDRESSES[$i]})
  STATUS=$(echo "$OUTPUT" | grep 'status' | awk '{print $2}')
  if [ "$STATUS" = "1" ]; then
    TRANSACTION_HASH=$(echo "$OUTPUT" | grep -m 2 'transactionHash' | tail -n 1 | awk '{print $2}')
    echo -e "${GREEN_COLOR}- Register module ${CONTRACT_NAMES[$i]} success, tx hash: $TRANSACTION_HASH"
  else
    echo -e "${RED_COLOR}- Register module ${CONTRACT_NAMES[$i]} fail"
  fi
done
