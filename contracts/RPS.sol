pragma solidity >=0.8.0;

contract PRS{
    enum Choice {
        None,
        Rock,
        Paper,
        Scissors
    }

    enum GameState {
        None,
        FirstCommit,
        SecondCommit
    }

    enum GameResult {
        Draw,
        First,
        Second
    }

    struct Game {
        uint stake;
        address firstPlayer;
        address secondPlayer;
        bytes32 firstCommitment;
        bytes32 secondCommitment;
        Choice firstChoice;
        Choice secondChoice;
        GameResult result;
        GameState state;

    }

    event Commit(address gameAddress, address player);
    event Reveal(address gameAddress, address player, Choice choice);
    event Result(address gameAddress, GameResult result);

    mapping (address => uint) public balances;
    mapping (address => Game) public games;
    
    event Received(address, uint);

    modifier hasEnoughEther(uint _stake){
        require(balances[msg.sender] >= _stake * (1 gwei), "Not enough Ether");
        _;
    }

    modifier hasCommitment(bytes32 _commitment){
        require(_commitment != "", "Commitment not provided");
        _;
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

    function startGame(uint stake, address opponent, bytes32 commitment) external hasCommitment(commitment) hasEnoughEther(stake){
        require(opponent != msg.sender, "Can't play with yourself");
        require(games[msg.sender].state == GameState.None, "Game is in incorrent state");
        
        balances[msg.sender] = balances[msg.sender] - stake;
        games[msg.sender].stake = stake;
        games[msg.sender].firstCommitment = commitment;
        games[msg.sender].firstPlayer = msg.sender;
        games[msg.sender].secondPlayer = opponent;
        games[msg.sender].state = GameState.FirstCommit;
        emit Commit(msg.sender, msg.sender);
    }

    function attendGame(address opponent, bytes32 commitment) external hasCommitment(commitment) {
        require(games[opponent].state == GameState.FirstCommit, "Game is in incorrent state");
        require(games[opponent].secondPlayer == msg.sender, "Different opponent for this game");

        uint stake = games[opponent].stake;

        require(stake <= balances[msg.sender], "Not enough Ether");

        balances[msg.sender] = balances[msg.sender] - stake;
        games[opponent].secondCommitment = commitment;
        games[opponent].state = GameState.SecondCommit;
        emit Commit(opponent, msg.sender);
    }

    function revealChoice(Choice choice, bytes32 secret, address gameAddress) external {        
        require(games[gameAddress].state == GameState.SecondCommit, "Game is in incorrent state");                
       
        if (games[gameAddress].firstPlayer == msg.sender){
            require(games[gameAddress].firstCommitment == keccak256(abi.encodePacked(choice, secret)), "problem with hash");
            games[gameAddress].firstChoice = choice;
        } 
        else if (games[gameAddress].secondPlayer == msg.sender){
            require(games[gameAddress].secondCommitment == keccak256(abi.encodePacked(choice, secret)), "problem with hash");
            games[gameAddress].secondChoice = choice;
        } 
        else{
            revert("Invalid game address");
        }
        emit Reveal(gameAddress, msg.sender, choice);
    }

    function endGame(address gameAddress) external returns(GameResult gameResult) {
        require(games[gameAddress].firstChoice != Choice.None && games[gameAddress].secondChoice != Choice.None, "Game has unrevealed choices");

        Choice firstChoice = games[gameAddress].firstChoice;
        Choice secondChoice = games[gameAddress].secondChoice;

        gameResult = GameResult.Draw;

        if (firstChoice == Choice.Rock && secondChoice == Choice.Rock ||
            firstChoice == Choice.Scissors && secondChoice == Choice.Scissors ||
            firstChoice == Choice.Paper && secondChoice == Choice.Paper)
        {
            gameResult = GameResult.First;
        }
        else if (firstChoice == Choice.Rock && secondChoice == Choice.Scissors ||
            firstChoice == Choice.Scissors && secondChoice == Choice.Paper ||
            firstChoice == Choice.Paper && secondChoice == Choice.Rock)
        {
            gameResult = GameResult.First;
        }
        else if (firstChoice == Choice.Rock && secondChoice == Choice.Paper ||
            firstChoice == Choice.Scissors && secondChoice == Choice.Rock ||
            firstChoice == Choice.Paper && secondChoice == Choice.Scissors)
        {
            gameResult = GameResult.Second;
        }
        else{
            revert("Invalid outcome");
        }

        address secondPlayer = games[gameAddress].secondPlayer;
        uint stake = games[gameAddress].stake;

        if(gameResult == GameResult.Draw){
            balances[gameAddress] = balances[gameAddress] + stake;
            balances[gameAddress] = balances[secondPlayer] + stake;
        }
        else if(gameResult == GameResult.First){
            balances[gameAddress] = balances[gameAddress] + stake;
        }
        else if(gameResult == GameResult.Second){
            balances[secondPlayer] = balances[secondPlayer] + stake;
        }

        delete games[gameAddress];

        emit Result(gameAddress, gameResult);
        return gameResult;
    }
}