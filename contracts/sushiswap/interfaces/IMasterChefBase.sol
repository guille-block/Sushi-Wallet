pragma solidity >=0.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// Simple trick for compilation purpose to use artifact on testing
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IPool {
     struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. SUSHIs to distribute per block.
        uint256 lastRewardBlock; // Last block number that SUSHIs distribution occurs.
        uint256 accSushiPerShare; // Accumulated SUSHIs per share, times 1e12. See below.
    }
}

interface IMasterChefBase is IPool {
    function poolInfo(uint256) external view returns (PoolInfo memory);
    function poolLength() external view returns (uint256);
}