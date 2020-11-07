const Flexi = artifacts.require('Flexi');
const { expect, assert } = require('chai');
const { expectEvent } = require('@openzeppelin/test-helpers');

const toWei = _amount => web3.utils.toWei(_amount.toString(), 'ether');
const amount = toWei(100);

contract('Flexi coin', async ([admin, user1, user2]) => {
    beforeEach(async () => {
        this.contract = await Flexi.new();
    })

    it('should deploy token correctly', async () => {
        expect(this.contract._address).does.not.equal(null)
    })

    it('should set the total supply of tokens to be 1000 FlexiCoin', async () => {
        const totalSupply = await this.contract.totalSupply();
        expect(totalSupply.toString()).to.equal(toWei(1000))
    })

    it('should set the balance of the admin to 1000 FlexiCoin', async () => {
        const balanceOfAdmin = await this.contract.balanceOf(admin);
        expect(balanceOfAdmin.toString()).to.equal(toWei(1000));
    })

    describe('Approve', async () => {
        it('should approve tokens correctly', async () => {
            await this.contract.approve(user1, amount, { from: admin });
            const approvedBalance = await this.contract.allowance(admin, user1);
            expect(approvedBalance.toString()).to.equal(amount);
        })

        it('new allowance should override existing allowance', async () => {
            await this.contract.approve(user1, amount, { from: admin });
            await this.contract.approve(user1, toWei(150), { from: admin });
            const approvedBalance = await this.contract.allowance(admin, user1);
            expect(approvedBalance.toString()).to.equal(toWei(150));
        })

        it('should emit approval event', async () => {
            const reciept = await this.contract.approve(user1, amount, { from: admin });
            expectEvent(reciept, 'Approval', { owner: admin, spender: user1, value: amount })
        })
    })

    describe('TransferFrom', async () => {
        it('should transfer allowance to spender', async () => {
            await this.contract.approve(user1, amount, { from: admin });
            const previousBalance = await this.contract.balanceOf(user1);
            let allowance = await this.contract.allowance(admin, user1);
            await this.contract.transferFrom(admin, user1, allowance.toString(), { from: user1 });
            const currentBalance = await this.contract.balanceOf(user1);
            allowance = await this.contract.allowance(admin, user1);
            expect(allowance.toString()).to.equal(toWei(0));
            assert.notEqual(Number(previousBalance.toString()), Number(currentBalance.toString()));
        })

        it("should not transfer allowance if giver's balance is less than tha allowance", async () => {
            try {
                await this.contract.approve(user2, amount, { from: user1 });
                await this.contract.transferFrom(user1, user2, amount, { from: user2 });
            } catch (error) {
                assert(error.message.includes("SafeMath: subtraction overflow"));
                return;
            }
            assert(false);
        })

        it('should emit transfer event', async () => {
            await this.contract.approve(user1, amount, { from: admin });
            const reciept = await this.contract.transferFrom(admin, user1, amount, { from: user1 });
            expectEvent(reciept, 'Transfer', { from: admin, to: user1, value: amount });
        })
    })

    describe('Decrease allowance', async () => {
        it('should decrease the allowance of the spender', async () => {
            await this.contract.approve(user1, amount, { from: admin });
            const oldAllowance = (await this.contract.allowance(admin, user1)).toString();
            await this.contract.decreaseAllowance(user1, toWei(10), { from: admin });
            const newAllowance = (await this.contract.allowance(admin, user1)).toString();
            assert.notEqual(Number(oldAllowance) < Number(newAllowance))
        })

        it('should emit approval event', async () => {
            await this.contract.approve(user1, amount, { from: admin });
            const reciept = await this.contract.decreaseAllowance(user1, toWei(10), { from: admin });
            expectEvent(reciept, 'Approval', { owner: admin, spender: user1, value: toWei(90) })
        })
    })

    describe('Burn', async () => {
        it('should burn token', async () => {
            await this.contract.burn(toWei(250), { from: admin });

            await this.contract.transfer(user1, toWei(100), { from: admin })
            const previousBalance = await this.contract.balanceOf(user1);
            expect(previousBalance.toString()).to.equal(toWei(100));
        })
    })


    describe('Increase allowance', async () => {
        it('should increse the allowance of the spender', async () => {
            await this.contract.approve(user1, amount, { from: admin });
            const oldAllowance = (await this.contract.allowance(admin, user1)).toString();
            await this.contract.increaseAllowance(user1, toWei(10), { from: admin });
            const newAllowance = (await this.contract.allowance(admin, user1)).toString();
            assert.notEqual(Number(oldAllowance) < Number(newAllowance))
        })

        it('should emit approval event', async () => {
            await this.contract.approve(user1, amount, { from: admin });
            const reciept = await this.contract.increaseAllowance(user1, toWei(10), { from: admin });
            expectEvent(reciept, 'Approval', { owner: admin, spender: user1, value: toWei(110) })
        })
    })

    describe('Transfer', async () => {
        it('should transfer tokens to a user', async () => {
            const beforeTransfer = (await this.contract.balanceOf(user1)).toString();
            await this.contract.transfer(user1, amount, { from: admin });
            const afterTransfer = (await this.contract.balanceOf(user1)).toString();
            assert.notEqual(beforeTransfer, afterTransfer);
        })

        it("should not transfer tokens if user's balance is less than the transfer amount", async () => {
            try {
                await this.contract.transfer(user2, amount, { from: user1 });
            } catch (error) {
                assert(error.message.includes("SafeMath: subtraction overflow"));
                return;
            }
            assert(false);
        })

        it('should burn 0 - 9% from the amount of tokens to transfer', async () => {
            const balanceBeforeTransfer = (await this.contract.balanceOf(user1)).toString();
            await this.contract.transfer(user1, amount, { from: admin });
            const balanceAfterTransfer = (await this.contract.balanceOf(user1)).toString();
            expect(balanceBeforeTransfer).to.equal('0');
            assert(Number(balanceBeforeTransfer) + Number(100) <= balanceAfterTransfer);
        })
    })


})