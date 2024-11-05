// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


contract MyWallet { 
    string public name;
    mapping (address => bool)private approved;
    modifier auth {
        address _owner;
        uint256 slot = 2;
        assembly {
            _owner := sload(slot)
        }
        require (msg.sender == _owner, "Not authorized");
        _;
    }

    constructor(string memory _name) {
        name = _name;
        uint256 slot =2;
        address _owner = msg.sender;
        assembly {
            sstore(slot, _owner)
        }

    } 

    function transferOwernship(address _addr) public auth {
        require(_addr!=address(0), "New owner is the zero address");

        address _owner;
        uint256 slot = 2;
        assembly {
            _owner := sload(slot)
        }
        require(_owner != _addr, "New owner is the same as the old owner");

        assembly {
            sstore(slot, _addr)
        }

    }

    function owner() public view returns (address _owner) {
        uint256 slot = 2;
        assembly {
            _owner := sload(slot)
        }
    }
}