// SPDX-License-Identifier: Apache-2.0

pragma solidity >=0.8.0 <0.9.0;

import "./DABC10Interface.sol";
import "./AggregatorInterface.sol";


contract DABC10 is DABC10Interface {

    uint256 constant private MAX_UINT256 = 2**256 - 1;
    uint constant public winTime = 3 * 60;         //质押时长（单位：秒）
    uint256 constant public eachMinedMinCount = 1e17; //单轮最小
    uint256 constant public eachMinedMaxCount = 10e18; //单轮最大
    uint constant public rate = 6;             //质押利息，例：6，表示6%
    uint constant public ZTRate = 2;           //直推利息，3%
    uint constant public SpanMin = 1 * 60; //第二轮质押开始距第一轮质押的时间间隔(单位：秒)
    uint constant public SpanMax = 3 * 60; //第二轮质押结束距第一轮质押的时间间隔(单位：秒)
    uint256 constant public Multiple = 1e17;    //质押倍数
    uint constant public InvalidTimesLimit = 100;    //无效单次数限制
    uint256 constant public OOD = 15 * 24 * 60 * 60;   //15天没有再质押则拉黑名单（测试：15分钟）
    uint constant jc_span = 24 * 60 * 60;      //级差奖励领取时间间隔

    string public constant name = 'DABC';
    string public constant symbol = 'DABC';      
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    uint256 public total;
    
    address admin;
    address constant matemask_account1 = 0x821b121D544cAb0a4F4d0ED2F1c2B14fAb4f969F;

    mapping(address => uint256) public reward;
    mapping(address => address[]) public invitees;
    mapping(address => zhitui[]) public ZT;
    mapping(address => address) public getInvitor;
    mapping(address => minter) public minters;
    mapping(address => tb[]) public TB;
    mapping(address => uint256) public balances;
    mapping(address => mapping(address => uint256)) public allowed;
    mapping(address => uint) jc_time;       //级差领取时间记录
    AggregatorInterface internal priceFeed;
    
    struct zhitui {
        address fromwho;    //建立此直推回报单的地址
        bool enable;        //是否可领取（ture：可领取；false：已领取）
        bool burning;       //是否被烧伤
        uint time;          //直推回报单创建的时间
        uint256 ztBalance;  //直推回报额度
    }

    struct minter {
        uint256 maxPledgeCount;
        uint lastPledgeTime;
        uint times;
        uint invalidTimes;    //无效单次数
        uint tblength;     
        uint ztlength;      //直推单列表长度
        uint256 totalBalance;  //总支出交易
        uint256 totalRevenue;  //总收益
        uint256 PDRevenue;     //质押总收益
        uint256 ZTRevenue;     //直推总收益
        uint256 JCRevenue;     //级差总收益
    }


    struct tb {
        uint time;          //时间戳
        bool valid;         //是否有效
        uint256 cost;       //质押消耗
        uint256 balance;    //质押额度
        bool isexist;       //true:本金存在;false:本金已领取
        uint256 reward;     //质押奖励
    }
    
    
    constructor (uint256 _initialAmount) {
        admin = matemask_account1;
        // priceFeed = AggregatorInterface(0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE);  //BSC chain main net
        priceFeed = AggregatorInterface(0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526);   //BSC chain test net
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

    function getLatestPrice() public pure returns (int256) {
        // return 22268791769 for test
        return 22268791769;
        // return priceFeed.latestAnswer();
    }

    function getLatestPriceTimestamp() public view returns (uint256) {
        return priceFeed.latestTimestamp();
    }

    function changeMaxPledge(address _target, uint256 _maxAmount) public payable {
        require(msg.sender != address(0));
        require(msg.sender == admin);
        require(_target != address(0));
        require(_maxAmount >= eachMinedMaxCount || _maxAmount == 0);
        minters[_target].maxPledgeCount = _maxAmount;
    }

    function get_timestamp() public view returns (uint) {
        return block.timestamp;
    }

    function poolBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function pullSome() public payable{
        require(msg.sender != address(0));
    }

    function getInvitees(address _inviter) public view returns (address[] memory) {
        return invitees[_inviter];
    }

    //get invilid times,
    function get_invalidtimes(address _sender) public view returns (uint) {
        uint t = 0;
        if(TB[_sender].length == 0) return t;
        for(uint i = 0; i < TB[_sender].length; i++){
            if(!TB[_sender][i].valid) t++;
        }
        return t;
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


    function Pledge(address _inviter) public payable returns (uint currtime,uint256 amount) {
        require(msg.sender != address(0));
        require(_inviter != msg.sender);
        require(msg.sender != admin);
        require(msg.value >= eachMinedMinCount && 
        (minters[msg.sender].maxPledgeCount == 0? msg.value <= eachMinedMaxCount : msg.value <= minters[msg.sender].maxPledgeCount));     
        require(msg.value % Multiple == 0);
        uint256 Per = state_per();
        uint256 cost = msg.value * Per / 10 ** 18;
        require(balances[msg.sender] >= cost);
        currtime = block.timestamp;
        amount = msg.value;
        if(minters[msg.sender].times != 0){
            require(currtime - minters[msg.sender].lastPledgeTime <= OOD);
        }
        if (TB[msg.sender].length > 0) {
            uint lasttime = TB[msg.sender][TB[msg.sender].length - 1].time;
            uint span = currtime - lasttime;
            require(span >= SpanMin);
            if(span <= SpanMax) {
                //pledge continue
                require(msg.value >= TB[msg.sender][TB[msg.sender].length - 1].balance);
                TB[msg.sender][TB[msg.sender].length - 1].valid = true;
                TB[msg.sender][TB[msg.sender].length - 1].reward = TB[msg.sender][TB[msg.sender].length - 1].balance * rate / 100;
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
                //break
                // minters[msg.sender].invalidTimes++;
            }  
        }
        // require(minters[msg.sender].invalidTimes < InvalidTimesLimit);
        require(get_invalidtimes(msg.sender) <= InvalidTimesLimit);    //also
        //建立关系
        if(getInvitor[msg.sender] == address(0) && invitees[msg.sender].length == 0 && _inviter != address(0)){
            getInvitor[msg.sender] = _inviter;
            invitees[_inviter].push(msg.sender);
        }
        //进行交易
        TB[msg.sender].push(tb(currtime, false, cost, msg.value, true, 0));
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
        minters[msg.sender].totalRevenue += payment;
        minters[msg.sender].ZTRevenue += payment;
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
        if(achieve < 500e18){
            return 0;
        } else if(achieve >= 500e18 && achieve < 1000e18) {
            return 1;
        } else if(achieve >= 1000e18 && achieve < 2000e18){
            return 2;
        } else if(achieve >= 2000e18 && achieve < 5000e18){
            return 3;
        } else if(achieve >= 5000e18 && achieve < 8000e18){
            return 4;
        } else if(achieve >= 8000e18) {
            return 5;
        }
        return 0;
    }

    //get one's validated order
    function get_valid(address owner, uint current) public view returns (uint256) {
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
            sum += jc * 2 * (ll - lv) / 10;    //等级战利比关系：战利比 = 等级 * 2 / 10
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
    function GetJC(address _inviter) public returns (uint256 jc, uint256 yj, uint lv) {
        if(_inviter == address(0)) return (0,0,0);
        uint current = block.timestamp;
        (yj, lv) = GetAchievement(_inviter);
        if(invitees[_inviter].length > 0){
            for(uint i = 0; i < invitees[_inviter].length; i++){
                jc += get_jc(invitees[_inviter][i], current, lv);
            }
        }
        return (jc, yj, lv);
    }

    // 待完善(一天领取一次？7天领取一次？)
    function GetJCBalance() public payable {
        uint current = block.timestamp;
        require(current - jc_time[msg.sender] >= jc_span);
        require(minters[msg.sender].times != 0);
        require(msg.sender != address(0));
        uint256 jcBalance = 0;
        uint256 yj = 0;
        uint lv = 0;
        (jcBalance, yj, lv) = GetJC(msg.sender);
        require(jcBalance > 0);
        require(address(this).balance >= jcBalance);
        payable(msg.sender).transfer(jcBalance);
        minters[msg.sender].totalRevenue += jcBalance;
        minters[msg.sender].JCRevenue += jcBalance;
        jc_time[msg.sender] = current;
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
        // minters[msg.sender].totalRevenue += payment;
    }

    function GetReward() public payable {
        require(msg.sender != address(0));
        require(reward[msg.sender] > 0);
        require(address(this).balance >= reward[msg.sender]);
        payable(msg.sender).transfer(reward[msg.sender]);
        minters[msg.sender].totalRevenue += reward[msg.sender];
        minters[msg.sender].PDRevenue += reward[msg.sender];
        reward[msg.sender] = 0;
    }

    function emptyPool() public payable {
        require(msg.sender == admin);
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

