#! /bin/bash

# Exit the script if any command fails  
# set -e

# Default values
ID=""
FUNDS_PK=""
RPC_URL="http://0.0.0.0:8545"
SOCKET=""
REGISTER_AVS=false

# Parse named arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --id)
      ID="$2"
      shift 2
      ;;
    --funds-pk)
      FUNDS_PK="$2"
      shift 2
      ;;
    --rpc-url)
      RPC_URL="$2"
      shift 2
      ;;
    --socket)
      SOCKET="$2"
      shift 2
      ;;
    --register-avs)
      REGISTER_AVS=true
      shift 1
      ;;
    --help)
      echo "Usage: $0 --id <id> --funds-pk <funds-pk> --rpc-url <rpc-url> --socket <socket>"
      exit 0
      ;;
    *)
      echo "Unknown parameter: $1"
      exit 1
      ;;
  esac
done


# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cleanup() {
  # set +e to avoid exiting the script if the rm commands fail
  set +e

  echo "Cleaning up..."
  rm $HOME/.eigenlayer/operator_keys/opr$ID.ecdsa.key.json
  rm $HOME/.eigenlayer/operator_keys/opr$ID.bls.key.json
  rm opr$ID.ecdsa.key.json
  rm opr$ID.bls.key.json
  rm $SCRIPT_DIR/operator$ID.yaml

  echo "Cleaning up complete"
  exit $?
} 

# trap cleanup on: interruption (ctrl+c), termination, and exit
trap cleanup EXIT INT TERM

# Validate required arguments
if [ -z "$ID" ]; then
  echo "Error: --id is required"
  exit 1
fi

if [ -z "$FUNDS_PK" ]; then
  echo "Error: --funds-pk is required"
  exit 1
fi

if [ -z "$RPC_URL" ]; then
  echo "Error: --rpc-url is required"
  exit 1
fi

if [ -z "$SOCKET" ]; then
  echo "Error: --socket is required"
  exit 1
fi

# Use the arguments
echo "ID: $ID"
echo "RPC URL: $RPC_URL"
echo "SOCKET: $SOCKET"

# Install EigenLayer CLI usinf curl
if ! command -v $HOME/bin/eigenlayer &> /dev/null; then
    echo "EigenLayer CLI is not installed"
    curl -sSfL https://raw.githubusercontent.com/layr-labs/eigenlayer-cli/master/scripts/install.sh | sh -s -- -b $HOME/bin v0.12.0-beta
fi

## Create a new ecdsa key
echo "" | $HOME/bin/eigenlayer keys create --key-type=ecdsa --insecure opr$ID > opr$ID.ecdsa.key.json
ECDSA_PRIVATE_KEY=$(grep -o "//[[:space:]]*[0-9a-f]\{64\}[[:space:]]*//" opr$ID.ecdsa.key.json | tr -d '//' | tr -d ' ')
echo "ECDSA_PRIVATE_KEY=$ECDSA_PRIVATE_KEY"

OPERATOR_ADDRESS=$(grep -o "[[:space:]]*0x[0-9a-fA-F]\{40\}[[:space:]]*" opr$ID.ecdsa.key.json | tr -d ' ')
echo "OPERATOR_ADDRESS=$OPERATOR_ADDRESS"

# Create a new bls key
echo "" | $HOME/bin/eigenlayer keys create --key-type=bls --insecure opr$ID > opr$ID.bls.key.json
BLS_PRIVATE_KEY=$(grep -o "//[[:space:]]*[0-9]\{50,100\}[[:space:]]*//" opr$ID.bls.key.json | tr -d '//' | tr -d ' ')
echo "BLS_PRIVATE_KEY=$BLS_PRIVATE_KEY"

cp $SCRIPT_DIR/operator.yaml $SCRIPT_DIR/operator$ID.yaml
sed -i '' "s/address: <OPERATOR_ADDRESS>/address: $OPERATOR_ADDRESS/" $SCRIPT_DIR/operator$ID.yaml

echo $HOME
sed -i '' "s|private_key_store_path: <PATH_TO_KEY>|private_key_store_path: $HOME/.eigenlayer/operator_keys/opr$ID.ecdsa.key.json|" $SCRIPT_DIR/operator$ID.yaml
sed -i '' "s|eth_rpc_url: <ETH_RPC_URL>|eth_rpc_url: $RPC_URL|" $SCRIPT_DIR/operator$ID.yaml

# Send funds to the operator
cast send $OPERATOR_ADDRESS --value 0.2ether --private-key $FUNDS_PK --rpc-url $RPC_URL 

sleep 10
# Register the operator
echo "Registering operator..."
echo "" | $HOME/bin/eigenlayer operator register $SCRIPT_DIR/operator$ID.yaml

sleep 10
# Restake 
echo "Restaking..."
PARENT_DIR="$SCRIPT_DIR/.."
$SCRIPT_DIR/acquire_and_deposit_steth.sh $RPC_URL $ECDSA_PRIVATE_KEY $PARENT_DIR/contracts/script/input/testnet.json 0.1ether

# Output to json
mkdir -p $SCRIPT_DIR/operators
cat << EOF > $SCRIPT_DIR/operators/operator$ID.json
{
  "operator_address": "$OPERATOR_ADDRESS",
  "ecdsa_private_key": "$ECDSA_PRIVATE_KEY",
  "bls_private_key": "$BLS_PRIVATE_KEY",
  "socket": "localhost:$SOCKET"
}
EOF

if $REGISTER_AVS; then
  echo "Registering operator to AVS..."
  go run $SCRIPT_DIR/register.go \
    --eth-url $RPC_URL \
    --eigenlayer-deployment-path $PARENT_DIR/contracts/script/input/testnet.json \
    --avs-deployment-path $PARENT_DIR/contracts/script/output/avs_deploy_output.json \
    --ecdsa-private-key $ECDSA_PRIVATE_KEY \
    --bls-private-key $BLS_PRIVATE_KEY \
    --socket "localhost:$SOCKET"
fi
