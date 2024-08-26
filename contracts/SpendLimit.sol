// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

error SpendLimit__OnlyAccountCanCall();
error SpendLimit__AmountCannotBeZero();
error SpendLimit__InvalidUpdate();

contract SpendLimit {
    uint public ONE_DAY = 24 hours;

    /// data storage of daily spending limits 
    /// limit - amount of daily spending limits
    /// available - available amount that can be spent
    /// resetTime - timestamp at which available amount is restored
    /// isEnabled - this is true when daily limit is enabled
    struct Limit {
        uint limit;
        uint available;
        uint resetTime;
        bool isEnabled;
    }

    mapping(address => Limit) public limits;

    modifier onlyAccount() {
        if(msg.sender != address(this)) {
            revert SpendLimit__OnlyAccountCanCall();
        }
        _;
    }

    /// @param _token ERC20 token address for which limit will be applied
    /// @param _amount non-zero limit
    function setSpendLimit(address _token, uint _amount) public onlyAccount {
        if(_amount == 0) {
            revert SpendLimit__AmountCannotBeZero();
        }

        uint resetTime;
        uint timestamp = block.timestamp;

        if(_isValidUpdate(_token)) {
            resetTime = timestamp + ONE_DAY;
        } else {
            resetTime = block.timestamp;
        }

        _updateLimit(_token, _amount, _amount, resetTime, true);
    }

    /// @param _token address to ERC20 token that is checked
    /// check 0 - is token is enabled (activated or not)
    /// check 1 - updating before spending (limits[_token].limit == limits[_token].available)
    /// check 2 - called after 24 hours have passed since the last update
    function _isValidUpdate(address _token) internal view returns (bool) {
        if(limits[_token].isEnabled) {
            if (limits[_token].limit > limits[_token].available || block.timestamp <= limits[_token].resetTime){
                revert SpendLimit__InvalidUpdate();
            }
            return true;
        } else {
            return false;
        }
    }

    /// @notice Storage modifying using private function
    /// called by either setSpendingLimit or removeSpendingLimit
    function _updateLimit(address _token, uint _limit, uint _available, uint _resetTime, bool _isEnabled) private {
        Limit storage limit = limits[_token];
        limit.limit = _limit;
        limit.available = _available;
        limit.resetTime = _resetTime;
        limit.isEnabled = _isEnabled;
    }

    /// Called by Account.sol before executeTransaction() 
    /// @dev used to check if an account is able to spend a given amount of token, also records new `available` amount
    function _checkSpendingLimit(address _token, uint _amount) internal {
        Limit memory limit = limits[_token];
        if(!limit.isEnabled) return;
        uint timestamp = block.timestamp;

        /// renew reset time if it is already past, and also make available equal to limit
        /// if not spent, the change reset time to one day after
        if(limit.limit != limit.available && timestamp > limit.resetTime) {
            limit.resetTime = timestamp + ONE_DAY;
            limit.available = limit.limit;
        } else if(limit.limit == limit.available) {
            limit.resetTime = timestamp + ONE_DAY;
        }

        // Function will revert if `_amount` exceeds the available number
        require(limit.available >= _amount);
        
        // decrement through internal mapping
        limit.available -= _amount;
        limits[_token] = limit;
    }

    function removeSpendingLimit(address _token) public onlyAccount {
        if(!_isValidUpdate(_token)) {
            revert SpendLimit__InvalidUpdate();
        }
        _updateLimit(_token, 0, 0, 0, false);
    }
}