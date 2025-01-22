// SPDX-License-Identifier: UNLICENSED 
pragma solidity ^0.8.12;

import {ServiceManagerBase, IAVSDirectory, IRewardsCoordinator, IServiceManager} from "eigenlayer-middleware/ServiceManagerBase.sol";
import {IRegistryCoordinator} from "eigenlayer-middleware/interfaces/IRegistryCoordinator.sol";
import {IStakeRegistry} from "eigenlayer-middleware/interfaces/IStakeRegistry.sol";

contract MinimalServiceManager is ServiceManagerBase {
    constructor(
        IAVSDirectory __avsDirectory,
        IRewardsCoordinator __rewardsCoordinator,
        IRegistryCoordinator __registryCoordinator,
        IStakeRegistry __stakeRegistry
    )
        ServiceManagerBase(
            __avsDirectory,
            __rewardsCoordinator,
            __registryCoordinator,
            __stakeRegistry
        )
    { }

    function initialize(
        address initialOwner,
        address _rewardsInitiator
    ) external initializer {
        __ServiceManagerBase_init(initialOwner, _rewardsInitiator);
    }
}
