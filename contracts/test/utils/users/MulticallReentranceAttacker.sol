// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

import {AsksV1_1} from "../../../modules/Asks/V1.1/AsksV1_1.sol";
import {Multicall} from "../../../common/Multicall/Multicall.sol";
import {ZoraModuleManager} from "../../../ZoraModuleManager.sol";

contract MulticallReentranceAttacker is ERC721Holder, ERC1155Holder {
    ZoraModuleManager internal ZMM;
    AsksV1_1 internal ASK;

    constructor(address _ZMM, address _ASK) {
        ZMM = ZoraModuleManager(_ZMM);
        ASK = AsksV1_1(_ASK);
    }

    /// ------------ ZORA Module Approvals ------------

    function setApprovalForModule(address _module, bool _approved) public {
        ZMM.setApprovalForModule(_module, _approved);
    }

    event Received(address sender, uint256 amount, uint256 balance);

    receive() external payable {
        emit Received(msg.sender, msg.value, address(this).balance);
        Multicall.Call[] memory calls = new Multicall.Call[](0);
        ASK.aggregate(calls);
    }
}
