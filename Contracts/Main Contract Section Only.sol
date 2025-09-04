
contract WOMBATTABMOW is Context, IERC20, Ownable {
    using SafeMath for uint256;

    string private _name = "TestingWombat";
    string private _symbol = "GWOM";
    uint8 private _decimals = 9;

    address public marketingWallet =
        address(0x28999633794189B200F45F9665973a6014d07Ef2);

    struct feeStruct {
        uint256 buyRewardFee;
        uint256 buyMarketingFee;
        uint256 sellMarketingFee;
        uint256 sellRewardFee;
        uint256 denominator;
    }
    feeStruct public fee;

    bool public launched;

    mapping(address => uint256) _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) public IsChargePair;
    mapping(address => bool) public isMarketPair;
    mapping(address => bool) public isDividendExempt;

    mapping(address => bool) public isWhitelisted;
    bool public whitelistEnabled = true;

    uint256 private _totalSupply = 200_000_000_000 * 10 ** _decimals;

    uint256 public maxTransaction = _totalSupply.mul(200).div(100);
    uint256 public maxWallet = _totalSupply.mul(1).div(100);

    uint256 public swapThreshold = _totalSupply.mul(5).div(100000);

    bool public swapEnabled = true;
    bool public swapbylimit = false;

    bool public AntiWhaleActive = false;

    DividendDistributor distributor;
    address public dividendReciever;

    uint256 distributorGas = 500000;

    IDexSwapRouter public dexRouter;
    address public dexPair;

    bool inSwap;

    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }

    event SwapTokensForETH(uint256 amountIn, address[] path);

    constructor() {
        address _rewardToken = address(
            0x170683f5F16A66Eb275FCBAf6d7bfda9E5aC85C1
        );
        uint _rewardTokenDecimal = uint(18);
        address _router = address(0x139dEfC9CDDd77A137F8C5C8019367eA611124B5);
        uint factor = uint(_decimals) + uint(_rewardTokenDecimal);

        IDexSwapRouter _dexRouter = IDexSwapRouter(_router);

        dexPair = IDexSwapFactory(_dexRouter.factory()).createPair(
            address(this),
            _dexRouter.WETH()
        );

        distributor = new DividendDistributor(
            _router,
            _rewardToken,
            factor,
            _rewardTokenDecimal,
            msg.sender
        );

        dividendReciever = address(distributor);

        isDividendExempt[msg.sender] = true;
        isDividendExempt[dexPair] = true;
        isDividendExempt[address(this)] = true;
        isDividendExempt[address(0xdead)] = true;
        isDividendExempt[address(0x0)] = true;
        isDividendExempt[0x83641dBab18AF4cd14ac23F6257f3269a5693204] = true;
        isDividendExempt[0x88B4706BfB81DDEE6F8090Bb12Fe57Fc15E342b7] = true;
        

        dexRouter = _dexRouter;

        isMarketPair[dexPair] = true;

        IsChargePair[address(this)] = true;
        IsChargePair[msg.sender] = true;
        IsChargePair[marketingWallet] = true;

        fee = feeStruct(3, 2, 2, 3, 100);

        _balances[msg.sender] = _totalSupply;

        isWhitelisted[msg.sender] = true;
        
        isWhitelisted[0x83641dBab18AF4cd14ac23F6257f3269a5693204] = true;  // wombat aggrigation
        isWhitelisted[0x88B4706BfB81DDEE6F8090Bb12Fe57Fc15E342b7] = true; // dex managw  Wrapper

        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    function addToWhitelist(address _address) external onlyOwner {
        require(_address != address(0), "Cannot whitelist zero address");
        isWhitelisted[_address] = true;
    }

    function removeFromWhitelist(address _address) external onlyOwner {
        isWhitelisted[_address] = false;
    }

    function setWhitelistEnabled(bool _enabled) external onlyOwner {
        whitelistEnabled = _enabled;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function allowance(
        address owner,
        address spender
    ) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    receive() external payable {}

    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) private returns (bool) {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        if (whitelistEnabled) {
            require(
                isWhitelisted[sender] ||
                    isWhitelisted[recipient] ||
                    sender == owner() ||
                    recipient == owner(),
                "When whitelist is enabled, only whitelisted addresses can transfer"
            );
        }

        if (inSwap) {
            return _basicTransfer(sender, recipient, amount);
        } else {
            if (
                !IsChargePair[sender] &&
                !IsChargePair[recipient] &&
                AntiWhaleActive
            ) {
                require(launched, "Not Launched!");
                require(amount <= maxTransaction, "Exceeds maxTxAmount");
                if (!isMarketPair[recipient]) {
                    require(
                        balanceOf(recipient).add(amount) <= maxWallet,
                        "Exceeds maxWallet"
                    );
                }
            }

            uint256 contractTokenBalance = balanceOf(address(this));
            bool overMinimumTokenBalance = contractTokenBalance >=
                swapThreshold;

            if (
                overMinimumTokenBalance &&
                !inSwap &&
                !isMarketPair[sender] &&
                swapEnabled &&
                !IsChargePair[sender] &&
                !IsChargePair[recipient]
            ) {
                swapBack(contractTokenBalance);
            }

            _balances[sender] = _balances[sender].sub(
                amount,
                "Insufficient Balance"
            );

            uint256 finalAmount = shouldNotTakeFee(sender, recipient)
                ? amount
                : takeFee(sender, recipient, amount);

            _balances[recipient] = _balances[recipient].add(finalAmount);

            if (!isDividendExempt[sender]) {
                try distributor.setShare(sender, balanceOf(sender)) {} catch {}
            }
            if (!isDividendExempt[recipient]) {
                try
                    distributor.setShare(recipient, balanceOf(recipient))
                {} catch {}
            }

            try distributor.process(distributorGas) {} catch {}

            emit Transfer(sender, recipient, finalAmount);
            return true;
        }
    }

    function manualProcess() external {
        try distributor.process(distributorGas) {} catch {}
    }

    function _basicTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        _balances[sender] = _balances[sender].sub(
            amount,
            "Insufficient Balance"
        );
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function shouldNotTakeFee(
        address sender,
        address recipient
    ) internal view returns (bool) {
        if (IsChargePair[sender] || IsChargePair[recipient]) {
            return true;
        } else if (isMarketPair[sender] || isMarketPair[recipient]) {
            return false;
        } else {
            return true;
        }
    }

    function takeFee(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (uint256) {
        uint feeAmount;
        uint rewardFee;
        uint marketingFee;

        unchecked {
            if (isMarketPair[sender]) {
                marketingFee = amount.mul(fee.buyMarketingFee).div(
                    fee.denominator
                );
                rewardFee = amount.mul(fee.buyRewardFee).div(fee.denominator);
                feeAmount = marketingFee.add(rewardFee);
            } else if (isMarketPair[recipient]) {
                marketingFee = amount.mul(fee.sellMarketingFee).div(
                    fee.denominator
                );
                rewardFee = amount.mul(fee.sellRewardFee).div(fee.denominator);
                feeAmount = marketingFee.add(rewardFee);
            }

            if (feeAmount > 0) {
                _balances[address(this)] = _balances[address(this)].add(
                    feeAmount
                );
                emit Transfer(sender, address(this), feeAmount);
            }

            return amount.sub(feeAmount);
        }
    }

    function swapBack(uint contractBalance) internal swapping {
        if (swapbylimit) contractBalance = swapThreshold;

        uint rewardShare = fee.buyRewardFee.add(fee.buyRewardFee);
        uint marketingShare = fee.buyMarketingFee.add(fee.sellMarketingFee);

        uint totalShares = rewardShare.add(marketingShare);

        uint256 initialBalance = address(this).balance;
        swapTokensForEth(contractBalance);
        uint256 amountReceived = address(this).balance.sub(initialBalance);

        uint marketingEth = amountReceived.mul(marketingShare).div(totalShares);
        uint rewardEth = amountReceived.sub(marketingEth);

        if (rewardEth > 0) {
            try distributor.deposit{value: rewardEth}() {} catch {}
        }
        if (marketingEth > 0) {
            (bool os, ) = payable(marketingWallet).call{value: marketingEth}(
                ""
            );
            os = true; 
        }
    }

    function swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = dexRouter.WETH();

        _approve(address(this), address(dexRouter), tokenAmount);

        dexRouter.swapExactTokensForETH(
            tokenAmount,
            1,
            path,
            address(this),
            block.timestamp + 30
        );

        emit SwapTokensForETH(tokenAmount, path);
    }

    function setMarketingWallet(address newAddress) external onlyOwner {
        marketingWallet = newAddress;
    }

    function rescueFunds() external onlyOwner {
        (bool os, ) = payable(msg.sender).call{value: address(this).balance}(
            ""
        );
        require(os, "Transaction Failed!!");
    }

    function rescueTokens(
        address _token,
        address recipient,
        uint _amount
    ) external onlyOwner {
        (bool success, ) = address(_token).call(
            abi.encodeWithSignature(
                "transfer(address,uint256)",
                recipient,
                _amount
            )
        );
        require(success, "Token payment failed");
    }

    function setFeeSetting(
        uint _buyMarketing,
        uint _buyReward,
        uint _sellMarketing,
        uint _sellReward
    ) external onlyOwner {
        uint buy_Subtotal;
        uint sell_Subtotal;

        fee.buyRewardFee = _buyReward;
        fee.buyMarketingFee = _buyMarketing;

        fee.sellMarketingFee = _sellMarketing;
        fee.sellRewardFee = _sellReward;

        buy_Subtotal = _buyReward.add(_buyMarketing);
        sell_Subtotal = _sellMarketing.add(_sellReward);

        require(
            buy_Subtotal >= 1 && sell_Subtotal >= 1,
            "Error: Cant set less tax than 1%"
        );
        require(
            buy_Subtotal <= 30 && sell_Subtotal <= 30,
            "Error: Cant set more tax than 30%"
        );
    }

    function setChargeFee(address _adr, bool _status) external onlyOwner {
        IsChargePair[_adr] = _status;
    }

    function setDistributorSettings(uint256 gas) external onlyOwner {
        require(gas < 750000, "Gas must be lower than 750000");
        distributorGas = gas;
    }

    function openTrade() external onlyOwner {
        require(!launched, "Already Enabled!");
        launched = true;
    }

    function setAntiWhalePercentage(uint256 _per) external onlyOwner {
        require(
            _per >= 5 && AntiWhaleActive,
            "Minimum Limit is 0.5% or Whale Must be Active"
        );
        maxTransaction = _totalSupply.mul(_per).div(1000);
        maxWallet = _totalSupply.mul(_per).div(1000);
    }

    function removeLimits() external onlyOwner {
        maxTransaction = _totalSupply;
        maxWallet = _totalSupply;
        AntiWhaleActive = false;
    }

    function setIsDividendExempt(
        address holder,
        bool exempt
    ) external onlyOwner {
        require(holder != address(this) && !IsChargePair[holder]);
        isDividendExempt[holder] = exempt;

        if (exempt) {
            distributor.setShare(holder, 0);
        } else {
            distributor.setShare(holder, balanceOf(holder));
        }
    }

    function setSwapBackSettings(
        bool _enabled,
        bool _limited,
        uint _threshold
    ) external onlyOwner {
        swapEnabled = _enabled;
        swapbylimit = _limited;
        swapThreshold = _threshold;
    }
}
