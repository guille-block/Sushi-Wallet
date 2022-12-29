pragma solidity >=0.8;

import "./BasicWallet.sol";
import "../sushiswap/SushiWrapper.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract SushiWallet is BasicWallet, SushiWrapper, Initializable {

    function initialize(address sushiRouter, address masterchefV1, address masterchefV2) initializer external {
        initWallet();
        initSushiWrapper(sushiRouter, masterchefV1, masterchefV2);
    }

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

    function withdrawFromYieldFarming(
        address tokenA,
        address tokenB,
        uint256 amount
    ) 
        external onlyOwner 
    {
        withdrawSLPToYieldFarm(tokenA,tokenB,amount);
    } 

    function withdrawERC20(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner,amount);
    }  

}
