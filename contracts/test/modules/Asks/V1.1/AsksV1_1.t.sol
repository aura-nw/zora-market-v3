// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {DSTest} from "ds-test/test.sol";

import {AsksV1_1} from "../../../../modules/Asks/V1.1/AsksV1_1.sol";
import {Zorb} from "../../../utils/users/Zorb.sol";
import {ZoraRegistrar} from "../../../utils/users/ZoraRegistrar.sol";
import {ZoraModuleManager} from "../../../../ZoraModuleManager.sol";
import {ZoraProtocolFeeSettings} from "../../../../auxiliary/ZoraProtocolFeeSettings/ZoraProtocolFeeSettings.sol";
import {ERC20TransferHelper} from "../../../../transferHelpers/ERC20TransferHelper.sol";
import {ERC721TransferHelper} from "../../../../transferHelpers/ERC721TransferHelper.sol";
import {RoyaltyEngine} from "../../../utils/modules/RoyaltyEngine.sol";
import {Multicall} from "../../../../common/Multicall/Multicall.sol";
import {MulticallReentranceAttacker} from "../../../utils/users/MulticallReentranceAttacker.sol";

import {TestERC721} from "../../../utils/tokens/TestERC721.sol";
import {WETH} from "../../../utils/tokens/WETH.sol";
import {VM} from "../../../utils/VM.sol";

