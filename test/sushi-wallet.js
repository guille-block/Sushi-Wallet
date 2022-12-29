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
        //check if it needs some ether to transfer the amounts
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

    //Only owner
    it('Sushi wallet can only be operated by owner (deposit/receive/fallback functions excluded)', async function () {
        await this.deployerSushiWallet.deposit({value: ethers.utils.parseEther('1')})
        let outsiderSushiWalletInstance = await this.deployerSushiWallet.connect(outsider)

        await ethers.provider.send("hardhat_setBalance", [
            outsider.address,
            "0x1208925819614629174706176", // 10 ETH
        ])

        expect(outsiderSushiWalletInstance.withdraw(ethers.utils.parseEther('1'))).to.be.revertedWith("Only the owner can perform this action")
    })

    //sushi wallet has received funds from impersonated providers correctly (internal test)
    it('Sushi wallet has a positive amount of ERC20 funds', async function () {
        for(let i = 0; i<tokensToProviders.length;i++) {
            let token = await this.erc20.attach(tokensToProviders[i].token) 
            let tokenBalance = await token.balanceOf(this.deployerSushiWallet.address)
            expect(tokenBalance).to.be.greaterThan("0")
        }
    })
})