pragma solidity >=0.8;

import "./IMasterChefBase.sol";

interface IMasterChefV1 is IMasterChefBase {
    function deposit(uint256,uint256) external;
    function withdraw(uint256,uint256) external;
}