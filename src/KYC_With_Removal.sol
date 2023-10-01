// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

// making a system that verifies the identity of the user and then anyone can check if the user is verified or not and see their idendity.
// the KYC verifiction process will be done by social media platforms like facebook, twitter, instagram, etc.

interface Morpheus {
    function getFeeds(uint256[] memory feedIDs)
        external
        view
        returns (
            uint256[] memory value,
            uint256[] memory decimals,
            uint256[] memory timestamp,
            string[] memory APIendpoint,
            string[] memory APIpath,
            string[] memory valStr
        );

    function requestFeeds(
        string[] calldata APIendpoint,
        string[] calldata APIendpointPath,
        uint256[] calldata decimals,
        uint256[] calldata bounties
    ) external payable returns (uint256[] memory feeds);

    function supportFeeds(uint256[] calldata feedIds, uint256[] calldata values) external payable;
}

import "./Initializable.sol";

contract KYC is Initializable {
    /* 
    NOTES FOR ME
        Remember to add Deployer for new KYC verifiers contracts for new platforms

        add function for removing user's KYC data (KYC cancelation)

        // ****************
        // SUGGESTED by copilot autosuggestion, might add them later.

        add function for getting user's KYC data

        add function for getting user's KYC data by user's address

        add function for getting user's KYC data by user's handle

        add function for getting user's KYC data by user's signature hash
        
        // ****************

        
        treat the address 0x0 as null
    */
    uint160 public constant KYC_REMOVAL_PENDING_TIME = 1 days;
    address public constant MORPHEUS_ORACLE = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
    uint256 public constant DEFAULT_BOUNTY = 1000000000000000000;
    string internal APIEndPoint;
    /// @notice struct for storing user's KYC data
    /// @notice some platforms don't have a handle url, only a unique username, in that case the userHandle will be the keccak of the username
    /// @param isKYCVerified bool to check if the user is verified or not
    /// @param userHandle keccak of user's handle url to profile on the platform

    struct UserKYC {
        // address userAddress;
        string userHandle;
        uint160 issuanceTime;
        uint160 removalRequestTime;
        bool isKYCVerified;
    }

    struct KYCRequest {
        string userHandle;
        uint256 feed;
        bool isKYCRequested;
    }
    /// @notice keccak of the platform name

    string public platformName;
    /// @notice keccak of the platform base url
    string public platformBaseUrl;
    /// @notice mapping of user's address to their KYC data
    mapping(address => UserKYC) internal usersKYC;

    mapping(address => KYCRequest) internal kycRequests;

    event UserKYCVerified(address indexed userAddress, string userHandle, uint160 issuanceTime);
    event UserKYCRequested(address indexed userAddress, string userHandle, uint160 issuanceTime);
    event UserKYCCancelationRequested(address indexed userAddress, string userHandle, uint160 issuanceTime);
    event UserKYCValidationRequested(address indexed userAddress, string userHandle, uint160 issuanceTime);
    // event UserKYCVerificationCanceled(address indexed userAddress, string userHandle, uint160 issuanceTime);

    error UserKYCAlreadyVerified();
    error InvalidSignature();
    error UserKYCAlreadyRequested();
    error UserKYCNotRequested();
    error KYCCancelationRequestNotFound();
    error KYCRemovalRequestTimeNotPassed();
    error userKYCNotVerified();

    /// @param _platformName name of the platform
    /// @param _platformBaseUrl base url of the platform
    function initialize(string memory _APIEndPoint, string memory _platformName, string memory _platformBaseUrl)
        public
        initializer
    {
        platformName = _platformName;
        platformBaseUrl = _platformBaseUrl;
        APIEndPoint = string.concat(_APIEndPoint, _platformName, "/");
    }

    function requestKYC(string calldata userHandle) public payable returns (bool) {
        if (usersKYC[msg.sender].isKYCVerified) {
            revert UserKYCAlreadyVerified();
        }
        if (kycRequests[msg.sender].isKYCRequested) {
            revert UserKYCAlreadyRequested();
        }
        KYCRequest memory kycRequest;
        kycRequest.userHandle = userHandle;
        kycRequest.isKYCRequested = true;

        string[] memory endpoint = new string[](1);
        string[] memory path = new string[](1);
        uint256[] memory decimals = new uint[](1);
        uint256[] memory bounties = new uint[](1);
        path[0] = "account_sig";
        decimals[0] = 0;
        bounties[0] = msg.value != 0 ? msg.value : DEFAULT_BOUNTY;
        endpoint[0] = string.concat(APIEndPoint, userHandle);
        uint256[] memory x =
            Morpheus(MORPHEUS_ORACLE).requestFeeds{value: bounties[0]}(endpoint, path, decimals, bounties);

        kycRequest.feed = x[0];
        kycRequests[msg.sender] = kycRequest;
        emit UserKYCRequested(msg.sender, userHandle, uint160(block.timestamp));
        return true;
    }

    function verifyKYC() public returns (bool) {
        KYCRequest memory kycRequest = kycRequests[msg.sender];
        if (!kycRequest.isKYCRequested) {
            revert UserKYCNotRequested();
        }

        uint256[] memory feeds = new uint[](1);
        feeds[0] = kycRequests[msg.sender].feed;

        (uint256[] memory value,,,,,) = Morpheus(MORPHEUS_ORACLE).getFeeds(feeds);
        bytes32 sig = keccak256(abi.encodePacked(kycRequest.userHandle, msg.sender));
        if (sig != bytes32(value[0])) {
            revert InvalidSignature();
        }

        UserKYC memory userKYC;
        userKYC.issuanceTime = uint160(block.timestamp);
        userKYC.isKYCVerified = true;
        userKYC.userHandle = kycRequest.userHandle;

        usersKYC[msg.sender] = userKYC;

        delete kycRequests[msg.sender];

        emit UserKYCVerified(msg.sender, kycRequest.userHandle, uint160(block.timestamp));
        return true;
    }

    function removeKYCRequest() external returns (bool) {
        if (!kycRequests[msg.sender].isKYCRequested) {
            revert UserKYCNotRequested();
        }
        delete kycRequests[msg.sender];

        return true;
    }

    function requestKYCRemoval() external returns (uint160) {
        if (!usersKYC[msg.sender].isKYCVerified) revert userKYCNotVerified();

        usersKYC[msg.sender].removalRequestTime = uint160(block.timestamp);
        return uint160(block.timestamp);
    }

    function removeKYC() external returns (uint160) {
        uint160 removalRequestTime = usersKYC[msg.sender].removalRequestTime;
        if (removalRequestTime == 0) revert KYCCancelationRequestNotFound();
        if (removalRequestTime + KYC_REMOVAL_PENDING_TIME < uint160(block.timestamp)) {
            revert KYCRemovalRequestTimeNotPassed();
        }

        delete usersKYC[msg.sender];
        return uint160(block.timestamp);
    }

    receive() external payable {}

    function getUserKYC(address userAddress) public view returns (string memory, uint160, uint160, bool) {
        return (
            usersKYC[userAddress].userHandle,
            usersKYC[userAddress].issuanceTime,
            usersKYC[userAddress].removalRequestTime,
            usersKYC[userAddress].isKYCVerified
        );
    }

    function getKYCRequest(address userAddress) public view returns (string memory, bool, uint256) {
        return (
            kycRequests[userAddress].userHandle, kycRequests[userAddress].isKYCRequested, kycRequests[userAddress].feed
        );
    }

    function isKYCVerified(address userAddress) external view returns (bool) {
        return usersKYC[userAddress].isKYCVerified;
    }

    function isKYCRequested(address userAddress) external view returns (bool) {
        return kycRequests[userAddress].isKYCRequested;
    }

    function isKYCRemovalRequested(address userAddress) external view returns (bool) {
        return usersKYC[userAddress].removalRequestTime != 0;
    }
}
