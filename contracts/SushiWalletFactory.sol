pragma solidity >=0.8;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./wallet/SushiWallet.sol";

/// @title Sushi wallet contract factory
contract SushiWalletFactory {
    address immutable WALLET_IMPLEMENTATION;
    address immutable SUSHI_ROUTER;
    address immutable MASTERCHEF_V1;
    address immutable MASTERCHEF_V2;

    mapping(address => address) public userToWallet;

    constructor(address _sushiRouter, address _masterChefV1, address _masterChefV2) {
        WALLET_IMPLEMENTATION = address(new SushiWallet());
        SUSHI_ROUTER = _sushiRouter;
        MASTERCHEF_V1 = _masterChefV1;
        MASTERCHEF_V2 = _masterChefV2;
    }

    ///@dev Check if address already has ana walllet assigned
    function hasWallet() private returns(bool) {
        address userWallet = userToWallet[msg.sender];
        if(userWallet == address(0)) {
            false;
        } else {
            true;
        }
    }

    ///@notice Create a sushi wallet for every address that calls this method
    function createWallet() external returns (address) {
        require(!hasWallet(), "User already has a wallet created, call userToWallet to check the address");
        address payable clone = payable(Clones.clone(WALLET_IMPLEMENTATION));
        SushiWallet(clone).initialize(SUSHI_ROUTER, MASTERCHEF_V1, MASTERCHEF_V2);
        userToWallet[msg.sender] = clone;
        return clone;
    }
}