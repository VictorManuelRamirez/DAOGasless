// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Script, console } from "forge-std/Script.sol";
import { MinimalForwarder } from "../src/MinimalForwarder.sol";
import { DAOVoting } from "../src/DAOVoting.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerKey);

        MinimalForwarder forwarder = new MinimalForwarder();
        DAOVoting dao = new DAOVoting(address(forwarder));

        vm.stopBroadcast();

        console.log("MinimalForwarder deployed at:", address(forwarder));
        console.log("DAOVoting deployed at:", address(dao));
        console.log("");
        console.log("Add to .env.local:");
        console.log("NEXT_PUBLIC_FORWARDER_ADDRESS=", address(forwarder));
        console.log("NEXT_PUBLIC_DAO_ADDRESS=", address(dao));
    }
}
