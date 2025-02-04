// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import "../src/Tiplify.sol";

contract DeployScript is Script {
    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address usdc = vm.envAddress("USDC_ADDRESS");
        console2.log("Deployer address", vm.addr(deployerPrivateKey));
        vm.startBroadcast(deployerPrivateKey);

        Tiplify tiplify = new Tiplify(usdc, vm.addr(deployerPrivateKey), 500);
        console2.log("Tiplify:", address(tiplify));

        vm.stopBroadcast();
    }
}
