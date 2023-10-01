// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// Basic and Simple, right?

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
    /// @notice struct for storing user's KYC data
    /// @notice some platforms don't have a handle url, only a unique username, in that case the userHandle will be the keccak of the username
    /// @param isKYCVerified bool to check if the user is verified or not
    /// @param userHandle keccak of user's handle url to profile on the platform

    struct UserKYC {
        // address userAddress;
        string userHandle;
        uint160 issuanceTime;
        bool isKYCVerified;
    }

    /// @notice struct for storing user's KYC request data
    /// @param isKYCRequested bool to check if the user has requested KYC verification or not
    /// @param userHandle keccak of user's handle url to profile on the platform
    /// @param feed feed id of the request
    struct KYCRequest {
        string userHandle;
        uint256 feedId;
        bool isKYCRequested;
    }

    uint160 public constant KYC_REMOVAL_PENDING_TIME = 1 days;
    address public constant MORPHEUS_ORACLE = 0x5FbDB2315678afecb367f032d93F642f64180aa3;
    uint256 public constant DEFAULT_BOUNTY = 1000000000000000000;
    string internal APIEndPoint;

    /// @notice the platform name
    string public platformName;
    /// @notice platform base url, not used for anything specific.
    string public platformBaseUrl;
    /// @notice mapping of user's address to their KYC data
    mapping(address => UserKYC) internal usersKYC;
    /// @notice mapping of user's address to their KYC request data
    mapping(address => KYCRequest) internal kycRequests;

    event UserKYCRequested(address indexed userAddress, string userHandle, uint160 issuanceTime);
    event UserKYCVerified(address indexed userAddress, string userHandle, uint160 issuanceTime);
    event UserKYCVerificationCanceled(address indexed userAddress, string userHandle, uint160 issuanceTime);

    error UserKYCNotRequested();
    error userKYCNotVerified();
    error UserKYCAlreadyRequested();
    error UserKYCAlreadyVerified();
    error InvalidSignature(bytes32 sig1, bytes32 sig2);

    /// @notice initialize the KYC contract
    /// @param _APIEndPoint API endpoint for the platformName
    /// @param _platformName name of the platform
    /// @param _platformBaseUrl base url of the platform
    function initialize(string memory _APIEndPoint, string memory _platformName, string memory _platformBaseUrl)
        external
        initializer
    {
        platformName = _platformName;
        platformBaseUrl = _platformBaseUrl;
        APIEndPoint = _APIEndPoint;
    }

    /// @notice request KYC verification
    /// @param userHandle username, then user handle on the platform, e.g 0xOZ
    /// @return bool true if the request was successful
    function requestKYC(string calldata userHandle) external payable returns (bool) {
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
        // uint256[] memory x =
        // Morpheus(MORPHEUS_ORACLE).requestFeeds{value: bounties[0]}(endpoint, path, decimals, bounties);

        kycRequest.feedId =
            Morpheus(MORPHEUS_ORACLE).requestFeeds{value: bounties[0]}(endpoint, path, decimals, bounties)[0];
        kycRequests[msg.sender] = kycRequest;
        emit UserKYCRequested(msg.sender, userHandle, uint160(block.timestamp));
        return true;
    }

    /// @notice verify User's KYC request
    /// @return bool true if the verification was successful
    function verifyKYC() external returns (bool) {
        KYCRequest memory kycRequest = kycRequests[msg.sender];
        if (!kycRequest.isKYCRequested) {
            revert UserKYCNotRequested();
        }

        uint256[] memory feeds = new uint[](1);
        feeds[0] = kycRequests[msg.sender].feedId;

        (uint256[] memory value,,,,,) = Morpheus(MORPHEUS_ORACLE).getFeeds(feeds);
        bytes32 sig = keccak256(abi.encodePacked(kycRequest.userHandle, msg.sender));
        if (sig != bytes32(value[0])) {
            revert InvalidSignature(sig, bytes32(value[0]));
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

    /// @notice cancel User's KYC request
    /// @notice doesn't work if the user is already verified
    /// @return bool true if the cancellation was successful
    function removeKYCRequest() external returns (bool) {
        if (!kycRequests[msg.sender].isKYCRequested) {
            revert UserKYCNotRequested();
        }
        delete kycRequests[msg.sender];

        return true;
    }

    /// @notice get User's KYC request feedId
    function getFeedId() external view returns (uint256) {
        return kycRequests[msg.sender].feedId;
    }

    /// @notice Support specific set of feedIds to bump their value
    function supportFeeds(uint256[] calldata feedIds, uint256[] calldata values) external payable returns (bool) {
        Morpheus(MORPHEUS_ORACLE).supportFeeds{value: msg.value}(feedIds, values);
        return true;
    }

    /// @notice Support specific feedId to bump its value
    function supportFeed(uint256 feedId, uint256 value) external payable returns (bool) {
        uint256[] memory feedIds = new uint[](1);
        uint256[] memory values = new uint[](1);
        feedIds[0] = feedId;
        values[0] = value;
        Morpheus(MORPHEUS_ORACLE).supportFeeds{value: msg.value}(feedIds, values);
        return true;
    }

    /// @notice Accepts donations
    receive() external payable {}

    /// @notice get User's KYC data
    /// @param userAddress address of the user
    /// @return string userHandle, uint160 issuanceTime, bool isKYCVerified
    function getUserKYC(address userAddress) external view returns (string memory, uint160, bool) {
        return
            (usersKYC[userAddress].userHandle, usersKYC[userAddress].issuanceTime, usersKYC[userAddress].isKYCVerified);
    }

    /// @notice get User's KYC request data
    /// @param userAddress address of the user
    /// @return string userHandle, bool isKYCRequested, uint256 feed
    function getKYCRequest(address userAddress) external view returns (string memory, bool, uint256) {
        return (
            kycRequests[userAddress].userHandle, kycRequests[userAddress].isKYCRequested, kycRequests[userAddress].feedId
        );
    }

    /// @notice get User's KYC data
    /// @param userAddress address of the user
    /// @return true of the user is verified
    function isKYCVerified(address userAddress) external view returns (bool) {
        return usersKYC[userAddress].isKYCVerified;
    }
    
    /// @notice get User's KYC data
    /// @return true of the sender is verified
    function isKYCVerified() external view returns (bool) {
        return usersKYC[msg.sender].isKYCVerified;
    }

    /// @notice get User's KYC request data
    /// @param userAddress address of the user
    /// @return true of the user has requested KYC verification
    function isKYCRequested(address userAddress) external view returns (bool) {
        return kycRequests[userAddress].isKYCRequested;

    }
}
