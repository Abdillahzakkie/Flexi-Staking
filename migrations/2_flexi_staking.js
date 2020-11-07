const FlexiCoin = artifacts.require('Flexi');
const FlexiStaking = artifacts.require('FlexiCoinStaking');


module.exports = async (deployer) => {
    await deployer.deploy(FlexiCoin);
    await deployer.deploy(FlexiStaking, FlexiCoin.address);
}