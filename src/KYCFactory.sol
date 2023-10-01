// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

interface Initializer {
    function initialize(string memory ApiEndPoint, string memory _platformName, string memory _platformBaseUrl)
        external;
}

contract KYCFactory {
    address internal immutable KYCImplementation;
    address internal owner;
    mapping(address => string) internal KYCVerifierNameByAddress;
    mapping(string => address) internal KYCVerifierAddressByName;
    address[] public KYCVerifierAddresses;

    event KYCVerifierCreated(address indexed _address, string _platformName);

    constructor(address _KYCImplementation) {
        owner = msg.sender;
        KYCImplementation = _KYCImplementation;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function.");
        _;
    }

    function createKYCVerifier(string memory _APIEndPoint, string memory _platformName, string memory _platformBaseUrl, bytes32 salt)
        public
        payable
        onlyOwner
    {
        address newKYCVerifierAddress = createClone(KYCImplementation, salt);
        KYCVerifierNameByAddress[newKYCVerifierAddress] = _platformName;
        KYCVerifierAddressByName[_platformName] = newKYCVerifierAddress;
        KYCVerifierAddresses.push(newKYCVerifierAddress);
        string.concat(_APIEndPoint, _platformName, "/");
        _APIEndPoint = string.concat(_APIEndPoint, _platformName, "/");
        Initializer(newKYCVerifierAddress).initialize(_APIEndPoint, _platformName, _platformBaseUrl);
        emit KYCVerifierCreated(newKYCVerifierAddress, _platformName);
    }

    function getKYCVerifierAddress(string memory _platformName) public view returns (address) {
        return KYCVerifierAddressByName[_platformName];
    }

    function getKYCVerifierName(address _platformAddress) public view returns (string memory) {
        return KYCVerifierNameByAddress[_platformAddress];
    }

    function getKYCVerifierAddresses() public view returns (address[] memory) {
        return KYCVerifierAddresses;
    }

    function createClone(address target, bytes32 salt) internal returns (address result) {
        bytes20 targetBytes = bytes20(target);
        assembly {
            let clone := mload(0x40)
            mstore(clone, 0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000)
            mstore(add(clone, 0x14), targetBytes)
            mstore(add(clone, 0x28), 0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000)
            result := create2(callvalue(), clone, 0x37, salt)
        }
    }
}
