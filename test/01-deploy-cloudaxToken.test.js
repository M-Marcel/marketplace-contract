const { n18, toEther, increaseTimestamp, ONE_DAY } = require("../utils/utils");
const { assert, expect } = require("chai");

const { network, deployments, ethers, getNamedAccounts } = require("hardhat")
const { developmentChains, networkConfig, networks } = require("../helper-hardhat-config")


// !developmentChains.includes(network.name)
//     ? describe.skip
//     : 
describe("Cloudax LauncPad Tests", function () {
    let cloudax, deployer, alice, bob, carol;

    beforeEach(async function () {
        [deployer, alice, bob, carol] = await ethers.getSigners() // could also do with getNamedAccounts

        // await deployments.fixture(["all"])
        // cloudax = await ethers.getContract("Cloudax")
        // const BusdToken = await ethers.getContractFactory("Cloudax");
        // cloudax = await BusdToken.deploy("Cloudax");
        // await cloudax.deployed();

        const Cloudax = await ethers.getContractFactory("Cloudax");
        cloudax = await Cloudax.deploy("Cloudax");
        await cloudax.deployed();
        console.log(cloudax.address)


        //     await cloudax.setTradingEnabled(1)
        //     await busdToken.transfer(accounts[1].address, n18("300000"));
        //     await busdToken.transfer(accounts[2].address, n18("20000"));
        //     await cloudax.transfer(accounts[1].address, n18("3000"));
        //     await cloudax.transfer(accounts[2].address, n18("2000"));
        // });

        describe("#deployment", function () {
            it("should deploy successfully", async function () {
                // assert.isDefined(cloudax.address);
                // return assert.notEqual(cloudax.address, "0x0000000000000000000000000000000");
                console.log(cloudax.address)
                await cloudax.transfer(alice.address, n18("3000"));
                const alice = cloudax.balanceOf(alice.address)
                expect(alice).to.equal(n18("0"))
            });
        });
    })
});