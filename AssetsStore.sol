pragma solidity ^0.4.10;

contract ILF { 
    uint public totalSupply;
    uint8 public decimals;
    bool public manualEmissionEnabled;
}

contract AssetsStore {
    
    mapping(address => bool) public oracles;
    mapping(address => bool) public managers;
    mapping(address => uint) public investmentsETH; //must not be public
    mapping(address => uint) public investmentsUSD; //must not be public
    uint public constant exa = 1000000000000000000; //10^18
    uint public lastUpdate;
    uint public tokenPrice; //for back compatibility it's not changed to tokenPriceETH
    //uint public tokenPriceUSD
    uint public tokenPriceUSD;
    uint public assetsValueUSD; 
    uint public depositedETH = 0;
    uint public depositedUSD = 0;
    uint public ETHPrice = 270000000000000000000; // = $270, price is in attodollars, so 1 wei = 270 attodollars
    address public minterAddress;
    address public burnerAddress;
    address public etherVault;
    address public ILFAddress;
    ILF public ilf;

    // @dev Create AssetsStore.
    // @param _manager AssetsStore manager address.
    // @param _oracle Oracle address.
    // @param _etherVault Ether vault address.
    // @param _ILFAddress ILF token address.
    function AssetsStore(address _manager, address _oracle, address _etherVault, address _ILFAddress) {
        ilf = ILF(_ILFAddress);
        ILFAddress = _ILFAddress;
        managers[_manager] = true;
        oracles[_oracle] = true;
        uint coefficient = 10**uint(ilf.decimals());
        uint oneEther = 1 ether;
        tokenPriceUSD = uint((oneEther)/(3500*coefficient))*ETHPrice/exa; //attodollars
        etherVault = _etherVault;
    }

    // @dev Set assets value.
    // @param _assetsValue Value in wei.
    function setAssetsValue(uint _assetsValueUSD, uint _ETHPrice) onlyOracleOrManager {
        assetsValueUSD = _assetsValueUSD;
        ETHPrice = _ETHPrice;
        lastUpdate = now;
        calculateILFPrice();
    }
    
    function etherDeposit(address _to, uint value) {
        assert(msg.sender == minterAddress || (managers[msg.sender] && ilf.manualEmissionEnabled()));
        investmentsETH[_to] += value;
        depositedETH += value;
        uint valueUSD = value*ETHPrice/exa;
        investmentsUSD[_to] +=valueUSD;
        depositedUSD += valueUSD;
    }

    function usdDeposit(address _to, uint value) {
        assert(msg.sender == minterAddress || (managers[msg.sender] && ilf.manualEmissionEnabled()));
        investmentsUSD[_to] +=value;
        depositedUSD += value;
    }

    function usdWithdraw(address _to, uint value) onlyBurner {
        if(investmentsUSD[_to] < value) {
            investmentsUSD[_to] = 0;
        }
        else {
            investmentsUSD[_to] -= value;
        }

        if(depositedUSD < value) {
            depositedUSD = 0;
        }
        else {
            depositedUSD -= value;
        }
    }

    function etherWithdraw(address _to, uint value) onlyBurner {
        if(investmentsETH[_to] < value) {
            investmentsETH[_to] = 0;
        }
        else {
            investmentsETH[_to] -= value;
        }

        if(depositedETH < value) {
            depositedETH = 0;
        }
        else {
            depositedETH -= value;
        }
    }

    //1 ILF token costs this amount of wei
    function calculateILFPrice() {
        uint coefficient = 10**uint(ilf.decimals());
        if (ilf.totalSupply() == 0) {
            uint oneEther = 1 ether;
            tokenPriceUSD = uint((oneEther)/(3500*coefficient))*ETHPrice/exa; //attodollars
        }
        else {
            tokenPriceUSD = (assetsValueUSD+(etherVault.balance*ETHPrice/exa))/ilf.totalSupply();
        }
        tokenPrice = tokenPriceUSD*exa/ETHPrice; 
    }

    function changeEtherVault(address _etherVault) onlyManager {
        etherVault = _etherVault;
        calculateILFPrice();
    }

    function changeBurner(address _burnerAddress) onlyManager { 
        burnerAddress = _burnerAddress;
    }

    function changeMinter(address _minterAddress) onlyManager { 
        minterAddress = _minterAddress;
    }

    ///@dev Allows given address to be manager.
    ///@param _managerAddress Manager address.
    ///@param _hash SHA3 of provided manager address.
    function setManager(address _managerAddress, bytes32 _hash) onlyManager { 
        assert(sha3(_managerAddress)==_hash);
        managers[_managerAddress] = true;
    }

    ///@dev Disallows given address to be manager.
    ///@param _managerAddress Manager address.
    ///@param _hash SHA3 of provided manager address.
    function unSetManager(address _managerAddress, bytes32 _hash) onlyManager { 
        assert(sha3(_managerAddress)==_hash);
        managers[_managerAddress] = false;
    }

    ///@dev Allows given address to be oracle.
    ///@param _oracleAddress Oracle address.
    ///@param _hash SHA3 of provided oracle address.
    function setOracle(address _oracleAddress, bytes32 _hash) onlyManager { 
        assert(sha3(_oracleAddress)==_hash);
        oracles[_oracleAddress] = true;
    }

    ///@dev Disallows given address to be oracle.
    ///@param _oracleAddress Oracle address.
    ///@param _hash SHA3 of provided oracle address.
    function unSetOracle(address _oracleAddress, bytes32 _hash) onlyManager { 
        assert(sha3(_oracleAddress)==_hash);
        oracles[_oracleAddress] = false;
    }

    modifier onlyMinter() {
        assert(msg.sender == minterAddress);
        _;
    }

    modifier onlyBurner() {
        assert(msg.sender == burnerAddress);
        _;
    }

    modifier onlyOracle() {
        assert(oracles[msg.sender]);
        _;
    }

    modifier onlyManager() {
        assert(managers[msg.sender]);
        _;
    }

    modifier onlyOracleOrManager() {
        assert(oracles[msg.sender] || managers[msg.sender]);
        _;
    }
}


