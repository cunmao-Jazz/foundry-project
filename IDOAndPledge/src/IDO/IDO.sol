// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IMintableToken is IERC20 {
    function mint(address to, uint256 amount) external;
}

contract IDOPresale is ReentrancyGuard, Ownable(msg.sender) {
    enum PresaleState { NotStarted, Active, Ended }

    IMintableToken public token;
    uint256 public fundraisingGoal;
    uint256 public fundraisingCap;
    uint256 public startTime; 
    uint256 public endTime;
    
    uint256 public totalRaised;
    bool public isWithdrawn;

    mapping(address => uint256) public contributions;
    mapping(address => uint256) public tokensPurchased;

    uint256 public minContribution;
    uint256 public maxContribution;

    uint256 public totalTokenSupply;

    event PresaleStarted(
        address indexed token,
        uint256 goal,
        uint256 cap,
        uint256 minContribution,
        uint256 maxContribution,
        uint256 totalTokenSupply,
        uint256 startTime,
        uint256 endTime
    );
    event TokensPurchased(address indexed buyer, uint256 amount, uint256 ethSpent);
    event RefundClaimed(address indexed user, uint256 amount);
    event TokensClaimed(address indexed user, uint256 amount);
    event FundsWithdrawn(address indexed owner, uint256 amount);

    function startPresale(
        address _token,
        uint256 _fundraisingGoal,
        uint256 _fundraisingCap,
        uint256 _minContribution,
        uint256 _maxContribution,
        uint256 _totalTokenSupply,
        uint256 _duration
    ) external onlyOwner {
        require(address(token) == address(0),"Presale already started");
        require(address(_token) != address(0),"Invalid token address");
        require(_fundraisingGoal > 0,"Fundraising goal must be greater than 0");
        require(_fundraisingCap >= _fundraisingGoal,"Cap must be >= goal");
        require(_duration > 0, "Duration must be > 0");
        require(_minContribution > 0, "Minimum contribution must be > 0");
        require(_maxContribution >= _minContribution, "Max contribution must be >= min contribution");
        require(_totalTokenSupply > 0,"Total token supply must be > 0");

        token = IMintableToken(_token);
        fundraisingGoal = _fundraisingGoal;
        fundraisingCap = _fundraisingCap;
        minContribution = _minContribution;
        maxContribution = _maxContribution;
        totalTokenSupply = _totalTokenSupply;
        startTime = block.timestamp;
        endTime = block.timestamp + _duration;

        emit PresaleStarted(
            _token,
            _fundraisingGoal,
            _fundraisingCap,
            _minContribution,
            _maxContribution,
            _totalTokenSupply,
            startTime,
            endTime
    );

    }

    function getPresaleState() public view returns(PresaleState) {
        if (block.timestamp < startTime) {
            return PresaleState.NotStarted;
        } else if (block.timestamp >= startTime && block.timestamp <= endTime) {
            return PresaleState.Active;
        } else {
            return PresaleState.Ended;
        }
    }

    function buyTokens() public payable nonReentrant {
        PresaleState state = getPresaleState();
        require(state == PresaleState.Active,"Presale is not active");
        require(msg.value >= minContribution,"Contribution below minimum limit");
        require(contributions[msg.sender] + msg.value <= maxContribution, "Contribution exceeds maximum limit");
        require(totalRaised + msg.value <= fundraisingCap, "Exceeds fundraising cap");

        contributions[msg.sender] += msg.value;
        totalRaised += msg.value;
        emit TokensPurchased(msg.sender, 0, msg.value);

    }

    function claimRefund() external nonReentrant{
        PresaleState state = getPresaleState();
        require(state == PresaleState.Ended,"Presale not ended");
        require(totalRaised < fundraisingGoal, "Fundraising goal reached");
        uint256 contributed = contributions[msg.sender];
        require(contributed > 0, "No contributions to refund");

        contributions[msg.sender] = 0;
        payable(msg.sender).transfer(contributed);

        emit RefundClaimed(msg.sender, contributed);
    }

    function claimTokens() external nonReentrant {
        PresaleState state = getPresaleState();
        require(state == PresaleState.Ended, "Presale not ended");
        require(totalRaised >= fundraisingGoal, "Fundraising goal not reached");

        uint256 tokens = (totalTokenSupply * contributions[msg.sender]) / totalRaised;
        require(tokens > 0, "No tokens to claim");

        contributions[msg.sender] = 0;
        tokensPurchased[msg.sender] += tokens;
        token.mint(msg.sender, tokens);

        emit TokensClaimed(msg.sender, tokens);
    }

    function withdrawFunds() external onlyOwner nonReentrant {
        PresaleState state = getPresaleState();
        require(state == PresaleState.Ended, "Presale not ended");
        require(totalRaised >= fundraisingGoal, "Fundraising goal not reached");
        require(!isWithdrawn, "Funds already withdrawn");

        isWithdrawn = true;
        payable(owner()).transfer(totalRaised);

        emit FundsWithdrawn(owner(), totalRaised);
    }

    receive() external payable {
        buyTokens();
    }

    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        require(tokenAddress != address(token), "Cannot recover presale token");
        IERC20(tokenAddress).transfer(owner(), tokenAmount);
    }
}
