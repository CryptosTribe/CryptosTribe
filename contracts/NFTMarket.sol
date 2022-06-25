// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract CryptosTribeNFTMarket is Ownable, Pausable {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    IERC721 public nft;
    IERC20 public token;
    address public target;
    uint256 private taxFee = 5;
    uint256 private feeCount;

    mapping(uint256 => address) private _tokenOwner;
    mapping(uint256 => uint256) private _tokenPriceList;
    mapping(uint256 => uint256) private _tokenOnSaleTime;
    mapping(address => EnumerableSet.UintSet) private _ownerAllToken;
    EnumerableSet.UintSet private _onSaleTokenList;
    EnumerableSet.UintSet private _soldTokenList;

    struct Order {
        address owner;
        address purchaser;
        uint256 tokenId;
        uint256 price;
        uint256 createTime;
        uint256 transactionTime;
    }

    uint256 private _soldTotal;
    mapping(uint256 => Order) private _orderData;

    event CreateOrder(
        address indexed from,
        uint256 indexed tokenId,
        uint256 indexed price
    );
    event CancelOrder(address indexed from, uint256 indexed tokenId);
    event BidsOrder(
        address indexed from,
        uint256 indexed tokenId,
        uint256 indexed price
    );

    constructor(address _token, address _nft) {
        token = IERC20(_token);
        nft = IERC721(_nft);
    }

    function calculateTaxFee(uint256 amount) private view returns (uint256) {
        return amount.mul(taxFee).div(10**2);
    }

    function changeTargetToken(address src) public onlyOwner {
        target = src;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function createOrder(uint256 tokenId, uint256 price)
        external
        whenNotPaused
        returns (bool)
    {
        require(
            !_onSaleTokenList.contains(tokenId),
            "Market: token was on sale"
        );
        address from = _msgSender();
        nft.transferFrom(from, address(this), tokenId);

        _tokenOwner[tokenId] = from;
        _tokenPriceList[tokenId] = price;
        _tokenOnSaleTime[tokenId] = block.timestamp;

        _ownerAllToken[from].add(tokenId);
        _onSaleTokenList.add(tokenId);

        if (_soldTokenList.contains(tokenId)) {
            _soldTokenList.remove(tokenId);
        }

        emit CreateOrder(from, tokenId, price);
        return true;
    }

    function cancelOrder(uint256 tokenId)
        external
        whenNotPaused
        returns (bool)
    {
        require(
            _onSaleTokenList.contains(tokenId),
            "Market: token not on sale"
        );
        require(!_soldTokenList.contains(tokenId), "Market: token was sold");

        address from = _msgSender();
        require(_tokenOwner[tokenId] == from, "NFT: not token owner");

        nft.transferFrom(address(this), from, tokenId);

        _onSaleTokenList.remove(tokenId);
        _ownerAllToken[from].remove(tokenId);

        delete _tokenOwner[tokenId];
        delete _tokenPriceList[tokenId];
        delete _tokenOnSaleTime[tokenId];

        emit CancelOrder(from, tokenId);
        return true;
    }

    function bidOrder(uint256 tokenId) external whenNotPaused returns (bool) {
        require(!_soldTokenList.contains(tokenId), "Market: token was sold");
        require(
            _onSaleTokenList.contains(tokenId),
            "Market: token not on sale"
        );
        // buyer
        address from = _msgSender();
        uint256 salePrice = _tokenPriceList[tokenId];
        uint256 fee = calculateTaxFee(salePrice);
        // seller amount
        uint256 amount0 = salePrice - fee;
        feeCount += fee;
        // to seller 95%
        token.transferFrom(from, _tokenOwner[tokenId], amount0);
        // 50% fee to pool
        token.transferFrom(from, target, fee);
        // 50% fee
        token.transferFrom(from, address(0), fee);

        nft.transferFrom(address(this), from, tokenId);

        _orderData[_soldTotal] = Order(
            _tokenOwner[tokenId],
            from,
            tokenId,
            salePrice,
            _tokenOnSaleTime[tokenId],
            block.timestamp
        );
        _soldTotal += 1;

        _soldTokenList.add(tokenId);

        _onSaleTokenList.remove(tokenId);
        _ownerAllToken[_tokenOwner[tokenId]].remove(tokenId);

        delete _tokenOwner[tokenId];
        delete _tokenPriceList[tokenId];
        delete _tokenOnSaleTime[tokenId];

        emit BidsOrder(from, tokenId, salePrice);
        return true;
    }

    function ownerAllToken(address account)
        external
        view
        returns (uint256[] memory)
    {
        return _ownerAllToken[account].values();
    }

    function tokenPrice(uint256 tokenId) external view returns (uint256) {
        return _tokenPriceList[tokenId];
    }

    function tokenOnSaleTime(uint256 tokenId) external view returns (uint256) {
        return _tokenOnSaleTime[tokenId];
    }

    function onSaleTokenList() external view returns (uint256[] memory) {
        return _onSaleTokenList.values();
    }

    function soldTokenList() external view returns (uint256[] memory) {
        return _soldTokenList.values();
    }

    function soldTotal() external view returns (uint256) {
        return _soldTotal;
    }

    function getOrderById(uint256 id) external view returns (Order memory) {
        return _orderData[id];
    }

    function taxFeeTotal() external view returns (uint256) {
        return feeCount;
    }
}
