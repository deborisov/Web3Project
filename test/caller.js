//Тесты на межконтрактное взаимодействие

const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("InterContract", function(){
        let caller;
        let rps;
        let account;

        beforeEach(async () => {
            [account] = await ethers.getSigners();
            const RPScontractFactory = await ethers.getContractFactory("PRS");
            rps = await RPScontractFactory.deploy();
            await rps.deployed();
           
            const callerContractFactory = await ethers.getContractFactory("Caller");
            caller = await callerContractFactory.deploy(rps.address);
            await caller.deployed();
        });

        describe("Caller tests", () => {
            it("should change values", async () => {
                const result = await caller.connect(account).callDeposit({ value: ethers.utils.parseEther("1") });
                expect(await rps.balances(caller.address)).to.equal(ethers.utils.parseEther("1"));
            });
        });
});