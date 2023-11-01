// SPDX-License-Identifier: MIT
// @audit outdated solidity version
// @audit carrot sign on version
pragma solidity ^0.7.6;

// @audit check if imports are up to date, and breaking changes that might affect the contract
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Base64} from "lib/base64/base64.sol";

contract PuppyRaffle is ERC721, Ownable {
    /// @audit why use Address for address payable here???
    /// @audit would this cause address not to receive ether??? Answer: No
    using Address for address payable;

    uint256 public immutable entranceFee;

    address[] public players;
    uint256 public raffleDuration;
    uint256 public raffleStartTime;
    address public previousWinner;

    address public feeAddress;
    /// @audit why is totalFees instantiated before constructor?
    /// @audit is total balance reset after every raffle?
    uint64 public totalFees = 0;

    mapping(uint256 => uint256) public tokenIdToRarity;
    mapping(uint256 => string) public rarityToUri;
    mapping(uint256 => string) public rarityToName;

    /// @audit Functions for updating these external URI values should provided incase of uncertainties
    string private commonImageUri =
        "ipfs://QmSsYRx3LpDAb1GZQm7zZ1AuHZjfbPkD6J7s9r41xu1mf8";
    uint256 public constant COMMON_RARITY = 70;
    string private constant COMMON = "common";

    string private rareImageUri =
        "ipfs://QmUPjADFGEKmfohdTaNcWhp7VGk26h5jXDA7v3VtTnTLcW";
    uint256 public constant RARE_RARITY = 25;
    string private constant RARE = "rare";

    string private legendaryImageUri =
        "ipfs://QmYx6GsYAKnNzZ9A6NvEKV9nf1VaDzJrqDR23Y8YSkebLU";
    uint256 public constant LEGENDARY_RARITY = 5;
    string private constant LEGENDARY = "legendary";

    event RaffleEnter(address[] newPlayers);

    /// @audit Unindexed event parameters
    event RaffleRefunded(address player);
    event FeeAddressChanged(address newFeeAddress);

    constructor(
        uint256 _entranceFee,
        address _feeAddress,
        uint256 _raffleDuration
    ) ERC721("Puppy Raffle", "PR") {
        /// @audit No Input Validation: The constructor does not validate the inputs.
        /// For example, it does not check if the _feeAddress is a zero address or
        /// if the _entranceFee and _raffleDuration are reasonable values.
        /// This could potentially lead to unexpected behavior or loss of funds.
        /// @audit Lacks zero address check
        entranceFee = _entranceFee;

        /// @audit Emit an appropriate event for any non-immutable variable set in the constructor that emits an event when mutated elsewhere.
        feeAddress = _feeAddress;
        raffleDuration = _raffleDuration;
        raffleStartTime = block.timestamp;

        rarityToUri[COMMON_RARITY] = commonImageUri;
        rarityToUri[RARE_RARITY] = rareImageUri;
        rarityToUri[LEGENDARY_RARITY] = legendaryImageUri;

        rarityToName[COMMON_RARITY] = COMMON;
        rarityToName[RARE_RARITY] = RARE;
        rarityToName[LEGENDARY_RARITY] = LEGENDARY;
    }

    /// @audit players can still enter the raffle even after raffle is over,
    /// as long as no one calls the selectWinner() function
    /// Scenario: player enters ended raffle, checks if they'll win,
    /// calls the selectWinner() or refund() function depending on favourable outcome
    function enterRaffle(address[] memory newPlayers) public payable {
        require(
            /// @audit charges entrance fee to participants
            /// @audit Tx is fee if newPlayers.length is zero
            /// @audit precise equality
            msg.value == entranceFee * newPlayers.length,
            "PuppyRaffle: Must send enough to enter raffle"
        );
        for (uint256 i = 0; i < newPlayers.length; i++) {
            players.push(newPlayers[i]);
        }

        /// @audit nested for loop ???
        /// @audit can an empty array underflow and give a player.length too long to loop
        for (uint256 i = 0; i < players.length - 1; i++) {
            for (uint256 j = i + 1; j < players.length; j++) {
                require(
                    players[i] != players[j],
                    "PuppyRaffle: Duplicate player"
                );
            }
        }
        emit RaffleEnter(newPlayers);
    }

    /// @audit players can get refunded even after raffle is over,
    /// as long as no one calls the selectWinner() function
    function refund(uint256 playerIndex) public {
        /// @audit how does the caller know their index?
        address playerAddress = players[playerIndex];
        require(
            playerAddress == msg.sender,
            "PuppyRaffle: Only the player can refund"
        );
        require(
            playerAddress != address(0),
            "PuppyRaffle: Player already refunded, or is not active"
        );

        /// @audit CEI not followed. Potential reentrancy
        /// @audit lacks check for Tx success
        payable(msg.sender).sendValue(entranceFee);

        /// @audit replace address(0) with the last element in players array
        /// and then pop the last element
        players[playerIndex] = address(0);
        emit RaffleRefunded(playerAddress);
    }

    function getActivePlayerIndex(
        address player
    ) external view returns (uint256) {
        for (uint256 i = 0; i < players.length; i++) {
            if (players[i] == player) {
                return i;
            }
        }
        /// @audit why return zero as a default, when zero is actually a valid array index?
        return 0;
    }

    function selectWinner() external {
        require(
            /// @audit Block values as time proxies only suitable for long timeframe
            block.timestamp >= raffleStartTime + raffleDuration,
            "PuppyRaffle: Raffle not over"
        );
        /// @audit statement assumes every array member is a valid player address
        require(players.length >= 4, "PuppyRaffle: Need at least 4 players");

        /// @audit weak random number generator
        uint256 winnerIndex = uint256(
            keccak256(
                abi.encodePacked(msg.sender, block.timestamp, block.difficulty)
            )
        ) % players.length;

        /// @audit players[winnerIndex] could a zero address
        /// @audit imagine 3 out of the 4 players refunded before a winner is selected
        address winner = players[winnerIndex];

        /// @audit if a player refunded before a winner is selected, totalAmountCollected will be inaccurate
        /// @audit contract balance must have equal or greater than totalAmountCollected at all times
        uint256 totalAmountCollected = players.length * entranceFee;

        /// @audit precision loss???
        uint256 prizePool = (totalAmountCollected * 80) / 100;

        /// @audit precision loss???
        /// @audit try an extreme (small) value for totalAmountCollected. Solidity don't work well with decimals
        /// @audit dust eth left that sets off the internal accounting???
        uint256 fee = (totalAmountCollected * 20) / 100;
        totalFees = totalFees + uint64(fee);

        /// @audit what's happening here???
        uint256 tokenId = totalSupply();

        /// @audit weak random number generator
        uint256 rarity = uint256(
            keccak256(abi.encodePacked(msg.sender, block.difficulty))
        ) % 100;
        if (rarity <= COMMON_RARITY) {
            tokenIdToRarity[tokenId] = COMMON_RARITY;
        } else if (rarity <= COMMON_RARITY + RARE_RARITY) {
            tokenIdToRarity[tokenId] = RARE_RARITY;
        } else {
            tokenIdToRarity[tokenId] = LEGENDARY_RARITY;
        }

        /// @audit Missing events for critical state changes
        /// @audit https://solodit.xyz/issues/m10-lack-of-events-emission-after-sensitive-actions-openzeppelin-holdefi-audit-markdown
        delete players;
        raffleStartTime = block.timestamp;
        previousWinner = winner;
        (bool success, ) = winner.call{value: prizePool}("");
        require(success, "PuppyRaffle: Failed to send prize pool to winner");
        _safeMint(winner, tokenId);
    }

    /// @audit no access control, anyone can call this function
    function withdrawFees() external {
        require(
            /// @audit accounting descrepancies caused by various enterRaffle() fees,
            /// and inaccurate totalFees calculated
            /// @audit anyone can force send eth into this contract to offset the accounting,
            /// and lock the contract funds permanently, despite not having any active players
            /// @audit Don't mix internal accounting with actual balances.
            /// @audit assumes this contract can only receive ether from entranceFee
            address(this).balance == uint256(totalFees),
            "PuppyRaffle: There are currently players active!"
        );
        uint256 feesToWithdraw = totalFees;
        totalFees = 0;
        (bool success, ) = feeAddress.call{value: feesToWithdraw}("");
        require(success, "PuppyRaffle: Failed to withdraw fees");
    }

    function changeFeeAddress(address newFeeAddress) external onlyOwner {
        /// @audit No Input Validation
        /// @audit zero address checks
        /// @audit address(this) checks
        feeAddress = newFeeAddress;
        /// @audit index event argument
        emit FeeAddressChanged(newFeeAddress);
    }

    function _isActivePlayer() internal view returns (bool) {
        /// @audit No Input Validation
        for (uint256 i = 0; i < players.length; i++) {
            if (players[i] == msg.sender) {
                return true;
            }
        }
        return false;
    }

    function _baseURI() internal pure returns (string memory) {
        return "data:application/json;base64,";
    }

    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        require(
            _exists(tokenId),
            "PuppyRaffle: URI query for nonexistent token"
        );

        uint256 rarity = tokenIdToRarity[tokenId];
        string memory imageURI = rarityToUri[rarity];
        string memory rareName = rarityToName[rarity];

        return
            string(
                abi.encodePacked(
                    _baseURI(),
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"',
                                name(),
                                '", "description":"An adorable puppy!", ',
                                '"attributes": [{"trait_type": "rarity", "value": ',
                                rareName,
                                '}], "image":"',
                                imageURI,
                                '"}'
                            )
                        )
                    )
                )
            );
    }
}
