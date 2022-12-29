pragma solidity >=0.8;

import "./IMasterChefBase.sol";

interface IMasterChefV2 is IMasterChefBase {
    function lpToken(uint256) external view returns (address);
    function deposit(uint256,uint256,address) external;
    function withdrawAndHarvest(uint256,uint256,address) external;
}