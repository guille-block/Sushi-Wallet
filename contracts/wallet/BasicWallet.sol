pragma solidity >=0.8.0;

contract BasicWallet {
    address public owner;
    uint private balance;

   modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can perform this action");
        _;
    }

    function initWallet() internal {
        owner = tx.origin;
        balance = 0;
    }

    function deposit() external payable {
        require(msg.value > 0, "Cannot deposit zero or negative value.");
        balance += msg.value;
    }

    function withdraw(uint amount) external onlyOwner {
        require(msg.sender == owner, "Only owner can withdraw from the wallet.");
        require(amount > 0, "Cannot withdraw zero or negative value.");
        require(amount <= balance, "Insufficient balance.");
        payable(msg.sender).transfer(amount);
        balance -= amount;
    }

    function transferETHAmount(address to, uint256 amount) external onlyOwner {
        require(msg.sender == owner, "Only owner can transfer funds from the wallet.");
        require(amount > 0, "Cannot withdraw zero or negative value.");
        require(amount <= balance, "Insufficient balance.");
        payable(to).transfer(amount); // transfer instead of a call to only forward 21000 units of gas
        balance -= amount;
    }

    function getBalance() public view returns (uint) {
        return balance;
    }

    receive() external payable {
        balance += msg.value;
    }

    fallback() external payable {
        balance += msg.value;
    }
}