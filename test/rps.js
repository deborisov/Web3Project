//Тесты на каменцы

const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("InterContract", function(){
        let rps;
        let account;
        let alice;

        beforeEach(async () => {
            [account, alice] = await ethers.getSigners();
            const RPScontractFactory = await ethers.getContractFactory("PRS");
            rps = await RPScontractFactory.deploy();
            await rps.deployed();
        });

        describe("RPS tests", () => {
            it("should change deposit", async () => {
                const result = await rps.connect(account).deposit({ value: ethers.utils.parseEther("1") });
                expect(await rps.balances(account.address)).to.equal(ethers.utils.parseEther("1"));
            });
            it("should throw error deposit", async () => {
                await expect(rps.startGame(ethers.utils.parseEther("1"), alice.address, "0x63616e6469646174653100000000000000000000000000000000000000000000"))
                    .to.be.revertedWith('Not enough Ether');
            });
            it("should start game", async () => {
                await rps.connect(account).deposit({ value: ethers.utils.parseEther("1") });
                await rps.startGame(1, alice.address, "0x63616e6469646174653100000000000000000000000000000000000000000000");
                await expect((await rps.games(account.address)).state).to.equal(1)
            });
            it("should attend game", async () => {
                await rps.connect(account).deposit({ value: ethers.utils.parseEther("1") });
                await rps.connect(alice).deposit({ value: ethers.utils.parseEther("1") });
                await rps.connect(account).startGame(1, alice.address, "0x63616e6469646174653100000000000000000000000000000000000000000000");
                await rps.connect(alice).attendGame(account.address, "0x63616e6469646174653100000000000000000000000000000000000000000000");
                await expect((await rps.games(account.address)).state).to.equal(2)
            });
        });
});