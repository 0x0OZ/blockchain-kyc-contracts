// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "src/KYC.sol";

contract Monate is Test {
    address public bot;
    address public user;
    KYC public kyc;
    KYC.UserKYC public userKYC;
    KYC.KYCRequest public kycRequest;
    string public APIEndPoint;
    string platformBaseUrl;
    string platformName;
    function setUp() public {
        bot = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
        user = address(18);
        platformName = "Twitter";
        platformBaseUrl = "https://twitter.com/";
        kyc = new KYC();
        APIEndPoint = "https://api.twitter.com/2/users/by/username/";
        kyc.initialize(APIEndPoint, platformName, platformBaseUrl);
    }
}
