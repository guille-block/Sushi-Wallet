const helpers = require("@nomicfoundation/hardhat-network-helpers")
const { ethers } = require("hardhat");
const {expect} = require("chai")

//Mappping of tokens with providers that can serve us funds to provide liquidity
let tokensToProviders = [
    {
        token: process.env.USDC,
        accountWithFunds: "0xf977814e90da44bfa03b6295a0616a897441acec" // BINANCE 8
    },
    {
        token: process.env.WETH,
        accountWithFunds: "0x030ba81f1c18d280636f32af80b9aad02cf0854e" // AAVE WETH
    },
    {
        token: process.env.CVX,
        accountWithFunds: "0xf977814e90da44bfa03b6295a0616a897441acec" // Binance 8
    }
]

//Iterate to impersonate each provider account and transfer the funds to receiver address to test sushi wallet funcionality
const setWalletWithERC20Tokens = async (erc20Factory, receiver) => {
    for(let i = 0; i<tokensToProviders.length;i++) {
        let impersonateAccount = await ethers.getImpersonatedSigner(tokensToProviders[i].accountWithFunds)

        let token = await erc20Factory.attach(tokensToProviders[i].token) 
        let impersonatedTokenInstance = await token.connect(impersonateAccount)
        let tokenBalanceImpersonated = await impersonatedTokenInstance.balanceOf(impersonateAccount.address)
        //Check if it needs some ether to transfer the amounts
        let ethBalance = await ethers.provider.getBalance(impersonateAccount.address)
        
        if(ethBalance == 0) {
            await ethers.provider.send("hardhat_setBalance", [
                impersonateAccount.address,
                "0x23611832414348226068480", // 5 ETH
            ]);
        }
        
        await impersonatedTokenInstance.transfer(receiver, tokenBalanceImpersonated)
    }
}


