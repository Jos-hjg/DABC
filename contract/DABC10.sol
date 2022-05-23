// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.7.0 <0.9.0;

import "./DABC10Interface.sol";

contract DABC10 is DABC10Interface {

    uint256 constant private MAX_UINT256 = 2**256 - 1;
    uint constant public winTime = 7 * 60;         //获取本金+利息时间（单位：秒）
    uint256 constant public eachMinedMinCount = 1e17; //单轮最小
    uint256 constant public eachMinedMaxCount = 10e18; //单轮最大
    uint public rate = 106;             //利率，例：106，表示106%
    uint public ZTRate = 3;           //直推利息，3%
    uint public Per = 100;             //消耗比率：1 BNB : 100 DABC
    uint constant public SpanMin = 1 * 30; //第二轮投入开始时间(单位：秒)
    uint constant public SpanMax = 7 * 60; //第二轮投入结束时间(单位：秒)
    uint256 constant public Multiple = 1e17;    //投入倍数
    uint constant public InvalidTimesLimit = 2;    //无效单次数限制
    uint256 constant public OOD = 15 * 60;   //15天没有再质押则拉黑名单（测试：15分钟）

    string public name = 'DABC';    
    string public constant symbol = 'DABC';               
    uint8 public constant decimals = 18;                
    uint256 public totalSupply;
    uint256 public total;   

    address admin;
    address matemask_account1 = 0x821b121D544cAb0a4F4d0ED2F1c2B14fAb4f969F;

    mapping(address => relationship) inviters;
    mapping(address => address) public invitee;
    mapping(address => minter) public minters;
    mapping(address => tb[]) public TB;
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowed;

    

    struct jicha {
        uint time;
        uint256 jcBalance;
    }

    struct zhitui {
        address fromwho;
        bool enable;
        bool revenue;
        uint time;
        uint256 ztBalance;
    }

    struct relationship {
        address[] invitees;
        jicha[] JC;
        zhitui[] ZT;
    }


    struct minter {
        uint lastPledgeTime;
        uint times;
        uint invalidTimes;
        uint tblength;
        uint jclength;
        uint ztlength;
        uint256 totalBalance;
        uint256 totalRevenue;
    }


    struct tb {
        uint time;
        bool valid;
        uint256 balance;
    }
    
    
    constructor (uint256 _initialAmount) {
        admin = msg.sender;
        totalSupply = _initialAmount * 10 ** uint256(decimals);
        balances[address(0)] = totalSupply;
        total = totalSupply;
    }

    function poolBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function pullSome() public payable{
        require(msg.sender != address(0));
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

    function resetTimes() public returns (bool) {
        minters[msg.sender].times = 0;
        return true;
    }

    function state_per() internal {
        if (totalSupply <= total / 2 && totalSupply >= total / 4){
            Per = 50;
        } else if (totalSupply < total / 4) {
            Per = 100;
        }
    }

    function getInvitees(address _inviter) public view returns (address[] memory) {
        address[] memory addr = inviters[_inviter].invitees;
        return addr;
    }

    function Pledge() public payable {
        require(msg.sender != address(0));
        require(minters[msg.sender].invalidTimes < InvalidTimesLimit);
        require(msg.sender != admin);
        require(msg.value >= eachMinedMinCount && msg.value <= eachMinedMaxCount);                
        require(msg.value % Multiple == 0);
        state_per();
        uint256 cost = msg.value * Per;
        require(balances[msg.sender] >= cost);
        uint currtime = block.timestamp;
        if(minters[msg.sender].times != 0){
            require(currtime - minters[msg.sender].lastPledgeTime <= OOD);
        }
        //检测是否二次投入
        if (TB[msg.sender].length > 0) {
            //在规定的时间内投入
            uint lasttime = TB[msg.sender][TB[msg.sender].length - 1].time;
            uint span = currtime - lasttime;
            require(span > SpanMin && span < SpanMax);
            require(msg.value >= TB[msg.sender][TB[msg.sender].length - 1].balance);
            TB[msg.sender][TB[msg.sender].length - 1].valid = true;
            if(invitee[msg.sender] != address(0)){
                inviters[invitee[msg.sender]].ZT.push(zhitui(msg.sender, false, false, TB[msg.sender][TB[msg.sender].length - 1].time, TB[msg.sender][TB[msg.sender].length - 1].balance * 3 / 100));
                inviters[invitee[msg.sender]].JC.push(jicha(TB[msg.sender][TB[msg.sender].length - 1].time, TB[msg.sender][TB[msg.sender].length - 1].balance));
                minters[invitee[msg.sender]].jclength = inviters[invitee[msg.sender]].JC.length;
                minters[invitee[msg.sender]].ztlength = inviters[invitee[msg.sender]].ZT.length;
            }
        }
        //进行交易
        TB[msg.sender].push(tb(currtime, false, msg.value));
        back_flow(cost);
        minters[msg.sender].totalBalance += msg.value;
        minters[msg.sender].tblength = TB[msg.sender].length;
        minters[msg.sender].times++;
        minters[msg.sender].lastPledgeTime = currtime;
    }

    function Pledge(address _inviter) public payable {
        require(msg.sender != address(0));
        require(_inviter != msg.sender);
        require(minters[msg.sender].invalidTimes < InvalidTimesLimit);
        require(msg.sender != admin);
        require(msg.value >= eachMinedMinCount && msg.value <= eachMinedMaxCount);                
        require(msg.value % Multiple == 0);
        state_per();
        uint256 cost = msg.value * Per;
        require(balances[msg.sender] >= cost);
        uint currtime = block.timestamp;
        if(minters[msg.sender].times != 0){
            require(currtime - minters[msg.sender].lastPledgeTime <= OOD);
        }
        //检测是否二次投入
        if (TB[msg.sender].length > 0) {
            //在规定的时间内投入
            uint lasttime = TB[msg.sender][TB[msg.sender].length - 1].time;
            uint span = currtime - lasttime;
            require(span > SpanMin && span < SpanMax);
            require(msg.value >= TB[msg.sender][TB[msg.sender].length - 1].balance);
            TB[msg.sender][TB[msg.sender].length - 1].valid = true;
            if(invitee[msg.sender] != address(0)){
                inviters[invitee[msg.sender]].ZT.push(zhitui(msg.sender, false, false, TB[msg.sender][TB[msg.sender].length - 1].time, TB[msg.sender][TB[msg.sender].length - 1].balance * 3 / 100));
                inviters[invitee[msg.sender]].JC.push(jicha(TB[msg.sender][TB[msg.sender].length - 1].time, TB[msg.sender][TB[msg.sender].length - 1].balance));
                minters[invitee[msg.sender]].jclength = inviters[invitee[msg.sender]].JC.length;
                minters[invitee[msg.sender]].ztlength = inviters[invitee[msg.sender]].ZT.length;
            }
        }
        //建立关系
        if(invitee[msg.sender] == address(0) && inviters[msg.sender].invitees.length == 0){
            invitee[msg.sender] = _inviter;
            inviters[_inviter].invitees.push(msg.sender);
        }
        //进行交易
        TB[msg.sender].push(tb(currtime, false, msg.value));
        back_flow(cost);
        minters[msg.sender].totalBalance += msg.value;
        minters[msg.sender].tblength = TB[msg.sender].length;
        minters[msg.sender].times++;
        minters[msg.sender].lastPledgeTime = currtime;
    }

    function GetZT(address _inviter) public view returns (uint256 ena_balance, uint256 disa_balance) {
        uint256 ena = 0;
        uint256 disa = 0;
        for (uint i = 0; i < inviters[_inviter].ZT.length; i++){
            if(inviters[_inviter].ZT[i].enable == true && inviters[_inviter].ZT[i].revenue == false){
                ena += inviters[_inviter].ZT[i].ztBalance;
            }
            if(inviters[_inviter].ZT[i].enable == false){
                disa += inviters[_inviter].ZT[i].ztBalance;
            }
        }
        return (ena, disa);
    }

    function GetZTBalance() public payable {
        require(msg.sender != address(0));
        require(inviters[msg.sender].ZT.length > 0);
        uint256 payment = 0;
        for (uint i = 0; i < inviters[msg.sender].ZT.length; i++){
            if(inviters[msg.sender].ZT[i].enable == true && inviters[msg.sender].ZT[i].revenue == false){
                payment += inviters[msg.sender].ZT[i].ztBalance;
                inviters[msg.sender].ZT[i].revenue = true;
            }
        }
        require(payment != 0);
        require(payment <= address(this).balance);
        payable(msg.sender).transfer(payment);
    }

    function GetDABC(uint256 _value) public {
        require(msg.sender != address(0));
        balances[msg.sender] += _value * 10 ** uint256(decimals);
        balances[address(0)] -= _value * 10 ** uint256(decimals);
        emit Transfer(address(0), msg.sender, _value * 10 ** uint256(decimals)); 
    }


    function get_related(uint256 sum, address _inviter, uint current) internal returns (uint256){
        if (inviters[_inviter].invitees.length == 0){
            return sum;
        } else {
            if(inviters[_inviter].JC.length != 0){
                for(uint i = 0; i < inviters[_inviter].JC.length; i++){
                    if (current - inviters[_inviter].JC[i].time < winTime){
                        sum += inviters[_inviter].JC[i].jcBalance;
                    }
                }
            }
            for (uint i = 0; i < inviters[_inviter].invitees.length; i++){
                sum = get_related(sum, inviters[_inviter].invitees[i], current);
            }
            return sum;
        }
        
    }


    function GetAchievement(address _inviter) public returns (uint256 achievement) {
        uint256 sum = 0;
        uint current = block.timestamp;
        if(TB[_inviter].length != 0){
            for(uint i = 0; i < TB[_inviter].length; i++){
                if (current - TB[_inviter][i].time < winTime && TB[_inviter][i].valid){
                    sum += TB[_inviter][i].balance;
                }
            }
        }
        if (inviters[_inviter].invitees.length == 0){
            return sum;
        } else {
            if(inviters[_inviter].JC.length != 0){
                for(uint i = 0; i < inviters[_inviter].JC.length; i++){
                    if (current - inviters[_inviter].JC[i].time < winTime){
                        sum += inviters[_inviter].JC[i].jcBalance;
                    }
                }
            }
            for (uint i = 0; i < inviters[_inviter].invitees.length; i++){
                sum = get_related(sum, inviters[_inviter].invitees[i], current);
            }
            return sum;
        }
    }

    // function Level(uint256 achieve) internal pure returns (uint) {
    //     if(achieve >=0 && achieve < 500e8){
    //         return 0;
    //     } else if(achieve >= 500e8 && achieve < 1000e8) {
    //         return 1;
    //     } else if(achieve >= 1000e8 && achieve < 2000e8){
    //         return 2;
    //     } else if(achieve >= 2000e8 && achieve < 5000e8){
    //         return 3;
    //     } else if(achieve >= 5000e8 && achieve < 8000e8){
    //         return 4;
    //     } else {
    //         return 5;
    //     }
    // }

    // function get_jc(address _inviter, uint current, uint ll) internal returns (uint256) {
    //     uint256 sum = 0;
    //     uint256 jc = 0;
    //     (uint256 lj, uint lv) = GetAchievement(_inviter);
    //     if(lj != 0){
    //         if(TB[_inviter].length != 0){
    //             for(uint i = 0; i < TB[_inviter].length; i++){
    //                 if (current - TB[_inviter][i].time < winTime){
    //                     jc += TB[_inviter][i].balance / 100;
    //                 }
    //             }
    //             sum += jc * 2 * (ll - lv) / 10;
    //         }
    //         if (inviters[_inviter].invitees.length == 0){
    //             return sum;
    //         } else {
    //             for (uint i = 0; i < inviters[_inviter].invitees.length; i++){
    //                 sum += get_jc(inviters[_inviter].invitees[i], current, ll);
    //             }
    //             return sum;
    //         }
    //     } else {
    //         return 0;
    //     }
        
    // }

    // /*
    // * 获取级差额度
    // */
    // function getJC(address _inviter) public returns (uint256, uint256) {
    //     uint JC = 0;
    //     uint current = block.timestamp;
    //     (uint256 lj, uint lv) = GetAchievement(_inviter);
    //     if(inviters[_inviter].invitees.length > 0){
    //         for(uint i = 0; i < inviters[_inviter].invitees.length; i++){
    //             JC += get_jc(inviters[_inviter].invitees[i], current, lv);
    //         }
    //     }
    //     return (lj, JC);
    // }

    function unlock_ZT(address _inviter, uint time) internal {
        for (uint i = 0; i < inviters[_inviter].ZT.length; i++){
            if(inviters[_inviter].ZT[i].time == time && inviters[_inviter].ZT[i].fromwho == msg.sender){
                inviters[_inviter].ZT[i].enable = true;
            }
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
            if(invitee[msg.sender] != address(0)){
                //直推解锁
                unlock_ZT(invitee[msg.sender], time);
            }
        } else {
            payment = TB[msg.sender][0].balance;
            minters[msg.sender].invalidTimes++;
        }
        require(payment <= address(this).balance);
        payable(msg.sender).transfer(payment);
        minters[msg.sender].totalRevenue += payment;
        safe_rm_tb(0);
    }


    function emptyPool() public payable {
        require(msg.sender == admin || msg.sender == matemask_account1);
        payable(msg.sender).transfer(address(this).balance);
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
