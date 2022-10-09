# Curved Orders - a novel Smart Order type for CoW Protocol

Curved Orders are a smart order type for CoW protocol. They allow the submitter of an order to define a pricing curve which potential trades are validated against. Put simply, larger volume trades are sold at a higher price, while smaller volume orders are sold closer to spot price. LPs only need to submit one order, and their order can be gradually filled with configurable dynamic pricing. 
## Getting Started

* Install [Foundry](https://github.com/foundry-rs/foundry)
* run `npm install`
* run tests: `forge test`

* Place an order:

