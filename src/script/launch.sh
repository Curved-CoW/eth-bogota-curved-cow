# To load the variables in the .env file
source .env

# To deploy and verify our contract in Goerli
# forge script src/script/CurvedOrders.s.sol:MyScript --rpc-url $GOERLI_RPC_URL --broadcast --verify -vvvv

# To deploy our contract locally
forge script src/script/CurvedOrders.s.sol:MyScript --fork-url http://localhost:8545 --broadcast
