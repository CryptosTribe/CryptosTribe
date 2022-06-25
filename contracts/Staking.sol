// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CryptosTribeNFTStaking is Ownable, Pausable {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;

    IERC721 public nft;
    IERC20 public token;
    address public stakingBonusesPool;

    uint256 private constant MAX = 10**18;

    EnumerableSet.AddressSet private stakingAddress;
    mapping(address => EnumerableSet.UintSet) private stakingTokenList;
    mapping(uint256 => uint256[3]) private stakingTokenInfo;

    event Stake(
        address indexed from,
        uint256 tokenId,
        uint256 tokenAmount,
        uint8 typeId,
        uint256 timestamp
    );
    event Unstake(
        address indexed to,
        uint256 tokenId,
        uint256 rewardAmount,
        uint256 timestamp
    );

    constructor(
        address _token,
        address _nft,
        address _stakingBonusesPool
    ) {
        token = IERC20(_token);
        nft = IERC721(_nft);
        stakingBonusesPool = _stakingBonusesPool;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function stake(
        uint256 tokenId,
        uint256 amount,
        uint8 typeId
    ) external whenNotPaused returns (bool) {
        address account = _msgSender();
        require(
            !stakingTokenList[account].contains(tokenId),
            "NFT: Token was staking"
        );
        require(nft.ownerOf(tokenId) == account, "NFT: caller not owner");
        require(typeId >= 1 || typeId <= 4, "Staking type error");
        require(
            amount / MAX >= 2000,
            "Staking token num must greater than 2000"
        );

        nft.transferFrom(account, address(this), tokenId);
        token.transferFrom(account, stakingBonusesPool, amount);

        stakingTokenList[account].add(tokenId);
        stakingTokenInfo[tokenId] = [amount, typeId, block.timestamp];

        if (!stakingAddress.contains(account)) {
            stakingAddress.add(account);
        }
        emit Stake(account, tokenId, amount, typeId, block.timestamp);
        return true;
    }

    function unstake(
        uint256 tokenId,
        address account,
        uint256 amount,
        uint256 burnAmount
    ) public onlyOwner whenNotPaused returns (bool) {
        require(
            stakingTokenList[account].contains(tokenId),
            "NFT: Token not staking"
        );

        nft.transferFrom(address(this), account, tokenId);
        token.transferFrom(stakingBonusesPool, account, amount);
        token.transferFrom(stakingBonusesPool, address(0), burnAmount);
        stakingTokenList[account].remove(tokenId);
        delete stakingTokenInfo[tokenId];

        if (stakingTokenList[account].length() == 0) {
            stakingAddress.remove(account);
        }
        emit Unstake(account, block.timestamp, tokenId, amount);
        return true;
    }

    function getStakingToken(address account)
        public
        view
        returns (uint256[] memory)
    {
        return stakingTokenList[account].values();
    }

    function allStakingAddress() public view returns (address[] memory) {
        return stakingAddress.values();
    }

    function getStakeTokenIdInfo(uint256 tokenId)
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256[3] memory temp = stakingTokenInfo[tokenId];
        return (temp[0], temp[1], temp[2]);
        //return tokenAmount, stakeType, stakeTimestamp;
    }
}
