const Token = artifacts.require('Flexi');
const FlexiStaking = artifacts.require('FlexiCoinStaking');
const { expect, assert } = require('chai');
const { expectEvent } = require('@openzeppelin/test-helpers');

const toWei = _amount => web3.utils.toWei(_amount.toString(), 'ether');
const amount = toWei(1);

contract('Flexi Staking', async ([admin, user1, user2, user3]) => {
    beforeEach(async () => {
        this.token = await Token.new();
        this.contract = await FlexiStaking.new(this.token.address);
        console.log(this.token.address)
    })

    describe('New stake', () => {
        it('should stake new user properly', async () => {
            // approve tokens before staking
            await this.token.approve(this.contract.address, amount, { from: user1 });
            await this.contract.newStake(amount, admin, { from: user1 });
            const result = await this.contract.registered(user1);
            console.log(result)
            expect(result).to.equal(true);
        })

        // it('should not stake new user if stake is less than minimum stake', async () => {
        //     try {
        //         const minimuStakes = (await this.contract.minimumStakeValue()).toString();
        //         await this.contract.newStake();
        //     } catch (error) {
        //         console.log(error.message);
        //         return;
        //     }
        //     assert(false)
        // })
    })
})