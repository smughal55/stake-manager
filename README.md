Overview

This is a simple Stake Manager for EVM compatible blockchains.

The Stake Manager is a simple smart contract that allows users to stake ETH and withdraw them after a lock period. The lock period is defined by the owner of the contract and can be changed at any time. The owner can also withdraw any slashed staked amount at any time.

Assumptions

The Stake Manager is designed to be used in a permissionless environment, where anyone can stake and withdraw their funds. The owner of the contract is the only one who can change the lock period and withdraw slashed funds.

There is no limit to the slashing amount, the ADMIN can slash the whole staked amount of a specific user.

Requirements

git: https://git-scm.com/book/en/v2/Getting-Started-Installing-Git
foundry: https://getfoundry.sh/

Quick Start

To deploy the Stake Manager, you need to have an Ethereum account with some ETH and a private key. You can use the .env_example file to create a .env file with your private key and the RPC URL of the network you want to deploy the contract to.

git clone https://github.com/smughal55/stake-manager
cd stake-manager

Dependencies

Run `forge install OpenZeppelin/openzeppelin-contracts-upgradeable --no-commit`

Build

Run `forge clean && forge build`

Testing

Run `forge test -vvvv --ffi` to run the tests with verbose output.

Deploy

Locally

Open a new terminal session and run `anvil` to start a local blockchain.

Copy the PRIVATE_KEY from anvil and paste it in the .env file, create this file using .env_example.

Run `forge script script/DeployStakeManager.s.sol --fork-url http://127.0.0.1:8545 --broadcast --ffi`

Interact

The first private key in the .env file is assumed to be the owner/admin of the contract and is referenced as $PRIVATE_KEY (assuming you have run `source .env`).

Take a second private key from anvil as the user and use it to interact with the contract as a user. It is referenced as $USER_PRIVATE_KEY in the .env file.

Deploying the contract will return the address of the deployed contract. You can use this address to interact with the contract.

First set the configuration of the Stake Manager as the owner:

`cast send %CONTRACT_ADDRESS% "setConfiguration(uint, uint)" 1000000000000000000 1000 --private-key $PRIVATE_KEY`

As a user, register as a staker:

`cast send %CONTRACT_ADDRESS% "register()" --value 1000000000000000000 --private-key $USER_PRIVATE_KEY`

As a user, stake some amount:

`cast send %CONTRACT_ADDRESS% "stake(uint256)" --value 1000000000000000000 --private-key $USER_PRIVATE_KEY`

As an admin, slash the staked amount of the user:

Take the public address of the user associated with the $USER_PRIVATE_KEY from anvil and use it in the following command (the user address below should be replaced) to slash the staked amount of the user. The amount is in wei, so 1 ETH is 1000000000000000000 wei.:

`cast send %CONTRACT_ADDRESS% "slash(address, uint)" 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 1000000000000000000 --private-key $PRIVATE_KEY`

As a user, unstake the staked amount:

`cast send %CONTRACT_ADDRESS% "unstake()" --private-key $USER_PRIVATE_KEY`

As a user, withdraw the staked amount:

`cast send %CONTRACT_ADDRESS% "withdraw()" --private-key $USER_PRIVATE_KEY`

As a user, unregister as a staker:

`cast send %CONTRACT_ADDRESS% "unregister()" --private-key $USER_PRIVATE_KEY`

As an admin, withdraw the slashed amount, change the beneficiary address as appropriate:

`cast send %CONTRACT_ADDRESS% "withdrawSlashed(address)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266  --private-key $USER_PRIVATE_KEY`
