// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "lib/forge-std/src/Script.sol";
import "src/KYCFactory.sol";
import "src/KYC.sol";

contract Monate is Script {
    address KYCImp;
    KYCFactory factory;
    string APIEndPoint = "http://192.2.1.3/api/";
    address user = vm.addr(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);

    function setUp() public {
        vm.startBroadcast(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);
        // KYCImp = address(new KYC());
        // factory = new KYCFactory(KYCImp);
    }

    function requestKYC(string memory username) public {
        address kycAddress = factory.getKYCVerifierAddress("Github");
        KYC kyc = KYC(payable(kycAddress));
        address(kyc).call{value: 1 ether}('');
        kyc.requestKYC(username);
    }

    function createKYC() public {
        factory.createKYCVerifier(APIEndPoint, "Github", "https://github.com", keccak256(abi.encodePacked("Github")));
        factory.createKYCVerifier(APIEndPoint, "Twitter", "https://twitter.com", keccak256(abi.encodePacked("Twitter")));
        factory.createKYCVerifier(APIEndPoint, "Reddit", "https://reddit.com", keccak256(abi.encodePacked("Reddit")));
        factory.createKYCVerifier(APIEndPoint, "Discord", "https://discord.com", keccak256(abi.encodePacked("Discord")));
        factory.createKYCVerifier(APIEndPoint, "Google", "https://Google.com", keccak256(abi.encodePacked("Google")));
    }

    function verifyKYC() public {
        address kycAddress = factory.getKYCVerifierAddress("Github");
        KYC kyc = KYC(payable(kycAddress));
        kyc.verifyKYC();
    }

    function createFactory() public {
        KYCImp = address(new KYC());
        factory = new KYCFactory(KYCImp);
    }

    function getFactory() public pure returns (address) {
        return address(0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9);
    }

    function getFeedId() public view returns (uint256) {
        KYC kyc = KYC(payable(factory.getKYCVerifierAddress("Github")));
        return kyc.getFeedId();
    }

    function run() public {
        createFactory();
        createKYC();
        factory = KYCFactory(payable(getFactory()));

        console.log("factory address: %s", address(factory));
        KYC kyc = KYC(payable(factory.getKYCVerifierAddress("Github")));
        // kyc.removeKYCRequest();
        console.log("kyc address: %s", address(kyc));
        console.log("feed: %s", getFeedId());
        console.log("isKYCVerified: %s", kyc.isKYCVerified());
        requestKYC("0x0OZ");
        // verifyKYC();
    }
}
