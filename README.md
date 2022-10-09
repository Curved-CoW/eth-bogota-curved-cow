# Curved Orders - a novel Smart Order type for CoW Protocol

Curved Orders are a smart order type for CoW protocol. They allow the submitter of an order to define a pricing curve which potential trades are validated against. Put simply, larger volume trades are sold at a higher price, while smaller volume orders are sold closer to spot price. LPs only need to submit one order, and their order can be gradually filled with configurable dynamic pricing. 
## Getting Started

* Install [Foundry](https://github.com/foundry-rs/foundry)
* run `npm install`
* run tests: `forge test`


## Place an order: 

1. update `src/scripts/placeOrder.s.sol` with order configuration, and then 
2. run `forge script placeOrder --fork-url https://eth-mainnet.alchemyapi.io/v2/xxxxxxxxx`

> ! The order factory contract is deployed on gorli & mainnet, but should probably not be used for production purposes

