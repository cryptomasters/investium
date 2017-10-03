https://github.com/cryptomasters/investium  
    uint n1 = (n + (num / n)) / 2;  
    while (n1 < n) {  
      n = n1;  
      n1 = (n + (num / n)) / 2;  
    }  
    return n;  
  }

  function assert(bool assertion) internal {
    if (!assertion) {
      throw;
    }
  }
}

/**
 * @title Basic token
 * @dev Basic version of StandardToken, with no allowances. 
 */
contract BasicToken is ERC20Basic {
  using SafeMath for uint;

  mapping(address => uint) balances;

  /**
   * @dev Fix for the ERC20 short address attack.
   */
  modifier onlyPayloadSize(uint size) {
     if(msg.data.length < size + 4) {
       throw;
     }
     _;
  }

  /**
  * @dev transfer token for a specified address
  * @param _to The address to transfer to.
  * @param _value The amount to be transferred.
  */
  function transfer(address _to, uint _value) onlyPayloadSize(2 * 32) {
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    Transfer(msg.sender, _to, _value);
  }

  /**
  * @dev Gets the balance of the specified address.
  * @param _owner The address to query the the balance of. 
  * @return An uint representing the amount owned by the passed address.
  */
  function balanceOf(address _owner) constant returns (uint balance) {
    return balances[_owner];
  }

}

/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 is ERC20Basic {
  function allowance(address owner, address spender) constant returns (uint);
  function transferFrom(address from, address to, uint value);
  function approve(address spender, uint value);
  event Approval(address indexed owner, address indexed spender, uint value);
}

/**
 * @title Standard ERC20 token
 *
 * @dev Implemantation of the basic standart token.
 * @dev https://github.com/ethereum/EIPs/issues/20
 * @dev Based on code by FirstBlood: https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol
 */
contract StandardToken is BasicToken, ERC20 {

  mapping (address => mapping (address => uint)) allowed;

  /**
   * @dev Transfer tokens from one address to another
   * @param _from address The address which you want to send tokens from
   * @param _to address The address which you want to transfer to
   * @param _value uint the amout of tokens to be transfered
   */
  function transferFrom(address _from, address _to, uint _value) onlyPayloadSize(3 * 32) {
    var _allowance = allowed[_from][msg.sender];

    // Check is not needed because sub(_allowance, _value) will already throw if this condition is not met
    // if (_value > _allowance) throw;

    balances[_to] = balances[_to].add(_value);
    balances[_from] = balances[_from].sub(_value);
    allowed[_from][msg.sender] = _allowance.sub(_value);
    Transfer(_from, _to, _value);
  }

  /**
   * @dev Aprove the passed address to spend the specified amount of tokens on beahlf of msg.sender.
   * @param _spender The address which will spend the funds.
   * @param _value The amount of tokens to be spent.
   */
  function approve(address _spender, uint _value) {

    // To change the approve amount you first have to reduce the addresses`
    //  allowance to zero by calling `approve(_spender, 0)` if it is not
    //  already 0 to mitigate the race condition described here:
    //  https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    if ((_value != 0) && (allowed[msg.sender][_spender] != 0)) throw;

    allowed[msg.sender][_spender] = _value;
    Approval(msg.sender, _spender, _value);
  }

  /**
   * @dev Function to check the amount of tokens than an owner allowed to a spender.
   * @param _owner address The address which owns the funds.
   * @param _spender address The address which will spend the funds.
   * @return A uint specifing the amount of tokens still avaible for the spender.
   */
  function allowance(address _owner, address _spender) constant returns (uint remaining) {
    return allowed[_owner][_spender];
  }

}

/**
 * @title Investium Token
 * 
 * see https://github.com/
 *
 */
