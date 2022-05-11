// SPDX-License-Identifier: Apache-2.0
pragma solidity >=0.7.0 <0.9.0;


abstract contract MP10Interface {
   
    uint256 public totalSupply;

    function balanceOf(address _owner) public virtual view returns (uint256);

    function transfer(address _to, uint256 _value) public virtual returns (bool);

    function transferFrom(address _from, address _to, uint256 _value) public virtual returns (bool);

    function approve(address _spender, uint256 _value) public virtual returns (bool);

    function allowance(address _owner, address _spender) public virtual view returns (uint256);

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}
