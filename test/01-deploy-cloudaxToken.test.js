const { n18, toEther, increaseTimestamp, ONE_DAY } = require("../utils/utils");
const { assert, expect } = require("chai");
const { network, deployments, ethers, getNamedAccounts } = require("hardhat")
const { developmentChains, networkConfig, networks } = require("../helper-hardhat-config")


describe("Cloudax Marketplace Tests", function () {
    let cloudaxMarketplace, deployer, alice, bob, carol;

    beforeEach(async function () {
        [deployer, alice, bob, carol] = await ethers.getSigners() // could also do with getNamedAccounts

        const CloudaxMarketplace = await ethers.getContractFactory("Cloudax");
        cloudaxMarketplace = await CloudaxMarketplace.deploy("CloudaxNftMarketplace");
        await cloudaxMarketplace.deployed();
        console.log(cloudaxMarketplace.address)

        // const price = n18("2")
        // const royaltyBPS = "2"

        describe("#deployment", function () {
            it("Create an item", async function () {
                const price = n18("2")
                const royaltyBPS = 2
                const quantity = 20

                expect(await cloudaxMarketplace.createItem(deployer, price, quantity, royaltyBPS)).to.emit(
                    "ItemCreate"
                )
            });
        });
    })
});