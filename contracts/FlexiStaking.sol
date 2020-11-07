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
    uint public stakeholdersCount;
    uint public totalStakes;
    uint private setTime;
    uint public minimumStakeValue;
    uint private rewardToShare;
 
    struct Referrals {
        address[] referredAddresses;    
    }
    modifier validateStake(uint _stake) {
        require(_stake >= minimumStakeValue, "Amount is below minimum stake value.");
        contractAddress.transferFrom(msg.sender, address(this), _stake);
        _;
    }
    
    mapping(address => uint256) private stakes;
    mapping(address => address) public addressThatReferred;
    mapping(address => Referrals) private referral;
    mapping(address => uint) public bonus;
    mapping(address => uint256) private time;
    mapping(address => bool) public registered;

    event NewStake(address indexed stakeholder, address indexed referrer, uint indexed stakes);
    event Stake(address indexed stakeholder, uint indexed stakes);
    event ClaimReward(address indexed stakeholder, uint value);
    event WeeklyRewardShared(uint indexed amount);
    event RemoveStakes(address indexed stakeholder, uint indexed initalStakes, uint indexed currentStakes);
 
    constructor(IERC20 _contractAddress) public {
        contractAddress = _contractAddress;
        stakeholdersCount = 0;
        setTime = 0;
        totalStakes = 0;
        stakingPool = 0;
        rewardToShare = 0;
        minimumStakeValue = 0.1 ether;
        
        stakeholdersCount = stakeholdersCount.add(1);
        stakes[msg.sender] = stakes[msg.sender].add(0);
        registered[msg.sender] = true;
    }
 

    function setReferrer(address _referrer) private {
        require(msg.sender != _referrer, "cannot add your address as your referral");
        require(registered[_referrer], "Referrer is not a stakeholder");

        referral[_referrer].referredAddresses.push(msg.sender);
        addressThatReferred[msg.sender] = _referrer;
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
 
    function newStake(uint _stake, address _referrer) external validateStake(_stake) returns(bool) {
        require(_referrer != address(0), "Referer is zero address");
        require(!registered[msg.sender], "Already a stakeholder, use stake method");
        require(registered[_referrer], "Referrer is not a stakeholder");
        
        registered[msg.sender] = true;
        uint availableForstake = stakingCost(_stake);
        stakes[msg.sender] = availableForstake;
        stakeholdersCount = stakeholdersCount.add(1);
        
        setReferrer(_referrer);
        emit NewStake(msg.sender, _referrer, _stake);
        return true;
    }
 
    function stake(uint _stake) external validateStake(_stake) returns(bool) {
        uint availableForstake = stakingCost(_stake);
        stakes[msg.sender] = stakes[msg.sender].add(availableForstake);
        emit Stake(msg.sender, _stake);
        return true;
    }
 
    function stakeOf(address _stakeholder) external view returns(uint256) {
        return stakes[_stakeholder];
    }
 
    function removeStake(uint _stake) external {
        address _user = msg.sender;
        
        require(registered[_user], "Not a stakeholder");
        require(stakes[_user] > 0, "stakes must be above 0");
        require(stakes[_user] >= _stake, "Amount is greater than current stake");
 
        uint _initialStakes = stakes[_user];
        stakes[_user] = _initialStakes.sub(_stake);
        
        uint _withdrawlCost = _stake.mul(20).div(100);
        stakingPool = stakingPool.add(_withdrawlCost);
        totalStakes = totalStakes.sub(_stake);

        uint _balance = _stake.sub(_withdrawlCost);
        
        contractAddress.transfer(_user, _balance);
        if(stakes[_user] == 0) removeStakeholder();
        emit RemoveStakes(msg.sender, _initialStakes, _balance);
    }
 
    function removeStakeholder() private  {
        address _stakeholder = msg.sender;
        require(registered[_stakeholder], "Not a stakeholder");
        registered[_stakeholder] = false;
    }
 
    function shareWeeklyRewards() external onlyOwner {
        require(block.timestamp > setTime, "wait a week from last call");
        stakingPool = stakingPool.add(rewardToShare);
        setTime = block.timestamp + 7 days;
        rewardToShare = stakingPool.div(2);
        stakingPool = stakingPool.sub(rewardToShare);
        emit WeeklyRewardShared(rewardToShare);
    }
 
    function claimweeklyRewards() external {
        address _user = msg.sender;
        require(registered[_user], "Not a stakeholder");
        require(rewardToShare > 0, "No reward to share at this time");
        require(block.timestamp > time[_user], "wait a week from last call");
        
        time[_user] = block.timestamp + 7 days;
        uint _initialStake = stakes[_user];
        uint _reward = _initialStake.mul(rewardToShare).div(totalStakes);
        rewardToShare = rewardToShare.sub(_reward);
        
        uint referrerFee = _reward.mul(10).div(100); // calculate 10% referral fee
        uint userRewardAfterReferrerFee = _reward.sub(referrerFee);
        stakes[_user] = stakes[_user].add(userRewardAfterReferrerFee); // updates user's balance with the reward
 
        address _referrer = addressThatReferred[_user];
        bonus[_referrer] = bonus[_referrer].add(referrerFee);
        stakes[_referrer] = stakes[_referrer].add(referrerFee); // updates the referrer balance with the stake rewards
        
        emit ClaimReward(msg.sender, userRewardAfterReferrerFee);
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
