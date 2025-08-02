// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract AdrianMasterProxy is Initializable {
    address public admin;
    mapping(bytes4 => address) public implementations;
    bool private initialized;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not admin");
        _;
    }

    function initialize(address _admin) external initializer {
        require(!initialized, "Already initialized");
        admin = _admin;
        initialized = true;
    }

    function updateImplementation(bytes4 selector, address implementation) external onlyAdmin {
        implementations[selector] = implementation;
    }

    function updateAdmin(address newAdmin) external onlyAdmin {
        admin = newAdmin;
    }

    fallback() external payable {
        address impl = implementations[msg.sig];
        require(impl != address(0), "Function not implemented");
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    receive() external payable {}
} 