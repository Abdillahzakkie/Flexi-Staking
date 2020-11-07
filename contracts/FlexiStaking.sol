// SPDX-License-Identifier: MIT
pragma solidity >=0.4.0 <0.8.0;
 
abstract contract Context {
    function _msgSender() internal view virtual returns (address payable) {
        return msg.sender;
    }
 
    function _msgData() internal view virtual returns (bytes memory) {
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}
 
contract Ownable is Context {
    address private _owner;
 
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
 
    constructor() public {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }
 
    function owner() public view returns (address) {
        return _owner;
    }
 
    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
 
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
 
    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}
 
library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
 
        return c;
    }
 
 
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }
 
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
 
        return c;
    }
 
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
 
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
 
        return c;
    }
 
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }
 
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
 
        return c;
    }
 
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }
 
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}
 
interface IERC20 {
    function totalSupply() external view returns (uint256);
 
    function balanceOf(address account) external view returns (uint256);
 
    function transfer(address recipient, uint256 amount) external returns (bool);
 
    function allowance(address owner, address spender) external view returns (uint256);
 
    function approve(address spender, uint256 amount) external returns (bool);
 
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
 
    event Transfer(address indexed from, address indexed to, uint256 value);
 
    event Approval(address indexed owner, address indexed spender, uint256 value);
}
 
 
contract FlexiCoinStaking is Ownable {
 
    //initializing safe computations
    using SafeMath for uint;
 
    IERC20 public contractAddress;
    uint public stakingPool;
    uint public stakeholdersIndex;
    uint public totalStakes;
    uint private setTime;
    uint public minimumStakeValue;
 
    uint rewardToShare;
 
    struct Referrals {
        uint referralcount;
        address[] referredAddresses;    
    }
 
    struct ReferralBonus {
        uint uplineProfit;
    }
 
    struct Stakeholder {
         uint id;
         uint stakes;
    }
 
    modifier validateStake(uint _stake) {
        require(_stake >= minimumStakeValue, "Amount is below minimum stake value.");
        require(contractAddress.balanceOf(msg.sender) >= _stake, "Must have enough balance to stake");
        require(
            contractAddress.allowance(msg.sender, address(this)) >= _stake, 
            "Must approve tokens before staking"
        );
        contractAddress.transferFrom(msg.sender, address(this), _stake);
        _;
    }
 
    mapping(address => Stakeholder) public stakeholders;
    mapping(uint => address) public stakeholdersReverseMapping;
    mapping(address => uint256) private stakes;
    mapping(address => address) public addressThatReferred;
    mapping(address => Referrals) private referral;
    mapping(address => ReferralBonus) public bonus;
    mapping(address => uint256) private time;
    mapping(address => bool) public registered;
 
    constructor(IERC20 _contractAddress) public {
        contractAddress = _contractAddress;
        stakeholdersIndex = 0;
        setTime = 0;
        totalStakes = 0;
        stakingPool = 0;
        rewardToShare = 0;
        minimumStakeValue = 0.1 ether;
 
 
        // Set the deployer as a stakeholder
        stakeholders[msg.sender].id = stakeholdersIndex;
        stakeholdersReverseMapping[stakeholdersIndex] = msg.sender;
        stakeholdersIndex = stakeholdersIndex.add(1);
        stakes[msg.sender] = stakes[msg.sender].add(0);
        registered[msg.sender] = true;
    }
 

    function addReferee(address _refereeAddress) private {
        require(msg.sender != _refereeAddress, "cannot add your address as your referral");
        require(registered[_refereeAddress], "Referree is not a stakeholder");
 
        referral[_refereeAddress].referralcount =  referral[_refereeAddress].referralcount.add(1);   
        referral[_refereeAddress].referredAddresses.push(msg.sender);
        addressThatReferred[msg.sender] = _refereeAddress;
        registered[msg.sender] = true;
    }
 
    /*returns stakeholders Referred List
    */
    function stakeholdersReferredList(address stakeholderAddress) view external returns(address[] memory){
      return referral[stakeholderAddress].referredAddresses;
    }
 
    function balance(address addr) public view returns(uint) {
        return contractAddress.balanceOf(addr);
    }
 
    function approvedTokenBalance(address _sender) public view returns(uint) {
        return contractAddress.allowance(_sender, address(this));
    }
 
    function newStake(uint _stake, address referree) external validateStake(_stake) returns(bool) {
        require(referree != address(0), "Referee is zero address");
        require(!registered[msg.sender], "Already a stakeholder, use stake method");
        
        addStakeholder(); //add user to stakeholder
        addReferee(referree);
        
        uint availableForstake = stakingCost(_stake);
        stakes[msg.sender] = availableForstake;
        return true;
    }
 
    function stake(uint _stake) external validateStake(_stake) returns(bool) {
        uint availableForstake = stakingCost(_stake);
        stakes[msg.sender] = stakes[msg.sender].add(availableForstake);
        return true;
    }
 
    function stakeOf(address _stakeholder) external view returns(uint256) {
        return stakes[_stakeholder];
    }
 
    function removeStake(uint _stake) external {
        address _user = msg.sender;
        
        require(registered[_user], "Not a stakeholder");
        require(stakes[_user] > 0, 'stakes must be above 0');
        require(stakes[_user] >= _stake, "Amount is greater than current stake");
 
        uint _balance = stakes[_user];
        stakes[_user] = _balance.sub(_stake);
        
        totalStakes = totalStakes.sub(_stake);
        uint _withdrawlCost = _stake.mul(20).div(100);
        stakingPool = stakingPool.add(_withdrawlCost);
        _balance = _balance.sub(_withdrawlCost);
        
        contractAddress.transfer(_user, _balance);
        if(stakes[_user] == 0) removeStakeholder();
    }
 
    function addStakeholder() private {
        address _stakeholder = msg.sender;
        require(!registered[_stakeholder], "Already a stakeholder");    
        stakeholders[_stakeholder].id = stakeholdersIndex;
        stakeholdersReverseMapping[stakeholdersIndex] = _stakeholder;
        stakeholdersIndex = stakeholdersIndex.add(1);
    }
 
    function removeStakeholder() private  {
        address _stakeholder = msg.sender;
        require(registered[_stakeholder], "Not a stakeholder");
 
        // get id of the stakeholders to be deleted
        uint swappableId = stakeholders[_stakeholder].id;
 
        // swap the stakeholders info and update admins mapping
        // get the last stakeholdersReverseMapping address for swapping
        address swappableAddress = stakeholdersReverseMapping[stakeholdersIndex -1];
 
        // swap the stakeholdersReverseMapping and then reduce stakeholder index
        stakeholdersReverseMapping[swappableId] = stakeholdersReverseMapping[stakeholdersIndex - 1];
 
        // also remap the stakeholder id
        stakeholders[swappableAddress].id = swappableId;
 
        // delete and reduce admin index 
        delete(stakeholders[_stakeholder]);
        delete(stakeholdersReverseMapping[stakeholdersIndex - 1]);
        stakeholdersIndex = stakeholdersIndex.sub(1);
        registered[msg.sender] = false;
    }
 
    function shareWeeklyRewards() external onlyOwner {
        require(block.timestamp > setTime, 'wait a week from last call');
        stakingPool = stakingPool.add(rewardToShare);
        setTime = block.timestamp + 7 days;
        rewardToShare = stakingPool.div(2);
        stakingPool = stakingPool.sub(rewardToShare);
    }
 
    function claimweeklyRewards() external {
        address _user = msg.sender;
        
        require(registered[_user], 'address does not belong to a stakeholders');
        require(rewardToShare > 0, 'no reward to share at this time');
        require(block.timestamp > time[_user], 'can only call this function once a week');
        
        time[_user] = block.timestamp + 7 days;
        uint _initialStake = stakes[_user];
        uint _reward = _initialStake.mul(rewardToShare).div(totalStakes);
        
        rewardToShare = rewardToShare.sub(_reward);
 
        uint referralFee = _reward.mul(10).div(100);
        uint userRewardAfterReferralFee = _reward.sub(referralFee);
        
        stakes[_user] = stakes[_user].add(userRewardAfterReferralFee); // updates user's balance with the reward
 
        address _referral = addressThatReferred[_user];
        bonus[_referral].uplineProfit = bonus[_referral].uplineProfit.add(referralFee);
        stakes[_referral] = stakes[_referral].add(referralFee); // updates the referral balance with the stake rewards
    }

 
    function stakingCost(uint256 _stake) private returns(uint availableForstake) {
        uint _rand = randNumber();
        uint _stakeCost =  _stake.mul(_rand).div(100);
        availableForstake = _stake.sub(_stakeCost);
        
        stakingPool = stakingPool.add(_stakeCost); // add to staking cost to the pool
        totalStakes = totalStakes.add(availableForstake); // update the totalstakes
        
        return availableForstake;
    }
 
    function randNumber() private view returns(uint _rand) {
        uint8[12] memory range = [9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20];
        _rand = uint(keccak256(abi.encode(block.timestamp, block.difficulty, msg.sender))) % 12;
        return range[_rand];
    }
 
}