describe('Sushi Wallet Tests', function () {
    let deployer, outsider
    
    before(async function () {
        [deployer, outsider] = await ethers.getSigners()

        await ethers.provider.send("hardhat_setBalance", [
            deployer.address,
            "0x75557863725914323419136", // 10 ETH
        ]);

        this.erc20 = await ethers.getContractFactory('ERC20', deployer)
        
        this.walletCloneFactory = await (
            await ethers.getContractFactory('SushiWalletFactory', deployer)
        ).deploy(process.env.SUSHI_ROUTER, process.env.MASTER_CHEF_V1, process.env.MASTER_CHEF_V2);

        await this.walletCloneFactory.createWallet()

        this.deployerWalletAddress = await this.walletCloneFactory.userToWallet(deployer.address)

        this.sushiWallets = await ethers.getContractFactory('SushiWallet', deployer)
        //Sushi wallet connected to its owner
        this.deployerSushiWallet = await this.sushiWallets.attach(this.deployerWalletAddress)
        
        await setWalletWithERC20Tokens(this.erc20, this.deployerSushiWallet.address)
        
    })
    
     //Deposit funds
     it('Sushi wallet deposit funds correctly', async function () {
        await this.deployerSushiWallet.deposit({value: ethers.utils.parseEther('1')})
        expect(await ethers.provider.getBalance(this.deployerSushiWallet.address)).to.be.equal(ethers.utils.parseEther('1'))
    })

    //Withdraw funds
    it('Sushi wallet withdraw funds correctly', async function () {
        await this.deployerSushiWallet.withdraw(ethers.utils.parseEther('1'))
        expect(await ethers.provider.getBalance(this.deployerSushiWallet.address)).to.be.equal(0)
    })

    //ETH transfer
    it('Sushi wallet transfer ETH correctly', async function () {
        await this.deployerSushiWallet.deposit({value: ethers.utils.parseEther('1')})
        await this.deployerSushiWallet.transferETHAmount(outsider.address, ethers.utils.parseEther('1'))
        expect(await ethers.provider.getBalance(outsider.address)).to.be.greaterThan(ethers.utils.parseEther('1'))
    })

    //Only owner
    it('Sushi wallet can only be operated by owner (deposit/receive/fallback functions excluded)', async function () {
        await this.deployerSushiWallet.deposit({value: ethers.utils.parseEther('1')})
        let outsiderSushiWalletInstance = await this.deployerSushiWallet.connect(outsider)
        expect(outsiderSushiWalletInstance.withdraw(ethers.utils.parseEther('1'))).to.be.revertedWith("Only the owner can perform this action")
    })

    //Sushi wallet has received funds from impersonated providers correctly (internal test)
    it('Sushi wallet has a positive amount of ERC20 funds', async function () {
        for(let i = 0; i<tokensToProviders.length;i++) {
            let token = await this.erc20.attach(tokensToProviders[i].token) 
            let tokenBalance = await token.balanceOf(this.deployerSushiWallet.address)
            expect(tokenBalance).to.be.greaterThan("0")
        }
    })
    
    //LP and YF on MasterchefV2 pool
    it('Sushi wallet LP and YF in one transaction CVX/WETH (MASCTERCHEF V2)', async function () {
        console.log("Next tests might require a couple of seconds, please wait...")
        let weth = await this.erc20.attach(process.env.WETH) 
        let CVX = await this.erc20.attach(process.env.CVX) 
        this.wethBalance = await weth.balanceOf(this.deployerSushiWallet.address)
        let CVXBalance = await CVX.balanceOf(this.deployerSushiWallet.address)
        let pairAvailableAmount = this.wethBalance.div(2) > CVXBalance ? CVXBalance : this.wethBalance.div(2)
        
        //Transaction that handles Liquidity providing and yield farming
        await this.deployerSushiWallet.executeYieldFarming(
            process.env.CVX,
            process.env.WETH,
            pairAvailableAmount,
            pairAvailableAmount,
            (await ethers.provider.getBlock('latest')).timestamp * 2
        )
    })

    //LP and YF on MasterchefV1 pool
    it('Sushi wallet LP and YF in one transaction USDC/WETH (MASCTERCHEF V1)', async function () {
        let usdc = await this.erc20.attach(process.env.USDC) 
        let usdcBalance = await usdc.balanceOf(this.deployerSushiWallet.address)
         
        //Transaction that handles Liquidity providing and yield farming
        await this.deployerSushiWallet.executeYieldFarming(
            process.env.USDC,
            process.env.WETH,
            usdcBalance,
            this.wethBalance.div(2),
            (await ethers.provider.getBlock('latest')).timestamp * 2
        )

    })

    
    //Additional functionality check on SLP withdrawals to validate SUSHI balances at different moments. The
    //end goal is to test end-to-end wallet functionality.
    //Get logs to see amount of SLP tokens deposited and withdraw that same balance, then validate we received 
    //the correct quantity of SUSHI tokens 
    it('Sushi wallet withdraw from yield farms and retrieve SUSHI (both MASCTERCHEF V1 and V2)', async function () {
        //Set starting block to get logs
        let startingBlockToCheck = (await ethers.provider.getBlock()).number - 1000 // go back a couple blocks to catch events
        let startingBlockToCheckHex = ethers.BigNumber.from(startingBlockToCheck)._hex
        //ethers.js doesnt support checking on multiple addresses at the same time. For event catching, an 
        //alternative is to use web3.js and handle everything with one method. For simplicity, 
        //it is used getLogs() from ethers.js to catch deposits to MasterchefV1 and MaterchefV2.
        let depositLogMasterChefV1 = await ethers.provider.getLogs(
            {
                fromBlock: startingBlockToCheckHex,
                address: process.env.MASTER_CHEF_V1, 
                topics: [
                    ethers.utils.id("Deposit(address,uint256,uint256)"), 
                    ethers.utils.hexZeroPad(this.deployerSushiWallet.address, 32 )
                ]
            }
        )
        let depositLogMasterChefV2 = await ethers.provider.getLogs(
            {
                fromBlock: startingBlockToCheckHex,
                address: process.env.MASTER_CHEF_V2, 
                topics: [
                    ethers.utils.id("Deposit(address,uint256,uint256,address)"),
                    ethers.utils.hexZeroPad(this.deployerSushiWallet.address, 32 )
                ]
            }
        )

        this.sushiERC20 = await this.erc20.attach(process.env.SUSHI)
        //Intial SUSHI balance has to be 0
        let SUSHIBalanceInitial = await this.sushiERC20.balanceOf(this.deployerSushiWallet.address)
        expect(SUSHIBalanceInitial).to.be.equal("0")
        //Dummy test to make sure we received a positive amount of SUSHI tokens after withdrawal from 
        //MasterChefV1
        const amountSLPForUSDCWETH = ethers.BigNumber.from(ethers.utils.hexStripZeros(depositLogMasterChefV1[0].data))
        await this.deployerSushiWallet.withdrawFromYieldFarming(process.env.USDC, process.env.WETH, amountSLPForUSDCWETH)
        let SUSHIBalanceAfterV1Withdrawal = await this.sushiERC20.balanceOf(this.deployerSushiWallet.address)
        expect(SUSHIBalanceAfterV1Withdrawal).to.be.greaterThan("0")
        //Dummy test to make sure we have a greater balance of SUSHI tokens after withdrawal from MasterChefV2
        //Under the hood we are calling withdrawAndHarvest() to "harvest" SUSHI rewards
        const amountSLPForCVXWETH = ethers.BigNumber.from(ethers.utils.hexStripZeros(depositLogMasterChefV2[0].data))
        await this.deployerSushiWallet.withdrawFromYieldFarming(process.env.CVX, process.env.WETH, amountSLPForCVXWETH) 
        this.SUSHIBalanceAfterV2Withdrawal = await this.sushiERC20.balanceOf(this.deployerSushiWallet.address)
        expect(this.SUSHIBalanceAfterV2Withdrawal).to.be.greaterThan(SUSHIBalanceAfterV1Withdrawal)
    })

    it('Sushi wallet withdraw SUSHI funds correctly to owner', async function () {        
        expect(await this.sushiERC20.balanceOf(deployer.address)).to.be.equal(0)
        await this.deployerSushiWallet.withdrawERC20(process.env.SUSHI, this.SUSHIBalanceAfterV2Withdrawal)
        expect(await this.sushiERC20.balanceOf(deployer.address)).to.be.equal(this.SUSHIBalanceAfterV2Withdrawal)
    })
    
})