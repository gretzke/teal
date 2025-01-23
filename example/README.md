# Teal Example

This example will take you end to end through deploying a minimal AVS that uses BLS aggregation to verify operator signatures on a SIMPLE TASK.

## Step 0: Setup Environment

```
export ETH_RPC_URL=<HOLSKY_RPC_URL>
export PRIVATE_KEY=<PRIVATE_KEY_WITH_SOME_ETH_IN_IT>
```

# Step 1: Deploy the AVS

For demo purposes, we'll deploy an AVS to EigenLayer's Holesky testnet with a single quorum that just pays attention to the StETH strategy.

```
cd example/contracts
forge script --rpc-url $ETH_RPC_URL --private-key $PRIVATE_KEY script/DeployAVS.s.sol --broadcast  --sig "run(string,uint256,address[])" -- ./script/input/testnet.json 200 "[0x7d704507b76571a51d9cae8addabbfd0ba0e63d3]"
```

See that `example/contracts/script/output/avs_deploy_output.json` has been created.

Only change the strategies if you know what you're doing.

# Step 2: Setup Operators

First, let's create an operator and give it some stETH.

```
cd example/scripts
./init_operators.sh --num-operators 3 --rpc-url $ETH_RPC_URL --funds-pk $PRIVATE_KEY
```

This will mint and deposit 0.1 ether of stETH into EigenLayer on behalf of the operator.

Now, let's register the operator with EigenLayer and the AVS.

```
./register_operator_avs.sh --rpc-url $ETH_RPC_URL
```

This will register your operator with the AVS and EigenLayer.

# Step 3: Run the Operator and Aggregator

Run the operator first.

```
./start_nodes.sh --rpc-url $UNI_RPC_URL
```

In a seperate terminal, run the aggregator. (ETH_RPC_URL MUST BE WSS)

```
./start_aggregator.sh --rpc-url $ETH_RPC_URL --private-key $PRIVATE_KEY --unichain-url $UNI_RPC_URL
```
