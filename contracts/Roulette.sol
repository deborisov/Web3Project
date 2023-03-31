pragma solidity >=0.8.0;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract Roulette is VRFConsumerBaseV2{
    VRFCoordinatorV2Interface COORDINATOR;
    address s_owner;

    uint64 s_subscriptionId = 11017;
    address vrfCoordinator = 0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D;
    bytes32 keyHash = 0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15;
    uint32 callbackGasLimit = 200000;
    uint16 requestConfirmations = 3;
    uint32 public numWords =  1;

    mapping (address => uint) public balances;
    mapping (address => Game) public games;
    mapping(uint256 => address) private s_rollers;

    enum GameState {
        None,
        PlayerCommit,
        BallRolled,
        Ended
    }

    enum StakeType {
        None,
        Odd,
        Even,
        Number
    }

    enum GameResult {
        None,
        Win,
        Lose
    }

    struct Game {
        uint stake;
        bytes32 playerCommitment;
        uint256 playerChoice;
        GameResult result;
        GameState state;
        uint256 requestId;
        uint256 rouletteValue;
        StakeType stakeType;
        uint256 number;
    }

    event BallRolled(uint256 requestId, address roller);
    event BallLanded(uint256 indexed requestId, uint256 indexed result);
    event Commit(address gameAddress, address player);
    event Reveal(address gameAddress, address player, uint256 choice);
    event Result(address gameAddress, GameResult result);
    event Received(address, uint);

    constructor(uint64 subscriptionId) VRFConsumerBaseV2(vrfCoordinator) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_owner = msg.sender;
        s_subscriptionId = subscriptionId;
    }
    
    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }
    
    function withdraw() external {
        uint playerBalance = balances[msg.sender];
        require(playerBalance > 0);
        
        balances[msg.sender] = 0;
        (bool success, ) = address(msg.sender).call{ value: playerBalance }("");
        require(success, "Failed to send Ether");
    }

    function startGame(uint stake, bytes32 commitment, StakeType stakeType, uint number) external hasCommitment(commitment) hasEnoughEther(stake) hasEnoughEtherInTheBank(stake, stakeType) hasValidStakeType(stakeType) hasValidStakeNumber(number){
        require(games[msg.sender].state == GameState.None || games[msg.sender].state == GameState.Ended, "Game is in incorrent state");
        
        balances[msg.sender] = balances[msg.sender] - stake * (1 gwei);
        if (stakeType == StakeType.Number){
            balances[s_owner] = balances[s_owner] - stake * (35 gwei);
        }
        else
        {
            balances[s_owner] = balances[s_owner] - stake * (1 gwei);
        }
        games[msg.sender].stake = stake;
        games[msg.sender].playerCommitment = commitment;
        games[msg.sender].state = GameState.PlayerCommit;
        games[msg.sender].stakeType = stakeType;
        games[msg.sender].number = number;
        uint256 requestId = COORDINATOR.requestRandomWords(
            keyHash,
            s_subscriptionId,
            requestConfirmations,
            callbackGasLimit,
            numWords
        );

        games[msg.sender].requestId = requestId;
        s_rollers[requestId] = msg.sender;

        emit BallRolled(requestId, msg.sender);
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        uint256 rouletteValue = randomWords[0];

        games[s_rollers[requestId]].rouletteValue = rouletteValue;
        games[s_rollers[requestId]].state = GameState.BallRolled;

        emit BallLanded(requestId, rouletteValue);
    }

    function revealChoice(uint256 number) external {        
        require(games[msg.sender].state == GameState.BallRolled, "Game is in incorrent state");                
       
        require(games[msg.sender].playerCommitment == keccak256(abi.encodePacked(number, msg.sender)), "Problem with hash");
        games[msg.sender].playerChoice = number;

        uint256 result = (number ^ games[msg.sender].rouletteValue) % 37;
        uint stake = games[msg.sender].stake;
        if (games[msg.sender].stakeType == StakeType.Number)
        {
            if (result == games[msg.sender].number)
            {
                games[msg.sender].result = GameResult.Win;
                balances[msg.sender] = balances[msg.sender] + stake * (36 gwei);
            }
            else
            {
                games[msg.sender].result = GameResult.Lose;
                balances[s_owner] = balances[s_owner] + stake * (36 gwei);
            }
        }
        if (games[msg.sender].stakeType == StakeType.Odd)
        {
            if (result != 0 && result % 2 == 1)
            {
                games[msg.sender].result = GameResult.Win;
                balances[msg.sender] = balances[msg.sender] + stake * (2 gwei);
            }
            else
            {
                games[msg.sender].result = GameResult.Lose;
                balances[s_owner] = balances[s_owner] + stake * (2 gwei);
            }
        }
        if (games[msg.sender].stakeType == StakeType.Even)
        {
            if (result != 0 && result % 2 == 0)
            {
                games[msg.sender].result = GameResult.Win;
                balances[msg.sender] = balances[msg.sender] + stake * (2 gwei);
            }
            else
            {
                games[msg.sender].result = GameResult.Lose;
                balances[s_owner] = balances[s_owner] + stake * (2 gwei);
            }
        }

        emit Reveal(s_owner, msg.sender, result);
    }

    modifier hasEnoughEther(uint _stake){
        require(balances[msg.sender] >= _stake * (1 gwei), "Not enough Ether");
        _;
    }

    modifier hasEnoughEtherInTheBank(uint _stake, StakeType stakeType){
        if (stakeType == StakeType.Number)
        {
            require(balances[s_owner] >= _stake * (1 gwei), "Not enough Ether in the bank");
        }
        else {
            require(balances[s_owner] >= _stake * (35 gwei), "Not enough Ether in the bank");
        }
        _;
    }

    modifier hasCommitment(bytes32 _commitment){
        require(_commitment != "", "Commitment not provided");
        _;
    }

    modifier hasValidStakeType(StakeType _stakeType){
        require(_stakeType != StakeType.None, "Invalid stake type");
        _;
    }

    modifier hasValidStakeNumber(uint256 number){
        require(number >= 0 && number <= 36, "Invalid number");
        _;
    }
}