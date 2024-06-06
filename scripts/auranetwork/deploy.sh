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

# ====

if [ "$FEE_SETTINGS_ADDR" = "" ]
then
  echo "Deploy ZoraProtocolFeeSettings..."
  FEE_SETTINGS_DEPLOY_OUTPUT=$(forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY ZoraProtocolFeeSettings \
    --verify --verifier sourcify --verifier-url $VERIFIER_URL)
  FEE_SETTINGS_ADDR=$(echo ${FEE_SETTINGS_DEPLOY_OUTPUT#*"Deployed to: "} | head -c 42)
  echo -e "${GREEN_COLOR}- deployed to: $FEE_SETTINGS_ADDR"

  if [[ $FEE_SETTINGS_DEPLOY_OUTPUT == *"Contract successfully verified"* ]]; then
    echo -e "${GREEN_COLOR}- verification result: success"
  else
    echo -e "${RED_COLOR}- fail to verify contract $FEE_SETTINGS_ADDR"
    echo "$FEE_SETTINGS_DEPLOY_OUTPUT"
  fi
else
  echo "Skip deploying ZoraProtocolFeeSettings. Contract address provided ($FEE_SETTINGS_ADDR)"
fi

# ====

if [ "$MODULE_MANAGER_ADDR" = "" ]
then
  echo -e "${NO_COLOR}Deploy ZoraModuleManager..."
  MODULE_MANAGER_DEPLOY_OUTPUT=$(forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY ZoraModuleManager \
      --constructor-args \
        $WALLET_ADDRESS `# _registrar` \
        $FEE_SETTINGS_ADDR \
    --verify --verifier sourcify --verifier-url $VERIFIER_URL)
  MODULE_MANAGER_ADDR=$(echo ${MODULE_MANAGER_DEPLOY_OUTPUT#*"Deployed to: "} | head -c 42)
  echo -e "${GREEN_COLOR}- deployed to: $MODULE_MANAGER_ADDR"

  if [[ $MODULE_MANAGER_DEPLOY_OUTPUT == *"Contract successfully verified"* ]]; then
    echo -e "${GREEN_COLOR}- verification result: success"
  else
    echo -e "${RED_COLOR}- fail to verify contract $MODULE_MANAGER_ADDR"
    echo "$MODULE_MANAGER_DEPLOY_OUTPUT"
  fi
else
  echo "Skip deploying ZoraModuleManager. Contract address provided ($MODULE_MANAGER_ADDR)"
fi

# ====

if [ "$FEE_PROTOCOL_INITIALIZE_TRANSACTION_HASH" = "" ]; then
  echo -e "${NO_COLOR}Initialize ZoraProtocolFeeSettings..."
  FEE_PROTOCOL_INITIALIZE_OUTPUT=$(cast send --rpc-url $RPC_URL --from $WALLET_ADDRESS --private-key $PRIVATE_KEY $FEE_SETTINGS_ADDR \
    "init(address,address)" \
      $MODULE_MANAGER_ADDR \
      "0x0000000000000000000000000000000000000000" `# metadata`)
  FEE_PROTOCOL_INITIALIZE_STATUS=$(echo "$FEE_PROTOCOL_INITIALIZE_OUTPUT" | grep 'status' | awk '{print $2}')
  if [ "$FEE_PROTOCOL_INITIALIZE_STATUS" = "1" ]
  then
    FEE_PROTOCOL_INITIALIZE_TRANSACTION_HASH=$(echo "$FEE_PROTOCOL_INITIALIZE_OUTPUT" | grep -m 2 'transactionHash' | tail -n 1 | awk '{print $2}')
    echo -e "${GREEN_COLOR}- ZoraProtocolFeeSettings initialize success, tx hash: ${FEE_PROTOCOL_INITIALIZE_TRANSACTION_HASH}"
  else
    echo -e "${RED_COLOR}- ZoraProtocolFeeSettings initialize fail"
  fi
else
  echo "${NO_COLOR}ZoraProtocolFeeSettings initialize skipped, prev tx hash: $FEE_PROTOCOL_INITIALIZE_TRANSACTION_HASH"
fi

# ====

if [ "$FEE_PROTOCOL_SET_OWNER_TRANSACTION_HASH" = "" ]; then
  echo -e "${NO_COLOR}Set owner for ZoraProtocolFeeSettings..."
  FEE_PROTOCOL_SET_OWNER_OUTPUT=$(cast send --rpc-url $RPC_URL --from $WALLET_ADDRESS --private-key $PRIVATE_KEY $FEE_SETTINGS_ADDR \
    "setOwner(address)" $WALLET_ADDRESS `# FEE_SETTINGS_OWNER`)
  FEE_PROTOCOL_SET_OWNER_STATUS=$(echo "$FEE_PROTOCOL_SET_OWNER_OUTPUT" | grep 'status' | awk '{print $2}')
  if [ "$FEE_PROTOCOL_SET_OWNER_STATUS" = "1" ]
  then
    FEE_PROTOCOL_SET_OWNER_TRANSACTION_HASH=$(echo "$FEE_PROTOCOL_SET_OWNER_OUTPUT" | grep -m 2 'transactionHash' | tail -n 1 | awk '{print $2}')
    echo -e "${GREEN_COLOR}- ZoraProtocolFeeSettings set owner success, tx hash: ${FEE_PROTOCOL_SET_OWNER_TRANSACTION_HASH}"
  else
    echo -e "${RED_COLOR}- ZoraProtocolFeeSettings set owner fail"
  fi
else
  echo "${NO_COLOR}ZoraProtocolFeeSettings set owner skipped, prev tx hash: $FEE_PROTOCOL_SET_OWNER_TRANSACTION_HASH"
fi

# ====

if [ "$ERC20_TRANSFER_HELPER_ADDR" = "" ]
then
  echo -e "${NO_COLOR}Deploy ERC20TransferHelper..."
  ERC20_TRANSFER_HELPER_DEPLOY_OUTPUT=$(forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY ERC20TransferHelper \
      --constructor-args $MODULE_MANAGER_ADDR \
    --verify --verifier sourcify --verifier-url $VERIFIER_URL)
  ERC20_TRANSFER_HELPER_ADDR=$(echo ${ERC20_TRANSFER_HELPER_DEPLOY_OUTPUT#*"Deployed to: "} | head -c 42)
  echo -e "${GREEN_COLOR}- deployed to: $ERC20_TRANSFER_HELPER_ADDR"

  if [[ $ERC20_TRANSFER_HELPER_DEPLOY_OUTPUT == *"Contract successfully verified"* ]]; then
    echo -e "${GREEN_COLOR}- verification result: success"
  else
    echo -e "${RED_COLOR}- fail to verify contract $ERC20_TRANSFER_HELPER_ADDR"
    echo "$ERC20_TRANSFER_HELPER_DEPLOY_OUTPUT"
  fi
else
  echo -e "${NO_COLOR}Skip deploying ERC20TransferHelper. Contract address provided ($ERC20_TRANSFER_HELPER_ADDR)"
fi

# ====

if [ "$ERC721_TRANSFER_HELPER_ADDR" = "" ]
then
  echo -e "${NO_COLOR}Deploy ERC721TransferHelper..."
  ERC721_TRANSFER_HELPER_DEPLOY_OUTPUT=$(forge create --rpc-url $RPC_URL --private-key $PRIVATE_KEY ERC721TransferHelper \
      --constructor-args $MODULE_MANAGER_ADDR \
    --verify --verifier sourcify --verifier-url $VERIFIER_URL)
  ERC721_TRANSFER_HELPER_ADDR=$(echo ${ERC721_TRANSFER_HELPER_DEPLOY_OUTPUT#*"Deployed to: "} | head -c 42)
  echo -e "${GREEN_COLOR}- deployed to: $ERC721_TRANSFER_HELPER_ADDR"

  if [[ $ERC721_TRANSFER_HELPER_DEPLOY_OUTPUT == *"Contract successfully verified"* ]]; then
    echo -e "${GREEN_COLOR}- verification result: success"
  else
    echo -e "${RED_COLOR}- fail to verify contract $ERC721_TRANSFER_HELPER_ADDR"
    echo "$ERC721_TRANSFER_HELPER_DEPLOY_OUTPUT"
  fi
else
  echo -e "${NO_COLOR}Skip deploying ERC721TransferHelper. Contract address provided ($ERC721_TRANSFER_HELPER_ADDR)"
fi

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
declare -a CONTRACT_ADDRESSES=( $FEE_SETTINGS_ADDR $ERC20_TRANSFER_HELPER_ADDR $ERC721_TRANSFER_HELPER_ADDR $ROYALTY_ENGINE_ADDR $WETH_ADDR $ASK_CONTRACT_ADDR )
declare -a CONTRACT_NAMES=( "ZoraProtocolFeeSettings" "ERC20TransferHelper" "ERC721TransferHelper" "RoyaltyEngineV1" "WETH9" "AsksV1_1" )

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
