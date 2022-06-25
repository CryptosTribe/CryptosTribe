// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./EnumerableMap.sol";

interface IPancakeSwapRouter {
    function getAmountsOut(uint256 amountIn, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts);
}

interface IGAME {
    function updateBoxStatus(address account) external returns (bool);
}

contract CryptosTribeGame is Ownable, Pausable, IGAME {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    uint256 private lotterWinnings;
    uint256 private lotteryNumber = 1;
    uint256 private constant _MAX = 10**18;

    uint256 private boxBurnTotal;

    IPancakeSwapRouter public router;
    address public token;
    address public nft;
    address public wbnb;
    address public pveBonusesPool;
    address public lotteryBonusesPool;

    EnumerableSet.AddressSet private purchaseHistory;
    EnumerableMap.AddressToUintMap private unOpenedBox;
    mapping(uint256 => mapping(address => EnumerableSet.UintSet))
        private lotteryStatus;
    mapping(address => uint256[2]) private userBonus;
    struct BonusesData {
        address account;
        uint256 userAmount;
        uint256 burnAmount;
        uint256 timestamp;
    }
    uint256 private bonusesIndex;
    mapping(uint256 => BonusesData) private bonusesData;

    event Box(
        address indexed from,
        uint256 price,
        uint256 num,
        uint256 timestamp
    );
    event Bonuses(address indexed to, uint256 amount, uint256 timestamp);
    event LotteryInfo(address indexed from, uint256 amount, uint256 timestamp);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    constructor(
        address _token,
        address _nft,
        address _router,
        address _wbnb,
        address _pveBonusesPool,
        address _lotteryBonusesPool
    ) {
        token = _token;
        nft = _nft;
        router = IPancakeSwapRouter(_router);
        wbnb = _wbnb;
        pveBonusesPool = _pveBonusesPool;
        lotteryBonusesPool = _lotteryBonusesPool;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function calculateFee(
        uint256 amount,
        uint256 fee,
        uint256 acc
    ) private pure returns (uint256) {
        return amount.mul(fee).div(acc);
    }

    function openRandomBox(uint256 num) external whenNotPaused returns (bool) {
        address from = _msgSender();
        require(num == 1 || num == 3, "Box: Wrong quantity");
        require(!purchaseHistory.contains(from), "Box: Opening");

        address[] memory path = new address[](2);
        path[0] = wbnb;
        path[1] = token;
        uint256 amountIn = 100000000000000000;
        uint256[] memory amountOut = getSwapAmount(path, amountIn);

        uint256 amount;
        if (num == 3) {
            amount = calculateFee(amountOut[1], 280, 100);
        } else {
            amount = amountOut[1];
        }

        boxBurnTotal += amount;
        IERC20(token).transferFrom(from, address(0), amount);

        unOpenedBox.set(from, num);
        purchaseHistory.add(from);
        emit Box(from, amountOut[1], num, block.timestamp);
        emit Transfer(from, address(0), amountOut[1]);
        return true;
    }

    function getBoxStatus(address account)
        external
        view
        whenNotPaused
        returns (bool, uint256)
    {
        return unOpenedBox.tryGet(account);
    }

    function getAllBox() external view returns (address[] memory) {
        return purchaseHistory.values();
    }

    function updateBoxStatus(address account)
        public
        virtual
        override
        whenNotPaused
        returns (bool)
    {
        require(_msgSender() == nft, "no permission");
        require(purchaseHistory.contains(account), "Box: not exists");
        unOpenedBox.remove(account);
        purchaseHistory.remove(account);
        return true;
    }

    function updatePVEBonuses(
        address account,
        uint256 _userAmount,
        uint256 _burnAmount
    ) public onlyOwner whenNotPaused {
        uint256 userAmount = userBonus[account][0];
        uint256 burnAmount = userBonus[account][1];
        userBonus[account] = [
            userAmount.add(_userAmount),
            burnAmount.add(_burnAmount)
        ];
    }

    function giveOutBonuses() public {
        uint256 userAmount = userBonus[msg.sender][0];
        uint256 burnAmount = userBonus[msg.sender][1];
        userBonus[msg.sender] = [0, 0];

        require(
            IERC20(token).balanceOf(pveBonusesPool) >=
                (userAmount + burnAmount),
            "PVE: Bonuses not enough"
        );

        // user
        IERC20(token).transferFrom(pveBonusesPool, msg.sender, userAmount);
        // burn
        IERC20(token).transferFrom(pveBonusesPool, address(0), burnAmount);

        bonusesData[bonusesIndex] = BonusesData(
            msg.sender,
            userAmount,
            burnAmount,
            block.timestamp
        );
        bonusesIndex = bonusesIndex.add(1);
        emit Bonuses(pveBonusesPool, userAmount, block.timestamp);
    }

    function getMyBonuses(address account) external view returns (uint256) {
        uint256 userAmount = userBonus[account][0];
        return userAmount;
    }

    function getBonusesRecordCount() external view returns (uint256) {
        return bonusesIndex;
    }

    function getBonusesRecord(uint256 index)
        external
        view
        returns (BonusesData memory)
    {
        return bonusesData[index];
    }

    function buyLottery(uint256 amount, uint256 timestamp)
        public
        whenNotPaused
        returns (bool)
    {
        address account = _msgSender();
        require(
            amount % (100 * _MAX) == 0,
            "Lottery: Amount must be a multiple of 100"
        );
        require(
            IERC20(token).balanceOf(account) >= amount,
            "ERCO20: Balance not enough"
        );
        IERC20(token).transferFrom(account, lotteryBonusesPool, amount);

        lotteryStatus[lotteryNumber][account].add(timestamp);

        lotterWinnings += amount;

        emit LotteryInfo(account, amount, timestamp);
        return true;
    }

    function verifyLotteryStatus(address account, uint256 timestamp)
        public
        view
        returns (bool)
    {
        return lotteryStatus[lotteryNumber][account].contains(timestamp);
    }

    function lotteryBonus(
        address[] memory addrList,
        uint256[] memory userAmountList,
        uint256[] memory burnAmountList,
        bool status
    ) public onlyOwner whenNotPaused returns (bool) {
        require(
            addrList.length == userAmountList.length,
            "Not the same length"
        );
        for (uint256 i = 0; i < addrList.length; i++) {
            address userAddress = addrList[i];
            uint256 userAmount = userAmountList[i];
            uint256 burnAmount = burnAmountList[i];

            uint256 total = userAmount + burnAmount;

            require(
                IERC20(token).balanceOf(lotteryBonusesPool) >= total,
                "Bonus pool amount not enough"
            );

            // user
            IERC20(token).transferFrom(
                lotteryBonusesPool,
                userAddress,
                userAmount
            );

            // burn
            IERC20(token).transferFrom(
                lotteryBonusesPool,
                address(0),
                burnAmount
            );

            if (lotterWinnings >= total) {
                lotterWinnings -= total;
            }
            delete lotteryStatus[lotteryNumber][userAddress];
        }

        if (status) {
            lotteryNumber += 1;
            IERC20(token).transferFrom(
                lotteryBonusesPool,
                address(0),
                lotterWinnings
            );
            lotterWinnings = 0;
        }
        return true;
    }

    function randomBoxBurnTotal() public view returns (uint256) {
        return boxBurnTotal;
    }

    function getSwapAmount(address[] memory path, uint256 amountIn)
        public
        view
        returns (uint256[] memory)
    {
        uint256[] memory amountOut = router.getAmountsOut(amountIn, path);
        return amountOut;
    }
}