/// @title AskV1_1Test
/// @notice Unit Tests for Asks v1.1
contract AsksV1_1Test is DSTest {
    VM internal vm;

    ZoraRegistrar internal registrar;
    ZoraProtocolFeeSettings internal ZPFS;
    ZoraModuleManager internal ZMM;
    ERC20TransferHelper internal erc20TransferHelper;
    ERC721TransferHelper internal erc721TransferHelper;
    RoyaltyEngine internal royaltyEngine;

    AsksV1_1 internal asks;
    TestERC721 internal token;
    TestERC721 internal otherToken;
    WETH internal weth;

    Zorb internal seller;
    Zorb internal sellerFundsRecipient;
    Zorb internal otherSellerFundsRecipient;
    Zorb internal operator;
    Zorb internal otherSeller;
    Zorb internal buyer;
    Zorb internal otherBuyer;
    Zorb internal finder;
    Zorb internal royaltyRecipient;
    MulticallReentranceAttacker internal attacker;

    function setUp() public {
        // Cheatcodes
        vm = VM(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

        // Deploy V3
        registrar = new ZoraRegistrar();
        ZPFS = new ZoraProtocolFeeSettings();
        ZMM = new ZoraModuleManager(address(registrar), address(ZPFS));
        erc20TransferHelper = new ERC20TransferHelper(address(ZMM));
        erc721TransferHelper = new ERC721TransferHelper(address(ZMM));

        // Init V3
        registrar.init(ZMM);
        ZPFS.init(address(ZMM), address(0));

        // Create users
        seller = new Zorb(address(ZMM));
        sellerFundsRecipient = new Zorb(address(ZMM));
        otherSellerFundsRecipient = new Zorb(address(ZMM));
        operator = new Zorb(address(ZMM));
        otherSeller = new Zorb(address(ZMM));
        buyer = new Zorb(address(ZMM));
        otherBuyer = new Zorb(address(ZMM));
        finder = new Zorb(address(ZMM));
        royaltyRecipient = new Zorb(address(ZMM));

        // Deploy mocks
        royaltyEngine = new RoyaltyEngine(address(royaltyRecipient));
        token = new TestERC721();
        otherToken = new TestERC721();
        weth = new WETH();

        // Deploy Asks v1.1
        asks = new AsksV1_1(address(erc20TransferHelper), address(erc721TransferHelper), address(royaltyEngine), address(ZPFS), address(weth));
        registrar.registerModule(address(asks));

        // attacker
        attacker = new MulticallReentranceAttacker(address(ZMM), address(asks));

        // Set user balances
        vm.deal(address(buyer), 100 ether);
        vm.deal(address(otherBuyer), 100 ether);
        vm.deal(address(attacker), 100 ether);

        // Mint seller token
        token.mint(address(seller), 0);
        otherToken.mint(address(seller), 1);
        token.mint(address(attacker), 1);
        token.mint(address(attacker), 2);

        // Buyer swap 50 ETH <> 50 WETH
        vm.prank(address(buyer));
        weth.deposit{value: 50 ether}();

        // Users approve Asks module
        seller.setApprovalForModule(address(asks), true);
        buyer.setApprovalForModule(address(asks), true);
        attacker.setApprovalForModule(address(asks), true);

        // Seller approve ERC721TransferHelper
        vm.prank(address(seller));
        token.setApprovalForAll(address(erc721TransferHelper), true);
        vm.prank(address(seller));
        otherToken.setApprovalForAll(address(erc721TransferHelper), true);
        vm.prank(address(attacker));
        token.setApprovalForAll(address(erc721TransferHelper), true);

        // Buyer approve ERC20TransferHelper
        vm.prank(address(buyer));
        weth.approve(address(erc20TransferHelper), 50 ether);
    }

    /// ------------ CREATE ASK ------------ ///

    function testGas_CreateAsk() public {
        vm.prank(address(seller));
        asks.createAsk(address(token), 0, 1 ether, address(0), address(sellerFundsRecipient), 1000);
    }

    function test_CreateAskFromTokenOwner() public {
        vm.prank(address(seller));
        asks.createAsk(address(token), 0, 1 ether, address(0), address(sellerFundsRecipient), 1000);

        (address askSeller, address fundsRecipient, address askCurrency, uint16 findersFeeBps, uint256 askPrice) = asks.askForNFT(address(token), 0);

        require(askSeller == address(seller));
        require(fundsRecipient == address(sellerFundsRecipient));
        require(askCurrency == address(0));
        require(askPrice == 1 ether);
        require(findersFeeBps == 1000);
    }

    function test_CreateAskFromTokenOperator() public {
        vm.prank(address(seller));
        token.setApprovalForAll(address(operator), true);

        operator.setApprovalForModule(address(asks), true);

        vm.prank(address(operator));
        asks.createAsk(address(token), 0, 0.5 ether, address(0), address(sellerFundsRecipient), 1000);

        (address askSeller, address fundsRecipient, address askCurrency, uint16 findersFeeBps, uint256 askPrice) = asks.askForNFT(address(token), 0);

        require(askSeller == address(seller));
        require(fundsRecipient == address(sellerFundsRecipient));
        require(askCurrency == address(0));
        require(askPrice == 0.5 ether);
        require(findersFeeBps == 1000);
    }

    function test_CreateAskAndCancelPreviousOwners() public {
        vm.prank(address(seller));
        asks.createAsk(address(token), 0, 1 ether, address(0), address(sellerFundsRecipient), 1000);

        (address askSeller, , , , ) = asks.askForNFT(address(token), 0);
        require(askSeller == address(seller));

        vm.prank(address(seller));
        token.safeTransferFrom(address(seller), address(otherSeller), 0);
        require(token.ownerOf(0) == address(otherSeller));

        otherSeller.setApprovalForModule(address(asks), true);

        vm.prank(address(otherSeller));
        token.setApprovalForAll(address(erc721TransferHelper), true);

        vm.prank(address(otherSeller));
        asks.createAsk(address(token), 0, 10 ether, address(0), address(sellerFundsRecipient), 1);

        (address newAskSeller, address fundsRecipient, address askCurrency, uint16 findersFeeBps, uint256 askPrice) = asks.askForNFT(
            address(token),
            0
        );

        require(newAskSeller == address(otherSeller));
        require(fundsRecipient == address(sellerFundsRecipient));
        require(askCurrency == address(0));
        require(askPrice == 10 ether);
        require(findersFeeBps == 1);
    }

    function testRevert_MustApproveERC721TransferHelper() public {
        vm.prank(address(seller));
        token.setApprovalForAll(address(erc721TransferHelper), false);

        vm.prank(address(seller));
        vm.expectRevert("createAsk must approve ERC721TransferHelper as operator");
        asks.createAsk(address(token), 0, 1 ether, address(0), address(sellerFundsRecipient), 1000);
    }

    function testFail_MustBeTokenOwnerOrOperator() public {
        asks.createAsk(address(token), 0, 1 ether, address(0), address(sellerFundsRecipient), 1000);
    }

    function testRevert_FindersFeeBPSCannotExceed10000() public {
        vm.prank(address(seller));
        vm.expectRevert("createAsk finders fee bps must be less than or equal to 10000");
        asks.createAsk(address(token), 0, 1 ether, address(0), address(sellerFundsRecipient), 10001);
    }

    function testRevert_SellerFundsRecipientCannotBeZeroAddress() public {
        vm.prank(address(seller));
        vm.expectRevert("createAsk must specify _sellerFundsRecipient");
        asks.createAsk(address(token), 0, 1 ether, address(0), address(0), 1001);
    }

    /// ------------ SET ASK PRICE ------------ ///

    function test_UpdateAskPrice() public {
        vm.startPrank(address(seller));

        asks.createAsk(address(token), 0, 1 ether, address(0), address(sellerFundsRecipient), 1000);
        asks.setAskPrice(address(token), 0, 5 ether, address(0));

        vm.stopPrank();

        (, , , , uint256 askPrice) = asks.askForNFT(address(token), 0);
        require(askPrice == 5 ether);
    }

    function testRevert_OnlySellerCanSetAskPrice() public {
        vm.prank(address(seller));
        asks.createAsk(address(token), 0, 1 ether, address(0), address(sellerFundsRecipient), 1000);

        vm.expectRevert("setAskPrice must be seller");
        asks.setAskPrice(address(token), 0, 5 ether, address(0));
    }

    function testFail_CannotUpdateCanceledAsk() public {
        vm.startPrank(address(seller));
        asks.createAsk(address(token), 0, 1 ether, address(0), address(sellerFundsRecipient), 1000);
        asks.cancelAsk(address(token), 0);
        asks.setAskPrice(address(token), 0, 5 ether, address(0));
        vm.stopPrank();
    }

    function testFail_CannotUpdateFilledAsk() public {
        vm.prank(address(seller));
        asks.createAsk(address(token), 0, 1 ether, address(0), address(sellerFundsRecipient), 1000);

        vm.prank(address(buyer));
        asks.fillAsk{value: 1 ether}(address(token), 0, address(0), 1 ether, address(finder));

        vm.prank(address(seller));
        asks.setAskPrice(address(token), 0, 5 ether, address(0));
    }

    /// ------------ CANCEL ASK ------------ ///

    function test_CancelAsk() public {
        vm.startPrank(address(seller));

        asks.createAsk(address(token), 0, 1 ether, address(0), address(sellerFundsRecipient), 1000);

        (, , , , uint256 beforeAskPrice) = asks.askForNFT(address(token), 0);
        require(beforeAskPrice == 1 ether);

        asks.cancelAsk(address(token), 0);

        (, , , , uint256 afterAskPrice) = asks.askForNFT(address(token), 0);
        require(afterAskPrice == 0);

        vm.stopPrank();
    }

    function testRevert_MsgSenderMustBeApprovedToCancelAsk() public {
        vm.prank(address(seller));
        asks.createAsk(address(token), 0, 1 ether, address(0), address(sellerFundsRecipient), 1000);

        vm.expectRevert("cancelAsk must be token owner or operator");
        asks.cancelAsk(address(token), 0);
    }

    function testRevert_AskMustExistToCancel() public {
        vm.expectRevert("cancelAsk ask doesn't exist");
        asks.cancelAsk(address(token), 0);
    }

    /// ------------ FILL ASK ------------ ///

    function test_FillAsk() public {
        vm.prank(address(seller));
        asks.createAsk(address(token), 0, 1 ether, address(0), address(sellerFundsRecipient), 1000);

        vm.prank(address(buyer));
        asks.fillAsk{value: 1 ether}(address(token), 0, address(0), 1 ether, address(finder));

        require(token.ownerOf(0) == address(buyer));
    }

    function testRevert_AskMustBeActiveToFill() public {
        vm.prank(address(seller));
        asks.createAsk(address(token), 0, 1 ether, address(0), address(sellerFundsRecipient), 1000);

        vm.prank(address(buyer));
        asks.fillAsk{value: 1 ether}(address(token), 0, address(0), 1 ether, address(finder));

        vm.expectRevert("fillAsk must be active ask");
        asks.fillAsk{value: 1 ether}(address(token), 0, address(0), 1 ether, address(finder));
    }

    function testRevert_FillCurrencyMustMatchAsk() public {
        vm.prank(address(seller));
        asks.createAsk(address(token), 0, 1 ether, address(weth), address(sellerFundsRecipient), 1000);

        vm.prank(address(buyer));
        vm.expectRevert("fillAsk _fillCurrency must match ask currency");
        asks.fillAsk(address(token), 0, address(0), 1 ether, address(finder));
    }

    function testRevert_FillAmountMustMatchAsk() public {
        vm.prank(address(seller));
        asks.createAsk(address(token), 0, 1 ether, address(weth), address(sellerFundsRecipient), 1000);

        vm.prank(address(buyer));
        vm.expectRevert("fillAsk _fillCurrency must match ask currency");
        asks.fillAsk(address(token), 0, address(0), 0.5 ether, address(finder));
    }

    /// ------------ MULTICALL ------------ ///
    function testMulticall_CreateAsks() public {
        vm.prank(address(seller));

        Multicall.Call[] memory calls = new Multicall.Call[](2);
        calls[0] = Multicall.Call(
            false,
            abi.encodeWithSelector(AsksV1_1.createAsk.selector, address(token), 0, 1 ether, address(0), address(sellerFundsRecipient), 1000)
        );
        calls[1] = Multicall.Call(
            false,
            abi.encodeWithSelector(AsksV1_1.createAsk.selector, address(otherToken), 1, 2 ether, address(0), address(otherSellerFundsRecipient), 1100)
        );
        asks.aggregate(calls);

        (address askSeller1, address fundsRecipient1, address askCurrency1, uint16 findersFeeBps1, uint256 askPrice1) = asks.askForNFT(
            address(token),
            0
        );
        require(askSeller1 == address(seller));
        require(fundsRecipient1 == address(sellerFundsRecipient));
        require(askCurrency1 == address(0));
        require(askPrice1 == 1 ether);
        require(findersFeeBps1 == 1000);

        (address askSeller2, address fundsRecipient2, address askCurrency2, uint16 findersFeeBps2, uint256 askPrice2) = asks.askForNFT(
            address(otherToken),
            1
        );
        require(askSeller2 == address(seller));
        require(fundsRecipient2 == address(otherSellerFundsRecipient));
        require(askCurrency2 == address(0));
        require(askPrice2 == 2 ether);
        require(findersFeeBps2 == 1100);
    }

    function testMulticall_FillAsks() public {
        vm.prank(address(seller));
        asks.createAsk(address(token), 0, 1 ether, address(0), address(sellerFundsRecipient), 1000);
        vm.prank(address(seller));
        asks.createAsk(address(otherToken), 1, 2 ether, address(0), address(otherSellerFundsRecipient), 1000);

        vm.prank(address(buyer));

        Multicall.Call[] memory fillCalls = new Multicall.Call[](2);
        fillCalls[0] = Multicall.Call(
            false,
            abi.encodeWithSelector(AsksV1_1.fillAsk.selector, address(token), 0, address(0), 1 ether, address(finder))
        );
        fillCalls[1] = Multicall.Call(
            true,
            abi.encodeWithSelector(AsksV1_1.fillAsk.selector, address(otherToken), 1, address(0), 2 ether, address(finder))
        );
        asks.aggregate{value: 3 ether}(fillCalls);

        require(token.ownerOf(0) == address(buyer));
        require(otherToken.ownerOf(1) == address(buyer));
    }

    function testMulticall_RequiredFillFail() public {
        vm.prank(address(seller));
        asks.createAsk(address(token), 0, 4 ether, address(0), address(sellerFundsRecipient), 1000);
        vm.prank(address(seller));
        asks.createAsk(address(otherToken), 1, 2 ether, address(0), address(otherSellerFundsRecipient), 1000);

        vm.prank(address(buyer));

        Multicall.Call[] memory fillCalls = new Multicall.Call[](2);
        fillCalls[0] = Multicall.Call(
            false,
            abi.encodeWithSelector(AsksV1_1.fillAsk.selector, address(token), 0, address(0), 4 ether, address(finder))
        );
        fillCalls[1] = Multicall.Call(
            true,
            abi.encodeWithSelector(AsksV1_1.fillAsk.selector, address(otherToken), 1, address(0), 2 ether, address(finder))
        );

        vm.expectRevert("Multicall: call failed");
        asks.aggregate{value: 3 ether}(fillCalls);

        require(token.ownerOf(0) == address(seller));
        require(otherToken.ownerOf(1) == address(seller));
    }

    function testMulticall_AskDoNotHoldEther() public {
        vm.prank(address(seller));
        asks.createAsk(address(token), 0, 1 ether, address(0), address(sellerFundsRecipient), 1000);
        vm.prank(address(seller));
        asks.createAsk(address(otherToken), 1, 2 ether, address(0), address(sellerFundsRecipient), 1000);

        vm.prank(address(buyer));

        Multicall.Call[] memory fillCalls = new Multicall.Call[](2);
        fillCalls[0] = Multicall.Call(
            false,
            abi.encodeWithSelector(AsksV1_1.fillAsk.selector, address(token), 0, address(0), 1 ether, address(finder))
        );
        fillCalls[1] = Multicall.Call(
            true,
            abi.encodeWithSelector(AsksV1_1.fillAsk.selector, address(otherToken), 1, address(0), 3 ether, address(finder))
        );

        asks.aggregate{value: 3 ether}(fillCalls);

        require(address(asks).balance == 0);
        require(token.ownerOf(0) == address(buyer));
        require(otherToken.ownerOf(1) == address(seller));
    }

    function testMulticall_FillAsksWithoutFund() public {
        vm.prank(address(seller));
        asks.createAsk(address(token), 0, 1 ether, address(0), address(sellerFundsRecipient), 1000);
        vm.prank(address(seller));
        asks.createAsk(address(otherToken), 1, 2 ether, address(0), address(sellerFundsRecipient), 1000);

        vm.prank(address(buyer));

        Multicall.Call[] memory fillCalls = new Multicall.Call[](2);
        fillCalls[0] = Multicall.Call(
            true,
            abi.encodeWithSelector(AsksV1_1.fillAsk.selector, address(token), 0, address(0), 1 ether, address(finder))
        );
        fillCalls[1] = Multicall.Call(
            true,
            abi.encodeWithSelector(AsksV1_1.fillAsk.selector, address(otherToken), 1, address(0), 3 ether, address(finder))
        );

        asks.aggregate(fillCalls);

        require(address(asks).balance == 0);
        require(token.ownerOf(0) == address(seller));
        require(otherToken.ownerOf(1) == address(seller));
    }

    function testMulticall_FillAsksNoAskFilled() public {
        vm.prank(address(seller));
        asks.createAsk(address(token), 0, 1 ether, address(0), address(sellerFundsRecipient), 1000);
        vm.prank(address(seller));
        asks.createAsk(address(otherToken), 1, 2 ether, address(0), address(sellerFundsRecipient), 1000);

        vm.prank(address(buyer));

        Multicall.Call[] memory fillCalls = new Multicall.Call[](2);
        fillCalls[0] = Multicall.Call(
            true,
            abi.encodeWithSelector(AsksV1_1.fillAsk.selector, address(token), 0, address(0), 2 ether, address(finder))
        );
        fillCalls[1] = Multicall.Call(
            true,
            abi.encodeWithSelector(AsksV1_1.fillAsk.selector, address(otherToken), 1, address(0), 3 ether, address(finder))
        );

        asks.aggregate{value: 1 ether}(fillCalls);

        require(address(asks).balance == 0);
        require(token.ownerOf(0) == address(seller));
        require(otherToken.ownerOf(1) == address(seller));
    }

    function testMulticall_MulticalReentranceAttack() public {
        uint256 previousBalance = address(attacker).balance;

        vm.prank(address(attacker));
        asks.createAsk(address(token), 1, 1 ether, address(0), address(attacker), 1000);
        vm.prank(address(attacker));
        asks.createAsk(address(token), 2, 2 ether, address(0), address(attacker), 1000);

        vm.prank(address(buyer));

        Multicall.Call[] memory fillCalls = new Multicall.Call[](2);
        fillCalls[0] = Multicall.Call(true, abi.encodeWithSelector(AsksV1_1.fillAsk.selector, address(token), 1, address(0), 1 ether, address(0)));
        fillCalls[1] = Multicall.Call(true, abi.encodeWithSelector(AsksV1_1.fillAsk.selector, address(token), 2, address(0), 2 ether, address(0)));
        asks.aggregate{value: 3 ether}(fillCalls);

        require(token.ownerOf(1) == address(buyer));
        require(token.ownerOf(2) == address(buyer));
        require(address(attacker).balance <= previousBalance);
    }
}
