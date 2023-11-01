// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import {Test, console} from "forge-std/Test.sol";
import {PuppyRaffle} from "../src/PuppyRaffle.sol";

// import {HarnessContract} from "../test/harness/HarnessContract.sol";

contract PuppyRaffleTest is Test {
    PuppyRaffle puppyRaffle;
    // HarnessContract harness;
    uint256 entranceFee = 1 wei; // fuzz with random entrance fee
    address playerOne = address(1);
    address playerTwo = address(2);
    address playerThree = address(3);
    address playerFour = address(4);
    address feeAddress = address(99);

    // fuzz with random and unexpected addresses
    address puppyRaffleAddress;
    address zeroAddress = address(0);
    address owner = address(this);

    uint256 duration = 1 days;

    event RaffleEnter(address[] newPlayers);
    event RaffleRefunded(address player);

    function setUp() public {
        puppyRaffle = new PuppyRaffle(entranceFee, feeAddress, duration);
        // harness = new HarnessContract(puppyRaffle);

        puppyRaffleAddress = address(puppyRaffle);
    }

    //////////////////////
    /// EnterRaffle    ///
    /////////////////////

    function testCanEnterRaffle() public {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        assertEq(puppyRaffle.players(0), playerOne);
    }

    function testCantEnterWithoutPaying() public {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        vm.expectRevert("PuppyRaffle: Must send enough to enter raffle");
        puppyRaffle.enterRaffle(players);
    }

    function testCanEnterRaffleMany() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);
        assertEq(puppyRaffle.players(0), playerOne);
        assertEq(puppyRaffle.players(1), playerTwo);
    }

    function testCantEnterWithoutPayingMultiple() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        vm.expectRevert("PuppyRaffle: Must send enough to enter raffle");
        puppyRaffle.enterRaffle{value: entranceFee}(players);
    }

    function testCantEnterWithDuplicatePlayers() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerOne;
        vm.expectRevert("PuppyRaffle: Duplicate player");
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);
    }

    function testCantEnterWithDuplicatePlayersMany() public {
        address[] memory players = new address[](3);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerOne;
        vm.expectRevert("PuppyRaffle: Duplicate player");
        puppyRaffle.enterRaffle{value: entranceFee * 3}(players);
    }

    //////////////// Auditor's Test //////////////
    // forge test --match-test "testCantEnterWithDuplicatePlayerstwo" -vvv
    function testCantEnterWithDuplicatePlayerstwo() public {
        address[] memory players = new address[](1);
        address[] memory players2 = new address[](1);
        players[0] = playerOne;
        players2[0] = playerOne;
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        vm.expectRevert("PuppyRaffle: Duplicate player");
        puppyRaffle.enterRaffle{value: entranceFee}(players2);
    }

    function testCantEnterWithMoreThanEntranceFee() public {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        vm.expectRevert("PuppyRaffle: Must send enough to enter raffle");
        puppyRaffle.enterRaffle{value: entranceFee + 10}(players);
    }

    /**
    function testDoSVulnerability() public {
        address[] memory players;
        vm.expectRevert("PuppyRaffle: Must send enough to enter raffle");
        puppyRaffle.enterRaffle(players);
    }

    */

    //////////////////////
    /// Refund         ///
    //////////////////////
    modifier playerEntered() {
        address[] memory players = new address[](1);
        players[0] = playerOne;
        puppyRaffle.enterRaffle{value: entranceFee}(players);
        _;
    }

    function testCanGetRefund() public playerEntered {
        uint256 balanceBefore = address(playerOne).balance;
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);

        vm.prank(playerOne);
        puppyRaffle.refund(indexOfPlayer);

        assertEq(address(playerOne).balance, balanceBefore + entranceFee);
    }

    function testGettingRefundRemovesThemFromArray() public playerEntered {
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);

        vm.prank(playerOne);
        puppyRaffle.refund(indexOfPlayer);

        assertEq(puppyRaffle.players(0), address(0));
    }

    function testOnlyPlayerCanRefundThemself() public playerEntered {
        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);
        vm.expectRevert("PuppyRaffle: Only the player can refund");
        vm.prank(playerTwo);
        puppyRaffle.refund(indexOfPlayer);
    }

    function testEnterRaffleAndRefundAfterRaffleDuration()
        public
        playersEntered
    {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);
        ///@notice At this point the raffle is over, but a winner hasn't been selected yet

        address[] memory players = new address[](1);
        address playerFive = address(5);
        players[0] = playerFive;

        ///@notice One new players are entered
        vm.expectEmit(true, false, false, false);
        emit RaffleEnter(players);
        puppyRaffle.enterRaffle{value: entranceFee}(players);

        ///@notice The winner is selected
        vm.prank(playerFive);
        vm.expectEmit(true, false, false, false);
        emit RaffleRefunded(playerFive);
        puppyRaffle.refund(4);
    }

    // forge test --match-test "testOnlyPlayerCanRefundThemself" -vvv
    //////////////// Auditor's Test //////////////
    /*
    /// @notice This test failed invalidating my assumption that the the sendValue will fail silently

    function testPlayerCanLossRefund() public playerEntered {
        uint256 balanceBefore = address(playerOne).balance;
        // uint256 raffleInitialBalance = address(puppyRaffle).balance;
        puppyRaffle.resetBalance();

        uint256 indexOfPlayer = puppyRaffle.getActivePlayerIndex(playerOne);

        // And Player is active
        vm.prank(playerOne);
        assertEq(puppyRaffle._isActivePlayer(), true);

        vm.prank(playerOne);
        puppyRaffle.refund(indexOfPlayer);

        // No difference in balance after refund, thus refunds
        assertEq(address(playerOne).balance, balanceBefore);

        // And Player is no longer active
        assertEq(puppyRaffle._isActivePlayer(), false);
    }
    */

    /////////////////////////////
    /// getActivePlayerIndex  ///
    /////////////////////////////
    function testGetActivePlayerIndexManyPlayers() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);

        assertEq(puppyRaffle.getActivePlayerIndex(playerOne), 0);
        assertEq(puppyRaffle.getActivePlayerIndex(playerTwo), 1);
    }

    //////////////// Auditor's Test //////////////
    // forge test --match-test "testReturnZeroForNonActivePlayer" -vvv
    function testReturnZeroForNonActivePlayer() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);

        assertEq(puppyRaffle.getActivePlayerIndex(playerThree), 0);
    }

    function testReturnZeroForNonActivePlayerAndActivePlayers() public {
        address[] memory players = new address[](2);
        players[0] = playerOne;
        players[1] = playerTwo;
        puppyRaffle.enterRaffle{value: entranceFee * 2}(players);

        /// @notice playerThree is not active, and return 0
        assertEq(puppyRaffle.getActivePlayerIndex(playerThree), 0);

        /// @notice playerOne is active, and return 0
        assertEq(puppyRaffle.getActivePlayerIndex(playerOne), 0);
    }

    //////////////////////
    /// selectWinner   ///
    /////////////////////
    modifier playersEntered() {
        address[] memory players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);
        _;
    }

    function testCantSelectWinnerBeforeRaffleEnds() public playersEntered {
        vm.expectRevert("PuppyRaffle: Raffle not over");
        puppyRaffle.selectWinner();
    }

    function testCantSelectWinnerWithFewerThanFourPlayers() public {
        address[] memory players = new address[](3);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = address(3);
        puppyRaffle.enterRaffle{value: entranceFee * 3}(players);

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        vm.expectRevert("PuppyRaffle: Need at least 4 players");
        puppyRaffle.selectWinner();
    }

    /// Use this to prove winner predictability
    function testSelectWinner() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.previousWinner(), playerFour);
    }

    function testSelectWinnerGetsPaid() public playersEntered {
        uint256 balanceBefore = address(playerFour).balance;

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 expectedPayout = (((entranceFee * 4) * 80) / 100);

        puppyRaffle.selectWinner();
        assertEq(address(playerFour).balance, balanceBefore + expectedPayout);
    }

    function testSelectWinnerGetsAPuppy() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.balanceOf(playerFour), 1);
    }

    /// Use this to prove puppy predictability
    function testPuppyUriIsRight() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        string
            memory expectedTokenUri = "data:application/json;base64,eyJuYW1lIjoiUHVwcHkgUmFmZmxlIiwgImRlc2NyaXB0aW9uIjoiQW4gYWRvcmFibGUgcHVwcHkhIiwgImF0dHJpYnV0ZXMiOiBbeyJ0cmFpdF90eXBlIjogInJhcml0eSIsICJ2YWx1ZSI6IGNvbW1vbn1dLCAiaW1hZ2UiOiJpcGZzOi8vUW1Tc1lSeDNMcERBYjFHWlFtN3paMUF1SFpqZmJQa0Q2SjdzOXI0MXh1MW1mOCJ9";

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.tokenURI(0), expectedTokenUri);
    }

    //////////////// Auditor's Test //////////////
    // forge test --match-test "testPlayersArrayIsEmptyAfterWinnerSelection" -vvv

    function testPlayersArrayIsEmptyAfterWinnerSelection()
        public
        playersEntered
    {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        puppyRaffle.selectWinner();
        assertEq(puppyRaffle.getPlayersLength(), 0);
    }

    function testWinnerLossesSomeFunds() public playersEntered {
        uint256 balanceBefore = address(playerFour).balance;

        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 expectedPayout = (((entranceFee * 4) * 80) / 100);
        /// @notice Actual result is (((1 wei * 4) * 80) / 100) == 3.2
        /// @notice But solidity returns 3

        puppyRaffle.selectWinner();
        assertEq(address(playerFour).balance, balanceBefore + expectedPayout);
        assertEq(address(playerFour).balance, balanceBefore + 3);
    }

    //////////////////////
    /// withdrawFees     ///
    /////////////////////
    function testCantWithdrawFeesIfPlayersActive() public playersEntered {
        vm.expectRevert("PuppyRaffle: There are currently players active!");
        puppyRaffle.withdrawFees();
    }

    function testWithdrawFees() public playersEntered {
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        uint256 expectedPrizeAmount = ((entranceFee * 4) * 20) / 100;

        puppyRaffle.selectWinner();
        puppyRaffle.withdrawFees();
        assertEq(address(feeAddress).balance, expectedPrizeAmount);
    }

    function testAccountLogic() public playersEntered {
        /// @notice playerOne gets refund
        vm.prank(playerOne);
        puppyRaffle.refund(0);

        /// @notice playerTwo gets refund
        vm.prank(playerTwo);
        puppyRaffle.refund(1);

        /// @notice playerThree gets refund
        vm.prank(playerThree);
        puppyRaffle.refund(2);

        /// @notice raffle ends and winner is selected
        vm.prank(address(this));
        vm.warp(block.timestamp + duration + 1);
        vm.roll(block.number + 1);

        vm.expectRevert("PuppyRaffle: Failed to send prize pool to winner");
        puppyRaffle.selectWinner();
    }
}
