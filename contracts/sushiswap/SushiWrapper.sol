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

    function initSushiWrapper(address sushiRouter, address _masterchefV1, address _masterchefV2) internal {
        SUSHI_ROUTER = sushiRouter;
        masterChefV1 = IMasterChefV1(_masterchefV1);
        masterChefV2 = IMasterChefV2(_masterchefV2);
    }

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