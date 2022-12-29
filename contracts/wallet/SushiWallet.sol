pragma solidity >=0.8;

import "./BasicWallet.sol";
import "../sushiswap/SushiWrapper.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/// @title Sushi wallet contract
contract SushiWallet is BasicWallet, SushiWrapper, Initializable {
    /// @notice Initialize wallet and sushiswap wrapper functionality
    /// @dev Can only be invoked once
    /// @param sushiRouter Ethereum sushiswapRouterV2 address
    /// @param masterchefV1 Ethereum MasterChef Pool address
    /// @param masterchefV2 Ethereum Masterchef V2 address
    function initialize(address sushiRouter, address masterchefV1, address masterchefV2) initializer external {
        initWallet();
        initSushiWrapper(sushiRouter, masterchefV1, masterchefV2);
    }

    /// @notice Execute one transaction LP and YF opertaion
    /// @param tokenA Address of token 0 in sushiswap pool
    /// @param tokenB Address of token 1 in sushiswap pool
    /// @param amountADesired amount of tokenA that we are willing to provide
    /// @param amountBDesired amount of tokenB that we are willing to provide
    /// @param deadline Max timestamp were this action is valid
    function executeYieldFarming(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint deadline
    ) 
        external onlyOwner 
    {
        executeLPSUSHIDeposit(tokenA,tokenB,amountADesired,amountBDesired,deadline);
    }  

    /// @notice Withdraw SLP tokens from yield farm
    /// @param tokenA Address of token 0 in sushiswap pool
    /// @param tokenB Address of token 1 in sushiswap pool
    /// @param amount amount of SLP tokens to withdraw
    function withdrawFromYieldFarming(
        address tokenA,
        address tokenB,
        uint256 amount
    ) 
        external onlyOwner 
    {
        withdrawSLPToYieldFarm(tokenA,tokenB,amount);
    } 

    /// @notice Transfer ERC20 tokens to owner
    /// @param token Address of ERC20 token to transfer
    /// @param amount amount of ERC20 token to transfer
    function withdrawERC20(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner,amount);
    }  

}
