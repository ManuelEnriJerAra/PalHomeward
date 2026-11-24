-- Paths from hook catalog H-001 through H-012, with parameter annotations from the PH-003 survey.
return {
    {
        id = "H-001",
        path = "/Script/Pal.PalNetworkBaseCampComponent:RequestMoveWorkerToPalBox_ToServer",
        params = {
            { name = "BaseCampId", type = "FGuid" },
            { name = "SlotId", type = "FPalCharacterSlotId" },
            { name = "CurrentPage", type = "int32" },
            { name = "ByMapObjectInstanceId", type = "FGuid" },
        },
    },
    {
        id = "H-002",
        path = "/Script/Pal.PalNetworkCharacterContainerComponent:RequestMoveToPalBox_ToServer_Rep",
        params = {
            { name = "SlotId", type = "FPalCharacterSlotId" },
            { name = "ContainerId", type = "FPalContainerId" },
            { name = "CurrentPage", type = "int32" },
        },
    },
    {
        id = "H-003",
        path = "/Script/Pal.PalNetworkCharacterContainerComponent:RequestMove_ToServer_Rep",
        params = {
            { name = "SlotId", type = "FPalCharacterSlotId" },
            { name = "ContainerId", type = "FPalContainerId" },
        },
    },
    {
        id = "H-004",
        path = "/Script/Pal.PalNetworkBaseCampComponent:RequestSwapWorkerSlot_ToServer",
        params = {
            { name = "BaseCampId", type = "FGuid" },
            { name = "SlotIdA", type = "FPalCharacterSlotId" },
            { name = "SlotIdB", type = "FPalCharacterSlotId" },
            { name = "ByMapObjectInstanceId", type = "FGuid" },
        },
    },
    {
        id = "H-005",
        path = "/Script/Pal.PalNetworkCharacterContainerComponent:RequestSwap_ToServer_Rep",
        params = {
            { name = "SlotIdA", type = "FPalCharacterSlotId" },
            { name = "SlotIdB", type = "FPalCharacterSlotId" },
        },
    },
    {
        id = "H-006",
        path = "/Script/Pal.PalNetworkBaseCampComponent:RequestMoveCharacterToWorker_ToServer",
        params = {
            { name = "BaseCampId", type = "FGuid" },
            { name = "SlotId", type = "FPalCharacterSlotId" },
            { name = "ToContainerId", type = "FPalContainerId" },
            { name = "ByMapObjectInstanceId", type = "FGuid" },
        },
    },
    {
        id = "H-007",
        path = "/Script/Pal.PalNetworkBaseCampComponent:RequestUnassignWorkInBaseCamp_ToServer",
        params = {
            { name = "BaseCampId", type = "FGuid" },
            { name = "WorkId", type = "FGuid" },
            { name = "IndividualId", type = "FPalInstanceID" },
        },
    },
    {
        id = "H-008",
        path = "/Script/Pal.PalNetworkCharacterContainerComponent:RequestEmptySlot_ToServer_Rep",
        params = {
            { name = "SlotId", type = "FPalCharacterSlotId" },
        },
    },
    {
        id = "H-009",
        path = "/Script/Pal.PalIndividualCharacterSlotsObserver:OnUpdateSlot",
        params = {
            { name = "Slot", type = "UPalIndividualCharacterSlot" },
            { name = "LastHandle", type = "UPalIndividualCharacterHandle" },
        },
    },
    {
        id = "H-010",
        path = "/Script/Pal.PalPlayerDataPalStorage:OnUpdateCharacterContainer_InServer",
        params = {},
    },
    {
        id = "H-011",
        path = "/Script/Pal.PalBaseCampModuleMedical:OnRemovedWorkerInServer",
        params = {
            { name = "IndividualHandle", type = "UPalIndividualCharacterHandle" },
        },
    },
    {
        id = "H-012",
        path = "/Script/Pal.PalPlayerController:RequestMoveToWorker_ToServer",
        params = {
            { name = "TargetCharacter", type = "APalCharacter" },
        },
    },
}