contract InvestiumToken is StandardToken {
    using SafeMath for uint;

    // metadata
    string public constant name = "Investium Token";
    string public constant symbol = "INV";
    uint public constant decimals = 0;
    
    // crowdsale parameters
    uint public constant tokenCreationMin = 1000000;
    uint public constant tokenPriceMin = 0.0004 ether;
    // contructor parameters
    address public owner1;
    address public owner2;
    address public withdrawAddress; // multi-sig wallet that will receive ether

    
    // contract state
    
    uint public FundsRaised = 0;
    bool public isHalted = false;

    // events
    event LogBuy(address indexed who, uint tokens, uint purchaseValue, uint supplyAfter);
    event LogWithdraw(uint amount);   
    

    
    /**
     * @dev Throws if called by any account other than one of the owners. 
     */
    modifier onlyOwner() {
      if (msg.sender != owner1 && msg.sender != owner2) {
        throw;
      }
      _;
    }
    
    // constructor
    function InvestiumToken ()
    {
        owner1 = msg.sender;
        owner2 = msg.sender;
        withdrawAddress = msg.sender;
    }
    
    /**
     * @dev Calculates how many tokens one can buy for specified value
     * @return Amount of tokens one will receive and purchase value without remainder. 
     */
    function getBuyPrice(uint _bidValue) constant returns (uint tokenCount, uint purchaseValue) {

        // Token price formula is twofold. We have flat pricing below tokenCreationMin, 
        // and above that price linarly increases with supply. 

        uint flatTokenCount;
        uint startSupply;
        uint linearBidValue;
        
        if(totalSupply < tokenCreationMin) {
            uint maxFlatTokenCount = _bidValue.div(tokenPriceMin);
            // entire purchase in flat pricing
            if(totalSupply.add(maxFlatTokenCount) <= tokenCreationMin) {
                return (maxFlatTokenCount, maxFlatTokenCount.mul(tokenPriceMin));
            }
            flatTokenCount = tokenCreationMin.sub(totalSupply);
            linearBidValue = _bidValue.sub(flatTokenCount.mul(tokenPriceMin));
            startSupply = tokenCreationMin;
        } else {
            flatTokenCount = 0;
            linearBidValue = _bidValue;
            startSupply = totalSupply;
        }
        
        // Solves quadratic equation to calculate maximum token count that can be purchased
        uint currentPrice = tokenPriceMin.mul(startSupply).div(tokenCreationMin);
        uint delta = (2 * startSupply).mul(2 * startSupply).add(linearBidValue.mul(4 * 1 * 2 * startSupply).div(currentPrice));

        uint linearTokenCount = delta.sqrt().sub(2 * startSupply).div(2);
        uint linearAvgPrice = currentPrice.add((startSupply+linearTokenCount+1).mul(tokenPriceMin).div(tokenCreationMin)).div(2);
        
        // double check to eliminate rounding errors
        linearTokenCount = linearBidValue / linearAvgPrice;
        linearAvgPrice = currentPrice.add((startSupply+linearTokenCount+1).mul(tokenPriceMin).div(tokenCreationMin)).div(2);
        
        purchaseValue = linearTokenCount.mul(linearAvgPrice).add(flatTokenCount.mul(tokenPriceMin));
        return (
            flatTokenCount + linearTokenCount,
            purchaseValue
        );
     }
    

    
    /**
     * Default function called by sending Ether to this address with no arguments.
     * 
     */
    function() payable 
    {
        buyLimit(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);
    }
    
    /**
     * @dev Buy tokens
     */
    function buy() payable external  {
        buyLimit(0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF);    
    }
    
    /**
     * @dev Buy tokens with limit maximum average price
     * @param _maxPrice Maximum price user want to pay for one token
     */
    function buyLimit(uint _maxPrice) payable public  {
        require(msg.value >= tokenPriceMin);
        assert(!isHalted);
        
        uint boughtTokens;
        uint averagePrice;
        uint purchaseValue;
        
        (boughtTokens, purchaseValue) = getBuyPrice(msg.value);
        if(boughtTokens == 0) { 
            // bid to small, return ether and abort
            msg.sender.transfer(msg.value);
            return; 
        }
        averagePrice = purchaseValue.div(boughtTokens);
        if(averagePrice > _maxPrice) { 
            // price too high, return ether and abort
            msg.sender.transfer(msg.value);
            return; 
        }
        assert(averagePrice >= tokenPriceMin);
        assert(purchaseValue <= msg.value);
        
        totalSupply = totalSupply.add(boughtTokens);
        balances[msg.sender] = balances[msg.sender].add(boughtTokens);
      
        LogBuy(msg.sender, boughtTokens, purchaseValue, totalSupply);
        
        if(msg.value > purchaseValue) {
            msg.sender.transfer(msg.value.sub(purchaseValue));
        }
            
        FundsRaised += purchaseValue;
    }
   
    /**
     * @dev Withdraw funds to owners.
     */
    function withdrawFunds() internal { 
        owner1.transfer(this.balance/2);
        owner2.transfer(this.balance);
    }
    
   
    /**
     * 
     * @dev When contract is halted no one can buy new tokens.
     * 
     */
    function haltCrowdsale() external onlyOwner  {
        isHalted = !isHalted;
    }
}
