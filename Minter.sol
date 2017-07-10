pragma solidity ^0.4.10;

contract ILF {
    uint public decimals;
    function emitToken(address, uint) {}
}

contract AssetsStore {
    uint public tokenPrice;
    address public etherVault;
    function etherDeposit(address, uint) {}
}

contract Minter {

    address public commissionHolder;
    ILF public ilf; 
    MinterControl public minterControl;
    AssetsStore public assetsStore;
    uint public constant maxDepositCommission = 20; //percents
    uint public constant minDepositCommission = 0;  //percents
    uint public minimalInvestment = 0; //in wei

    /// @dev Create Minter contract.
    /// @param _ILFAddress Token address.
    function Minter(address _ILFAddress, address _minterControlAddress, address _assetsStoreAddress, address
                     _commissionHolder) {
        minterControl = MinterControl(_minterControlAddress);
        commissionHolder = _commissionHolder;
        assetsStore = AssetsStore(_assetsStoreAddress);
        ilf = ILF(_ILFAddress);
    }

    /// @dev Fallback function for receiving ether and issuing ILF tokens.
    function() payable {
        assert(msg.value >= minimalInvestment);
        uint commission = minterControl.calculateDepositCommission(msg.sender, msg.value);
        assert(commission >= minDepositCommission && commission <= maxDepositCommission);
        uint fee = commission*msg.value/100;
        uint investAmount = msg.value-fee;
        uint tokenAmount = investAmount/assetsStore.tokenPrice();
        address etherVault = assetsStore.etherVault();
        etherVault.transfer(investAmount);
        commissionHolder.transfer(fee);
        ilf.emitToken(msg.sender, tokenAmount);
        assetsStore.etherDeposit(msg.sender, investAmount);
    }

    function enterWithoutCommission(address _to) payable onlyChosenOne {
        uint tokenAmount = msg.value/assetsStore.tokenPrice();
        address etherVault = assetsStore.etherVault();
        etherVault.transfer(msg.value);
        ilf.emitToken(_to, tokenAmount);
    }

    /// @dev Change AssetsStore. 
    /// @param _assetsStoreAddress Address of new AssetsStore.
    function changeAssetsStore(address _assetsStoreAddress) onlyManager { 
        assetsStore = AssetsStore(_assetsStoreAddress);
    }

    /// @dev Change commission holder. 
    /// @param _commissionHolder Address of new commission holder.
    function changeCommissionHolder(address _commissionHolder) onlyManager {
        commissionHolder = _commissionHolder;
    }
    
    /// @dev Change minimal investment.
    /// @param _minimalInvestment New value of minimal investment. In wei.
    function changeMinimalInvestment(uint _minimalInvestment) onlyManager {
        minimalInvestment = _minimalInvestment;
    }

    /// @dev Change minter control contract.
    /// @param _minterControlAddress Address of new minter control.
    function changeMinterControl(address _minterControlAddress) onlyManager {
        MinterControl newControl = MinterControl(_minterControlAddress);
        assert(newControl.managers(msg.sender));
        minterControl = newControl;
    }
    
    modifier onlyManager() {
        assert(minterControl.managers(msg.sender));
        _;
    }

    modifier onlyChosenOne() {
        assert(minterControl.chosenOnes(msg.sender));
        _;
    }
}

contract MinterControl {

    mapping(address => bool) public managers;
    mapping(address => bool) public chosenOnes;
    int public manualDepositCommission = 5; //if less than 0, then amount-dependent commission is used

    /// @dev Create MinterControl contract.
    /// @param _managerAddress Minter manager address.
    function MinterControl(address _managerAddress) {
        managers[_managerAddress] = true;
    }

    /// @dev Calculate commission for given address and investment value in wei.
    /// @param _to Investor address.
    /// @param _value Investment value in wei.
    function calculateDepositCommission(address _to, uint _value) constant returns(uint commission) {
        _to; //address is not used now, but solidity compiler requires usage of all input paramters
        if (manualDepositCommission >= 0) {
            commission = uint(manualDepositCommission);
        }
        else if (_value < 10 ether) {
            commission = 10;
        }
        else if (_value < 50 ether) {
            commission = 5;
        }
        else {
            commission = 3;
        }
        return commission;
    }

    ///@dev Set manual deposit commission. Negative value indicates usage of default behaviour: commission depends on investment value.
    ///@param _depositCommission Manual commission value.
    function setManualDepositCommission(int _depositCommission) onlyManager {
        manualDepositCommission = _depositCommission;
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

    ///@dev Allows given address to be chosen one.
    ///@param _chosenOneAddress Manager address.
    ///@param _hash SHA3 of provided chosen one address.
    function setChosenOne(address _chosenOneAddress, bytes32 _hash) onlyManager { 
        assert(sha3(_chosenOneAddress)==_hash);
        chosenOnes[_chosenOneAddress] = true;
    }

    ///@dev Disallows given address to be chosen one.
    ///@param _chosenOneAddress Manager address.
    ///@param _hash SHA3 of provided chosen one address.
    function unSetChosenOne(address _chosenOneAddress, bytes32 _hash) onlyManager { 
        assert(sha3(_chosenOneAddress)==_hash);
        chosenOnes[_chosenOneAddress] = false;
    }

    modifier onlyManager() {
        assert(managers[msg.sender]);
        _;
    }
}


contract ChosenOne {

    mapping(address=>uint) public referrals;
    address minterAddress;
    Minter minter;
    MinterControl minterControl;
    AssetsStore assetsStore;
    ILF ilf;

    function depositUsingReferral(address ref) payable {
        assert(msg.value >= minter.minimalInvestment());
        uint commission = minterControl.calculateDepositCommission(msg.sender, msg.value);
        if (referrals[ref] > 1000 ether) {
            commission = 80*commission/commission;
        } else if (referrals[ref] > 5000 ether){
            commission = 60*commission/commission;
        } else if (referrals[ref] > 10000 ether){
            commission = 40*commission/commission;
        }
        assert(commission >= minter.minDepositCommission() && commission <= minter.maxDepositCommission());
        uint fee = commission*msg.value/100;
        uint investAmount = msg.value-fee;
        uint tokenAmount = investAmount/assetsStore.tokenPrice();
        address etherVault = assetsStore.etherVault();
        etherVault.transfer(investAmount);
        minter.enterWithoutCommission.value(investAmount)(msg.sender);
        referrals[ref] += investAmount;
        minter.commissionHolder().transfer(fee);
        ilf.emitToken(msg.sender, tokenAmount);
        assetsStore.etherDeposit(msg.sender, investAmount);
    }

    function changeMinter() {}
    function changeAssetsStore() {}
}
