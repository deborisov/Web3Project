pragma solidity >=0.8.0;

contract Caller{
    address public rpsAddress;

    constructor(address _rpsAddress){
        rpsAddress = _rpsAddress;
    }

    function callDeposit() external payable returns(bool result) {
        (result, ) = payable(rpsAddress).call{value: msg.value}(
            abi.encodeWithSignature("deposit()")
        ); 
        return result;
    }
}