pragma solidity >=0.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IMasterChefV1.sol";
import "./interfaces/IMasterChefV2.sol";
import "./interfaces/IMasterChefBase.sol";
import "./libraries/UniswapV2Library.sol";


abstract contract SushiWrapper is IPool {
    address internal SUSHI_ROUTER;
    IMasterChefV1 internal masterChefV1;
    IMasterChefV2 internal masterChefV2;

    /// @notice Initialize wrapper with sushiswap addresses
    /// @param sushiRouter Ethereum sushiswapRouterV2 address
    /// @param _masterchefV1 Ethereum MasterChef Pool address
    /// @param _masterchefV2 Ethereum Masterchef V2 address
    function initSushiWrapper(address sushiRouter, address _masterchefV1, address _masterchefV2) internal {
        SUSHI_ROUTER = sushiRouter;
        masterChefV1 = IMasterChefV1(_masterchefV1);
        masterChefV2 = IMasterChefV2(_masterchefV2);
    }

    /// @notice Execute first liquidity provide and follow with the yield farming operation
    /// @param tokenA Address of token 0 in sushiswap pool
    /// @param tokenB Address of token 1 in sushiswap pool
    /// @param amountADesired amount of tokenA that we are willing to provide
    /// @param amountBDesired amount of tokenB that we are willing to provide
    /// @param deadline Max timestamp were this action is valid
    function executeLPSUSHIDeposit(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint deadline
    ) 
        internal 
    {
        depositTokensToPool(tokenA, tokenB, amountADesired, amountBDesired, deadline);
        depositSLPToYieldFarm(tokenA, tokenB);
    }

    /// @notice Retrieve the position of the pool id and te Masterchef contract where it was found
    /// @param lpToken SLP token address from a sushiswap pool
    /// @return pid that relates to the correct Masterchef pool based on our SLP token
    /// @return Address of either MasterchefV2 or MasterchefV1 depending on where the pool is found
    function getMasterChefPid(address lpToken) private view returns (uint256, address) {
        uint256 numPoolsV1 = masterChefV1.poolLength();
        uint256 numPoolsV2 = masterChefV2.poolLength();
        uint256 size = numPoolsV1 >= numPoolsV2 ? numPoolsV1 : numPoolsV2;

        for (uint256 i = 0; i < size;) {
            PoolInfo memory poolV1 = masterChefV1.poolInfo(i);
            
            if (address(poolV1.lpToken) == lpToken) {
                return (i, address(masterChefV1));
            } 

            if(i <= numPoolsV2) {
                address lpTokenI= masterChefV2.lpToken(i);
                if (address(lpTokenI) == lpToken) {
                    return (i, address(masterChefV2));
                }   
            }
            ++i;
        }
        
        revert("Pair is not listed on MasterChefV1 or MasterChefV2");
    }

    /// @notice Execute liquidity provide operation
    /// @param tokenA Address of token 0 in sushiswap pool
    /// @param tokenB Address of token 1 in sushiswap pool
    /// @param amountADesired amount of tokenA that we are willing to provide
    /// @param amountBDesired amount of tokenB that we are willing to provide
    /// @param deadline Max timestamp were this action is valid
    function depositTokensToPool(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint deadline
    ) 
        private 
    {
        IERC20(tokenA).approve(address(SUSHI_ROUTER), amountADesired);
        IERC20(tokenB).approve(address(SUSHI_ROUTER), amountBDesired);
        (bool success, bytes memory res) = SUSHI_ROUTER.call(abi.encodeWithSignature("addLiquidity(address,address,uint256,uint256,uint256,uint256,address,uint256)",
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            0,
            0,
            address(this),
            deadline
        ));

        require(success, "Call to SUSHI_ROUTER.addLiquidity() failed");
    }

    /// @notice Execute yield farm operation
    /// @dev We deposit all available SLP tokens
    /// @param tokenA Address of token 0 in sushiswap pool
    /// @param tokenB Address of token 1 in sushiswap pool
    function depositSLPToYieldFarm(address tokenA, address tokenB) private {
        (bool successFactory, bytes memory resFactory) = SUSHI_ROUTER.call(abi.encodeWithSignature("factory()"));
        require(successFactory, "Call to SUSHI_ROUTER.factory() failed");
        address factory = abi.decode(resFactory, (address));

        address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);
        (uint256 pid, address masterChefVersion) = getMasterChefPid(pair);

        uint256 balanceSLP = IERC20(pair).balanceOf(address(this));
        
        if(masterChefVersion == address(masterChefV1)) {
            IERC20(pair).approve(address(masterChefV1), balanceSLP);
            masterChefV1.deposit(pid, balanceSLP);
        } else {
            IERC20(pair).approve(address(masterChefV2), balanceSLP);
            masterChefV2.deposit(pid, balanceSLP, address(this));
        }
        
    }

    /// @notice Withdraw SLP tokens from MasterChef
    /// @dev We will harvest all SUSHI to claim on rewarder pid
    /// @param tokenA Address of token 0 in sushiswap pool
    /// @param tokenB Address of token 1 in sushiswap pool
    /// @param amountToWithDraw amount of SLP tokens to withdraw
    function withdrawSLPToYieldFarm(address tokenA, address tokenB, uint256 amountToWithDraw) internal {
        (bool successFactory, bytes memory resFactory) = SUSHI_ROUTER.call(abi.encodeWithSignature("factory()"));
        require(successFactory, "Call to SUSHI_ROUTER.factory() failed");
        address factory = abi.decode(resFactory, (address));

        address pair = UniswapV2Library.pairFor(factory, tokenA, tokenB);
        (uint256 pid, address masterChefVersion) = getMasterChefPid(pair);

        if(masterChefVersion == address(masterChefV1)) {
            masterChefV1.withdraw(pid, amountToWithDraw);
        } else {
            masterChefV2.withdrawAndHarvest(pid, amountToWithDraw, address(this));
        }
    }


}