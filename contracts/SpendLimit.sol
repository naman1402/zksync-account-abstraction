// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract SpendLimit {
    uint public ONE_DAY = 24 hours;
    struct Limit {
        uint limit;
        uint available;
        uint resetTime;
        bool isEnabled;
    }

    mapping (address=>Limit) public limits;

    
}