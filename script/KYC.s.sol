// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

// import "forge-std/Script.sol";
import "../lib/forge-std/src/Script.sol";
import "src/KYC.sol";

/**
    Script deploy and runs KYC contract through the _Happiest_ Path.
 */
contract Monate is Script {
    bytes32 public platformName;
    bytes32 public platformBaseUrl;
    bytes32 public constant VerificationSignature =
        "My KYC Verification Signature: ";
    address public bot;
    address public user;
    KYC public kyc;
    KYC.UserKYC public userKYC;
    KYC.KYCRequest public kycRequest;
    function setUp() public {
        vm.startBroadcast(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);
        bot = address(17);
        user = vm.addr(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);

        // kyc = new KYC("Github", "https://github.com/");
        kyc = KYC(payable(0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0));
    }

    function run() public {
        console.log("kyc address: %s", address(kyc));
        kyc.requestKYC{value:1 ether}("0x0OZ");


    }
}

contract getFeed{
    function run() public view {
        // KYC kyc = KYC(payable(0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0));
        Morpheus morpheus = Morpheus(0x5FbDB2315678afecb367f032d93F642f64180aa3);
        uint256[] memory feeds = new uint[](1);
        feeds[0] = 0;
        (uint256[] memory value,,,,,) = morpheus.getFeeds(feeds);
        console.log("feed: %s", value[0]);
        feeds[0] = 0;
        ( value,,,,,) = morpheus.getFeeds(feeds);
        console.log("feed: %s", value[0]);

    }
}
