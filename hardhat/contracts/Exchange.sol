//SPDX-License-Identifier:MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Exchange is ERC20 {
    address public cryptoDevTokenAddress;

    constructor(address _CryptoDevToken) ERC20("CryptoDev LP Token", "CDLP"){
        require(_CryptoDevToken != address(0), "Token address passed is a null address");
        cryptoDevTokenAddress = _CryptoDevToken;
    }


    // returns the amount of Crypto Dev Tokens held by the contract
    function getReserve() public view returns (uint){
        return ERC20(cryptoDevTokenAddress).balanceOf(address(this));
    }

    // adds liquidity to the exchange
    function addLiquidity(uint _amount) public payable returns (uint) {
        uint liquidity;
        uint ethBalance = address(this).balance;
        uint cryptoDevTokenReserve = getReserve();
        ERC20 cryptoDevToken = ERC20(cryptoDevTokenAddress);

        // if the reserve is empty, intake any supplied value for ether and crypto dev token 
        // because there is no ratio currently 
        if(cryptoDevTokenReserve == 0){
            cryptoDevToken.transferFrom(msg.sender, address(this), _amount);
            // LP tokens provided is equal to the eth balance 
            liquidity = ethBalance;
            _mint(msg.sender, liquidity);
        } else {
            uint ethReserve = ethBalance - msg.value;
            // determine the token amount that user can add 
            // based on ratio (cryptoDevToken user can add / cryptoDevTokenReserve) = (eth sent by user / eth reserve)

            uint cryptoDevTokenAmount = (msg.value * cryptoDevTokenReserve) / ethReserve;
            require(_amount >= cryptoDevTokenAmount, "Amount of tokens sent less than the minimum tokens required");

            cryptoDevToken.transferFrom(msg.sender, address(this), cryptoDevTokenAmount);

            // number of LP tokens to be sent to user / LP tokens total supply in contract = eth sent by user / ethreserve
            liquidity = (totalSupply() * msg.value) / ethReserve;
            _mint(msg.sender, liquidity);
        }
        return liquidity;
    }

    // returns the amount of Eth/CryptoDev Token to the user 
    function removeLiquidity(uint _amount) public returns (uint, uint) {
        require(_amount > 0, "_amount should be more than 0");
        uint ethReserve = address(this).balance;
        uint _totalSupply = totalSupply();

        uint ethAmount = ( ethReserve * _amount ) / _totalSupply;
        uint cryptoDevTokenAmount = ( getReserve() * _amount ) / _totalSupply;
        // burn the LP tokens from the user's wallet 
        _burn(msg.sender, _amount);
        // transfer ethAmount from contract to user's wallet
        payable(msg.sender).transfer(ethAmount);
        // transfer cryptoDevTokenAMount from contract to user's wallet
        ERC20(cryptoDevTokenAddress).transfer(msg.sender, cryptoDevTokenAmount);
        return (ethAmount, cryptoDevTokenAmount);
    }

    // return the amount of eth/cryptodev tokens that would be returned to the user in the swap
    function getAmountOfTokens(
        uint256 inputAmount, 
        uint256 inputReserve, 
        uint256 outputReserve
    ) public pure returns (uint256){
        require(inputReserve > 0 && outputReserve > 0, "invalid reserves");
        //charging a fee of 1%
        uint256 inputAmountWithFee = inputAmount * 99;

        //based on a formula (x + ^x) * (y - ^y) = xy
        // final formula become ^y = (y * ^x) / (x + ^x)
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = (inputReserve * 100) + inputAmountWithFee;
        return numerator / denominator;
    }

    // swaps eth for cryptodev tokens
    function ethToCryptoDevToken(uint _minTokens) public payable {
        uint256 tokenReserve = getReserve();

        uint256 tokensBought = getAmountOfTokens(
            msg.value, 
            address(this).balance - msg.value,
            tokenReserve
        );

        require(tokensBought >= _minTokens, "insufficient output amount");
        //transfer the crypto dev tokens to the user
        ERC20(cryptoDevTokenAddress).transfer(msg.sender, tokensBought);
    }

    // swaps crypto dev tokens for Eth 
    function cryptoDevTokenToEth(uint _tokensSold, uint _minEth) public payable {
        uint256 tokenReserve = getReserve();

        uint256 ethBought = getAmountOfTokens(
            _tokensSold,
            tokenReserve,
            address(this).balance
        );

        require(ethBought >= _minEth, "Insufficient output amount");
        // transfer the cryptoDev token from the user's address to the contract
        ERC20(cryptoDevTokenAddress).transferFrom(msg.sender, address(this), _tokensSold);
        //send the eth to the user from the contract
        payable(msg.sender).transfer(ethBought);
    }   

}