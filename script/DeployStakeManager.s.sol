// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {Script} from "forge-std/Script.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";
import {StakeManager} from "./../src/StakeManager.sol";

contract DeployStakeManager is Script {
    function run() external returns (address) {
        address proxy = Upgrades.deployUUPSProxy(
            "StakeManager.sol",
            abi.encodeCall(StakeManager.initialize, ())
        );
        return proxy;
    }
}
