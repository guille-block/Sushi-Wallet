# Sushi wallet implementation

## Background
This project demonstrates a basic use case for creating wallets that can interact with sushiswap efficiently. The main functionality radicates in the abilitiy to provide liquidity to any pool and automatically deposit the SLP tokens received into either MasterchefV1 or MasterchefV2 all in one transaction. At the same time, it also handles all basic wallet core functionalities. Any EOA can create a wallet through the sushi wallet factory and have competely control over it.

## Usage

Copy the project and install its dependendies.

```
git clone https://github.com/guille-block/rather-labs-challenge.git
cd rather-labs-challenge
npm install
```

Create an .env file. For simplicity, you can just rename .env-example and use that file.

```
mv .env-example .env
```

Run the unit tests with the following command:

```
npx hardhat test test/sushi-wallet.js
```

## Notes

All tests will run on a fork from the Ethereum blockchain
