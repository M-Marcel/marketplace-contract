const { ethers } = require("hardhat")
// const { ethers } = require("ethers");

const UINT_MAX =
    "115792089237316195423570985008687907853269984665640564039457584007913129639935";
const ONE_DAY = 86400;

function n18(amount) {
    // return web3.utils.toWei(amount, "ether");
    return ethers.utils.parseEther(amount)
}

function toEther(amount) {
    // return web3.utils.fromWei(amount);
    return ethers.utils.formatEther(amount);
}

function etherBalance(account) {
    return new Promise((resolve, reject) => {
        // web3.eth.getBalance(account, (error, result) => {
        ethers.getBalance(account, (error, result) => {
            if (error) {
                return reject(error);
            }
            return resolve(result);
        });
    });
}

function isTestnet(network) {
    return (network === "development" || network === "ganache_gui" || network.includes("testnet"));
}

const asyncMine = async () => {
    return new Promise((resolve, reject) => {
        web3.currentProvider.send({
            jsonrpc: "2.0",
            method: "evm_mine",
            id: new Date().getTime()
        }, (error, result) => {
            if (error) {
                return reject(error);
            }
            return resolve(result);
        });
    });
};


function increaseTimestamp(web3, increase) {
    return new Promise((resolve, reject) => {
        web3.currentProvider.send({
            method: "evm_increaseTime",
            params: [increase],
            jsonrpc: "2.0",
            id: new Date().getTime()
        }, (error, result) => {
            if (error) {
                return reject(error);
            }
            return asyncMine().then(() => resolve(result));
        });
    });
}


module.exports = {
    n18,
    increaseTimestamp,
    UINT_MAX,
    ONE_DAY,
    isTestnet,
    toEther,
    etherBalance
};