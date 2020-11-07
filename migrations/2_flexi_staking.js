const FlexiCoin = artifacts.require('Flexi');
const FlexiStaking = artifacts.require('FlexiCoinStaking');


module.exports = async (deployer, network, accounts) => {
    const flexiToken = await deployer.deploy(FlexiCoin);
    await deployer.deploy(FlexiStaking, flexiToken.address);
}