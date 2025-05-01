#generated with pxdgen thirdparty/imgui/imgui.h -x c++ -f defines -f includerefs -f importall -w ImGui 


cdef extern from "imgui.h" nogil:
    struct ImFontBuilderIO:
        pass
    #struct ImGuiContext:
    #    pass
    struct ImDrawListSharedData:
        pass
    int IMGUI_VERSION
    long IMGUI_VERSION_NUM = 19191
    int IMGUI_HAS_TABLE
    int IMGUI_API
    int IMGUI_IMPL_API
    const int IM_ASSERT(...)
    const int IM_ARRAYSIZE(...)
    const int IM_UNUSED(...)
    const int IMGUI_CHECKVERSION(...)
    const int IM_FMTARGS(...)
    const int IM_FMTLIST(...)
    int IM_MSVC_RUNTIME_CHECKS_OFF
    int IM_MSVC_RUNTIME_CHECKS_RESTORE
    int IMGUI_PAYLOAD_TYPE_COLOR_3F
    int IMGUI_PAYLOAD_TYPE_COLOR_4F
    const int IMGUI_DEBUG_LOG(...)
    const int IM_ALLOC(...)
    const int IM_FREE(...)
    const int IM_PLACEMENT_NEW(...)
    const int IM_NEW(...)
    unsigned long IM_UNICODE_CODEPOINT_INVALID = 0xFFFD
    unsigned long IM_UNICODE_CODEPOINT_MAX = 0xFFFF
    long IM_COL32_R_SHIFT = 0
    long IM_COL32_G_SHIFT = 8
    long IM_COL32_B_SHIFT = 16
    long IM_COL32_A_SHIFT = 24
    unsigned long IM_COL32_A_MASK = 0xFF000000
    const int IM_COL32(...)
    int IM_COL32_WHITE
    int IM_COL32_BLACK
    int IM_COL32_BLACK_TRANS
    int IM_DRAWLIST_TEX_LINES_WIDTH_MAX
    int ImDrawCallback_ResetRenderState
    const int IM_OFFSETOF(...)
    ctypedef unsigned int ImGuiID
    ctypedef signed char ImS8
    ctypedef unsigned char ImU8
    ctypedef short ImS16
    ctypedef unsigned short ImU16
    ctypedef int ImS32
    ctypedef unsigned int ImU32
    ctypedef long long ImS64
    ctypedef unsigned long long ImU64
    ctypedef int ImGuiCol
    ctypedef int ImGuiCond
    ctypedef int ImGuiDataType
    ctypedef int ImGuiMouseButton
    ctypedef int ImGuiMouseCursor
    ctypedef int ImGuiStyleVar
    ctypedef int ImGuiTableBgTarget
    ctypedef int ImDrawFlags
    ctypedef int ImDrawListFlags
    ctypedef int ImFontAtlasFlags
    ctypedef int ImGuiBackendFlags
    ctypedef int ImGuiButtonFlags
    ctypedef int ImGuiChildFlags
    ctypedef int ImGuiColorEditFlags
    ctypedef int ImGuiConfigFlags
    ctypedef int ImGuiComboFlags
    ctypedef int ImGuiDragDropFlags
    ctypedef int ImGuiFocusedFlags
    ctypedef int ImGuiHoveredFlags
    ctypedef int ImGuiInputFlags
    ctypedef int ImGuiInputTextFlags
    ctypedef int ImGuiItemFlags
    ctypedef int ImGuiKeyChord
    ctypedef int ImGuiPopupFlags
    ctypedef int ImGuiMultiSelectFlags
    ctypedef int ImGuiSelectableFlags
    ctypedef int ImGuiSliderFlags
    ctypedef int ImGuiTabBarFlags
    ctypedef int ImGuiTabItemFlags
    ctypedef int ImGuiTableFlags
    ctypedef int ImGuiTableColumnFlags
    ctypedef int ImGuiTableRowFlags
    ctypedef int ImGuiTreeNodeFlags
    ctypedef int ImGuiViewportFlags
    ctypedef int ImGuiWindowFlags
    ctypedef unsigned int ImWchar32
    ctypedef unsigned short ImWchar16
    ctypedef ImWchar32 ImWchar
    ctypedef ImS64 ImGuiSelectionUserData
    ctypedef int (*ImGuiInputTextCallback)(ImGuiInputTextCallbackData*)
    ctypedef void (*ImGuiSizeCallback)(ImGuiSizeCallbackData*)
    ctypedef void* (*ImGuiMemAllocFunc)(int, void*)
    ctypedef void (*ImGuiMemFreeFunc)(void*, void*)
    cppclass ImVec2:
        float x
        float y
        ImVec2()
        ImVec2(float, float)
        float& operator[](int)
        float operator[](int)
    cppclass ImVec4:
        float x
        float y
        float z
        float w
        ImVec4()
        ImVec4(float, float, float, float)
    ctypedef ImU64 ImTextureID
    enum ImGuiWindowFlags_:
        ImGuiWindowFlags_None = 0
        ImGuiWindowFlags_NoTitleBar = 1
        ImGuiWindowFlags_NoResize = 2
        ImGuiWindowFlags_NoMove = 4
        ImGuiWindowFlags_NoScrollbar = 8
        ImGuiWindowFlags_NoScrollWithMouse = 16
        ImGuiWindowFlags_NoCollapse = 32
        ImGuiWindowFlags_AlwaysAutoResize = 64
        ImGuiWindowFlags_NoBackground = 128
        ImGuiWindowFlags_NoSavedSettings = 256
        ImGuiWindowFlags_NoMouseInputs = 512
        ImGuiWindowFlags_MenuBar = 1024
        ImGuiWindowFlags_HorizontalScrollbar = 2048
        ImGuiWindowFlags_NoFocusOnAppearing = 4096
        ImGuiWindowFlags_NoBringToFrontOnFocus = 8192
        ImGuiWindowFlags_AlwaysVerticalScrollbar = 16384
        ImGuiWindowFlags_AlwaysHorizontalScrollbar = 32768
        ImGuiWindowFlags_NoNavInputs = 65536
        ImGuiWindowFlags_NoNavFocus = 131072
        ImGuiWindowFlags_UnsavedDocument = 262144
        ImGuiWindowFlags_NoNav = 196608
        ImGuiWindowFlags_NoDecoration = 43
        ImGuiWindowFlags_NoInputs = 197120
        ImGuiWindowFlags_ChildWindow = 16777216
        ImGuiWindowFlags_Tooltip = 33554432
        ImGuiWindowFlags_Popup = 67108864
        ImGuiWindowFlags_Modal = 134217728
        ImGuiWindowFlags_ChildMenu = 268435456
        ImGuiWindowFlags_NavFlattened = 536870912
        ImGuiWindowFlags_AlwaysUseWindowPadding = 1073741824
    enum ImGuiChildFlags_:
        ImGuiChildFlags_None = 0
        ImGuiChildFlags_Borders = 1
        ImGuiChildFlags_AlwaysUseWindowPadding = 2
        ImGuiChildFlags_ResizeX = 4
        ImGuiChildFlags_ResizeY = 8
        ImGuiChildFlags_AutoResizeX = 16
        ImGuiChildFlags_AutoResizeY = 32
        ImGuiChildFlags_AlwaysAutoResize = 64
        ImGuiChildFlags_FrameStyle = 128
        ImGuiChildFlags_NavFlattened = 256
        ImGuiChildFlags_Border = 1
    enum ImGuiItemFlags_:
        ImGuiItemFlags_None = 0
        ImGuiItemFlags_NoTabStop = 1
        ImGuiItemFlags_NoNav = 2
        ImGuiItemFlags_NoNavDefaultFocus = 4
        ImGuiItemFlags_ButtonRepeat = 8
        ImGuiItemFlags_AutoClosePopups = 16
        ImGuiItemFlags_AllowDuplicateId = 32
    enum ImGuiInputTextFlags_:
        ImGuiInputTextFlags_None = 0
        ImGuiInputTextFlags_CharsDecimal = 1
        ImGuiInputTextFlags_CharsHexadecimal = 2
        ImGuiInputTextFlags_CharsScientific = 4
        ImGuiInputTextFlags_CharsUppercase = 8
        ImGuiInputTextFlags_CharsNoBlank = 16
        ImGuiInputTextFlags_AllowTabInput = 32
        ImGuiInputTextFlags_EnterReturnsTrue = 64
        ImGuiInputTextFlags_EscapeClearsAll = 128
        ImGuiInputTextFlags_CtrlEnterForNewLine = 256
        ImGuiInputTextFlags_ReadOnly = 512
        ImGuiInputTextFlags_Password = 1024
        ImGuiInputTextFlags_AlwaysOverwrite = 2048
        ImGuiInputTextFlags_AutoSelectAll = 4096
        ImGuiInputTextFlags_ParseEmptyRefVal = 8192
        ImGuiInputTextFlags_DisplayEmptyRefVal = 16384
        ImGuiInputTextFlags_NoHorizontalScroll = 32768
        ImGuiInputTextFlags_NoUndoRedo = 65536
        ImGuiInputTextFlags_ElideLeft = 131072
        ImGuiInputTextFlags_CallbackCompletion = 262144
        ImGuiInputTextFlags_CallbackHistory = 524288
        ImGuiInputTextFlags_CallbackAlways = 1048576
        ImGuiInputTextFlags_CallbackCharFilter = 2097152
        ImGuiInputTextFlags_CallbackResize = 4194304
        ImGuiInputTextFlags_CallbackEdit = 8388608
    enum ImGuiTreeNodeFlags_:
        ImGuiTreeNodeFlags_None = 0
        ImGuiTreeNodeFlags_Selected = 1
        ImGuiTreeNodeFlags_Framed = 2
        ImGuiTreeNodeFlags_AllowOverlap = 4
        ImGuiTreeNodeFlags_NoTreePushOnOpen = 8
        ImGuiTreeNodeFlags_NoAutoOpenOnLog = 16
        ImGuiTreeNodeFlags_DefaultOpen = 32
        ImGuiTreeNodeFlags_OpenOnDoubleClick = 64
        ImGuiTreeNodeFlags_OpenOnArrow = 128
        ImGuiTreeNodeFlags_Leaf = 256
        ImGuiTreeNodeFlags_Bullet = 512
        ImGuiTreeNodeFlags_FramePadding = 1024
        ImGuiTreeNodeFlags_SpanAvailWidth = 2048
        ImGuiTreeNodeFlags_SpanFullWidth = 4096
        ImGuiTreeNodeFlags_SpanLabelWidth = 8192
        ImGuiTreeNodeFlags_SpanAllColumns = 16384
        ImGuiTreeNodeFlags_LabelSpanAllColumns = 32768
        ImGuiTreeNodeFlags_NavLeftJumpsBackHere = 131072
        ImGuiTreeNodeFlags_CollapsingHeader = 26
        ImGuiTreeNodeFlags_AllowItemOverlap = 4
        ImGuiTreeNodeFlags_SpanTextWidth = 8192
    enum ImGuiPopupFlags_:
        ImGuiPopupFlags_None = 0
        ImGuiPopupFlags_MouseButtonLeft = 0
        ImGuiPopupFlags_MouseButtonRight = 1
        ImGuiPopupFlags_MouseButtonMiddle = 2
        ImGuiPopupFlags_MouseButtonMask_ = 31
        ImGuiPopupFlags_MouseButtonDefault_ = 1
        ImGuiPopupFlags_NoReopen = 32
        ImGuiPopupFlags_NoOpenOverExistingPopup = 128
        ImGuiPopupFlags_NoOpenOverItems = 256
        ImGuiPopupFlags_AnyPopupId = 1024
        ImGuiPopupFlags_AnyPopupLevel = 2048
        ImGuiPopupFlags_AnyPopup = 3072
    enum ImGuiSelectableFlags_:
        ImGuiSelectableFlags_None = 0
        ImGuiSelectableFlags_NoAutoClosePopups = 1
        ImGuiSelectableFlags_SpanAllColumns = 2
        ImGuiSelectableFlags_AllowDoubleClick = 4
        ImGuiSelectableFlags_Disabled = 8
        ImGuiSelectableFlags_AllowOverlap = 16
        ImGuiSelectableFlags_Highlight = 32
        ImGuiSelectableFlags_DontClosePopups = 1
        ImGuiSelectableFlags_AllowItemOverlap = 16
    enum ImGuiComboFlags_:
        ImGuiComboFlags_None = 0
        ImGuiComboFlags_PopupAlignLeft = 1
        ImGuiComboFlags_HeightSmall = 2
        ImGuiComboFlags_HeightRegular = 4
        ImGuiComboFlags_HeightLarge = 8
        ImGuiComboFlags_HeightLargest = 16
        ImGuiComboFlags_NoArrowButton = 32
        ImGuiComboFlags_NoPreview = 64
        ImGuiComboFlags_WidthFitPreview = 128
        ImGuiComboFlags_HeightMask_ = 30
    enum ImGuiTabBarFlags_:
        ImGuiTabBarFlags_None = 0
        ImGuiTabBarFlags_Reorderable = 1
        ImGuiTabBarFlags_AutoSelectNewTabs = 2
        ImGuiTabBarFlags_TabListPopupButton = 4
        ImGuiTabBarFlags_NoCloseWithMiddleMouseButton = 8
        ImGuiTabBarFlags_NoTabListScrollingButtons = 16
        ImGuiTabBarFlags_NoTooltip = 32
        ImGuiTabBarFlags_DrawSelectedOverline = 64
        ImGuiTabBarFlags_FittingPolicyResizeDown = 128
        ImGuiTabBarFlags_FittingPolicyScroll = 256
        ImGuiTabBarFlags_FittingPolicyMask_ = 384
        ImGuiTabBarFlags_FittingPolicyDefault_ = 128
    enum ImGuiTabItemFlags_:
        ImGuiTabItemFlags_None = 0
        ImGuiTabItemFlags_UnsavedDocument = 1
        ImGuiTabItemFlags_SetSelected = 2
        ImGuiTabItemFlags_NoCloseWithMiddleMouseButton = 4
        ImGuiTabItemFlags_NoPushId = 8
        ImGuiTabItemFlags_NoTooltip = 16
        ImGuiTabItemFlags_NoReorder = 32
        ImGuiTabItemFlags_Leading = 64
        ImGuiTabItemFlags_Trailing = 128
        ImGuiTabItemFlags_NoAssumedClosure = 256
    enum ImGuiFocusedFlags_:
        ImGuiFocusedFlags_None = 0
        ImGuiFocusedFlags_ChildWindows = 1
        ImGuiFocusedFlags_RootWindow = 2
        ImGuiFocusedFlags_AnyWindow = 4
        ImGuiFocusedFlags_NoPopupHierarchy = 8
        ImGuiFocusedFlags_RootAndChildWindows = 3
    enum ImGuiHoveredFlags_:
        ImGuiHoveredFlags_None = 0
        ImGuiHoveredFlags_ChildWindows = 1
        ImGuiHoveredFlags_RootWindow = 2
        ImGuiHoveredFlags_AnyWindow = 4
        ImGuiHoveredFlags_NoPopupHierarchy = 8
        ImGuiHoveredFlags_AllowWhenBlockedByPopup = 32
        ImGuiHoveredFlags_AllowWhenBlockedByActiveItem = 128
        ImGuiHoveredFlags_AllowWhenOverlappedByItem = 256
        ImGuiHoveredFlags_AllowWhenOverlappedByWindow = 512
        ImGuiHoveredFlags_AllowWhenDisabled = 1024
        ImGuiHoveredFlags_NoNavOverride = 2048
        ImGuiHoveredFlags_AllowWhenOverlapped = 768
        ImGuiHoveredFlags_RectOnly = 928
        ImGuiHoveredFlags_RootAndChildWindows = 3
        ImGuiHoveredFlags_ForTooltip = 4096
        ImGuiHoveredFlags_Stationary = 8192
        ImGuiHoveredFlags_DelayNone = 16384
        ImGuiHoveredFlags_DelayShort = 32768
        ImGuiHoveredFlags_DelayNormal = 65536
        ImGuiHoveredFlags_NoSharedDelay = 131072
    enum ImGuiDragDropFlags_:
        ImGuiDragDropFlags_None = 0
        ImGuiDragDropFlags_SourceNoPreviewTooltip = 1
        ImGuiDragDropFlags_SourceNoDisableHover = 2
        ImGuiDragDropFlags_SourceNoHoldToOpenOthers = 4
        ImGuiDragDropFlags_SourceAllowNullID = 8
        ImGuiDragDropFlags_SourceExtern = 16
        ImGuiDragDropFlags_PayloadAutoExpire = 32
        ImGuiDragDropFlags_PayloadNoCrossContext = 64
        ImGuiDragDropFlags_PayloadNoCrossProcess = 128
        ImGuiDragDropFlags_AcceptBeforeDelivery = 1024
        ImGuiDragDropFlags_AcceptNoDrawDefaultRect = 2048
        ImGuiDragDropFlags_AcceptNoPreviewTooltip = 4096
        ImGuiDragDropFlags_AcceptPeekOnly = 3072
        ImGuiDragDropFlags_SourceAutoExpirePayload = 32
    enum ImGuiDataType_:
        ImGuiDataType_S8 = 0
        ImGuiDataType_U8 = 1
        ImGuiDataType_S16 = 2
        ImGuiDataType_U16 = 3
        ImGuiDataType_S32 = 4
        ImGuiDataType_U32 = 5
        ImGuiDataType_S64 = 6
        ImGuiDataType_U64 = 7
        ImGuiDataType_Float = 8
        ImGuiDataType_Double = 9
        ImGuiDataType_Bool = 10
        ImGuiDataType_String = 11
        ImGuiDataType_COUNT = 12
    enum ImGuiDir:
        ImGuiDir_None = -1
        ImGuiDir_Left = 0
        ImGuiDir_Right = 1
        ImGuiDir_Up = 2
        ImGuiDir_Down = 3
        ImGuiDir_COUNT = 4
    enum ImGuiSortDirection:
        ImGuiSortDirection_None = 0
        ImGuiSortDirection_Ascending = 1
        ImGuiSortDirection_Descending = 2
    enum ImGuiKey:
        ImGuiKey_None = 0
        ImGuiKey_NamedKey_BEGIN = 512
        ImGuiKey_Tab = 512
        ImGuiKey_LeftArrow = 513
        ImGuiKey_RightArrow = 514
        ImGuiKey_UpArrow = 515
        ImGuiKey_DownArrow = 516
        ImGuiKey_PageUp = 517
        ImGuiKey_PageDown = 518
        ImGuiKey_Home = 519
        ImGuiKey_End = 520
        ImGuiKey_Insert = 521
        ImGuiKey_Delete = 522
        ImGuiKey_Backspace = 523
        ImGuiKey_Space = 524
        ImGuiKey_Enter = 525
        ImGuiKey_Escape = 526
        ImGuiKey_LeftCtrl = 527
        ImGuiKey_LeftShift = 528
        ImGuiKey_LeftAlt = 529
        ImGuiKey_LeftSuper = 530
        ImGuiKey_RightCtrl = 531
        ImGuiKey_RightShift = 532
        ImGuiKey_RightAlt = 533
        ImGuiKey_RightSuper = 534
        ImGuiKey_Menu = 535
        ImGuiKey_0 = 536
        ImGuiKey_1 = 537
        ImGuiKey_2 = 538
        ImGuiKey_3 = 539
        ImGuiKey_4 = 540
        ImGuiKey_5 = 541
        ImGuiKey_6 = 542
        ImGuiKey_7 = 543
        ImGuiKey_8 = 544
        ImGuiKey_9 = 545
        ImGuiKey_A = 546
        ImGuiKey_B = 547
        ImGuiKey_C = 548
        ImGuiKey_D = 549
        ImGuiKey_E = 550
        ImGuiKey_F = 551
        ImGuiKey_G = 552
        ImGuiKey_H = 553
        ImGuiKey_I = 554
        ImGuiKey_J = 555
        ImGuiKey_K = 556
        ImGuiKey_L = 557
        ImGuiKey_M = 558
        ImGuiKey_N = 559
        ImGuiKey_O = 560
        ImGuiKey_P = 561
        ImGuiKey_Q = 562
        ImGuiKey_R = 563
        ImGuiKey_S = 564
        ImGuiKey_T = 565
        ImGuiKey_U = 566
        ImGuiKey_V = 567
        ImGuiKey_W = 568
        ImGuiKey_X = 569
        ImGuiKey_Y = 570
        ImGuiKey_Z = 571
        ImGuiKey_F1 = 572
        ImGuiKey_F2 = 573
        ImGuiKey_F3 = 574
        ImGuiKey_F4 = 575
        ImGuiKey_F5 = 576
        ImGuiKey_F6 = 577
        ImGuiKey_F7 = 578
        ImGuiKey_F8 = 579
        ImGuiKey_F9 = 580
        ImGuiKey_F10 = 581
        ImGuiKey_F11 = 582
        ImGuiKey_F12 = 583
        ImGuiKey_F13 = 584
        ImGuiKey_F14 = 585
        ImGuiKey_F15 = 586
        ImGuiKey_F16 = 587
        ImGuiKey_F17 = 588
        ImGuiKey_F18 = 589
        ImGuiKey_F19 = 590
        ImGuiKey_F20 = 591
        ImGuiKey_F21 = 592
        ImGuiKey_F22 = 593
        ImGuiKey_F23 = 594
        ImGuiKey_F24 = 595
        ImGuiKey_Apostrophe = 596
        ImGuiKey_Comma = 597
        ImGuiKey_Minus = 598
        ImGuiKey_Period = 599
        ImGuiKey_Slash = 600
        ImGuiKey_Semicolon = 601
        ImGuiKey_Equal = 602
        ImGuiKey_LeftBracket = 603
        ImGuiKey_Backslash = 604
        ImGuiKey_RightBracket = 605
        ImGuiKey_GraveAccent = 606
        ImGuiKey_CapsLock = 607
        ImGuiKey_ScrollLock = 608
        ImGuiKey_NumLock = 609
        ImGuiKey_PrintScreen = 610
        ImGuiKey_Pause = 611
        ImGuiKey_Keypad0 = 612
        ImGuiKey_Keypad1 = 613
        ImGuiKey_Keypad2 = 614
        ImGuiKey_Keypad3 = 615
        ImGuiKey_Keypad4 = 616
        ImGuiKey_Keypad5 = 617
        ImGuiKey_Keypad6 = 618
        ImGuiKey_Keypad7 = 619
        ImGuiKey_Keypad8 = 620
        ImGuiKey_Keypad9 = 621
        ImGuiKey_KeypadDecimal = 622
        ImGuiKey_KeypadDivide = 623
        ImGuiKey_KeypadMultiply = 624
        ImGuiKey_KeypadSubtract = 625
        ImGuiKey_KeypadAdd = 626
        ImGuiKey_KeypadEnter = 627
        ImGuiKey_KeypadEqual = 628
        ImGuiKey_AppBack = 629
        ImGuiKey_AppForward = 630
        ImGuiKey_Oem102 = 631
        ImGuiKey_GamepadStart = 632
        ImGuiKey_GamepadBack = 633
        ImGuiKey_GamepadFaceLeft = 634
        ImGuiKey_GamepadFaceRight = 635
        ImGuiKey_GamepadFaceUp = 636
        ImGuiKey_GamepadFaceDown = 637
        ImGuiKey_GamepadDpadLeft = 638
        ImGuiKey_GamepadDpadRight = 639
        ImGuiKey_GamepadDpadUp = 640
        ImGuiKey_GamepadDpadDown = 641
        ImGuiKey_GamepadL1 = 642
        ImGuiKey_GamepadR1 = 643
        ImGuiKey_GamepadL2 = 644
        ImGuiKey_GamepadR2 = 645
        ImGuiKey_GamepadL3 = 646
        ImGuiKey_GamepadR3 = 647
        ImGuiKey_GamepadLStickLeft = 648
        ImGuiKey_GamepadLStickRight = 649
        ImGuiKey_GamepadLStickUp = 650
        ImGuiKey_GamepadLStickDown = 651
        ImGuiKey_GamepadRStickLeft = 652
        ImGuiKey_GamepadRStickRight = 653
        ImGuiKey_GamepadRStickUp = 654
        ImGuiKey_GamepadRStickDown = 655
        ImGuiKey_MouseLeft = 656
        ImGuiKey_MouseRight = 657
        ImGuiKey_MouseMiddle = 658
        ImGuiKey_MouseX1 = 659
        ImGuiKey_MouseX2 = 660
        ImGuiKey_MouseWheelX = 661
        ImGuiKey_MouseWheelY = 662
        ImGuiKey_ReservedForModCtrl = 663
        ImGuiKey_ReservedForModShift = 664
        ImGuiKey_ReservedForModAlt = 665
        ImGuiKey_ReservedForModSuper = 666
        ImGuiKey_NamedKey_END = 667
        ImGuiMod_None = 0
        ImGuiMod_Ctrl = 4096
        ImGuiMod_Shift = 8192
        ImGuiMod_Alt = 16384
        ImGuiMod_Super = 32768
        ImGuiMod_Mask_ = 61440
        ImGuiKey_NamedKey_COUNT = 155
        ImGuiKey_COUNT = 667
        ImGuiMod_Shortcut = 4096
        ImGuiKey_ModCtrl = 4096
        ImGuiKey_ModShift = 8192
        ImGuiKey_ModAlt = 16384
        ImGuiKey_ModSuper = 32768
    enum ImGuiInputFlags_:
        ImGuiInputFlags_None = 0
        ImGuiInputFlags_Repeat = 1
        ImGuiInputFlags_RouteActive = 1024
        ImGuiInputFlags_RouteFocused = 2048
        ImGuiInputFlags_RouteGlobal = 4096
        ImGuiInputFlags_RouteAlways = 8192
        ImGuiInputFlags_RouteOverFocused = 16384
        ImGuiInputFlags_RouteOverActive = 32768
        ImGuiInputFlags_RouteUnlessBgFocused = 65536
        ImGuiInputFlags_RouteFromRootWindow = 131072
        ImGuiInputFlags_Tooltip = 262144
    enum ImGuiConfigFlags_:
        ImGuiConfigFlags_None = 0
        ImGuiConfigFlags_NavEnableKeyboard = 1
        ImGuiConfigFlags_NavEnableGamepad = 2
        ImGuiConfigFlags_NoMouse = 16
        ImGuiConfigFlags_NoMouseCursorChange = 32
        ImGuiConfigFlags_NoKeyboard = 64
        ImGuiConfigFlags_IsSRGB = 1048576
        ImGuiConfigFlags_IsTouchScreen = 2097152
        ImGuiConfigFlags_NavEnableSetMousePos = 4
        ImGuiConfigFlags_NavNoCaptureKeyboard = 8
    enum ImGuiBackendFlags_:
        ImGuiBackendFlags_None = 0
        ImGuiBackendFlags_HasGamepad = 1
        ImGuiBackendFlags_HasMouseCursors = 2
        ImGuiBackendFlags_HasSetMousePos = 4
        ImGuiBackendFlags_RendererHasVtxOffset = 8
    enum ImGuiCol_:
        ImGuiCol_Text = 0
        ImGuiCol_TextDisabled = 1
        ImGuiCol_WindowBg = 2
        ImGuiCol_ChildBg = 3
        ImGuiCol_PopupBg = 4
        ImGuiCol_Border = 5
        ImGuiCol_BorderShadow = 6
        ImGuiCol_FrameBg = 7
        ImGuiCol_FrameBgHovered = 8
        ImGuiCol_FrameBgActive = 9
        ImGuiCol_TitleBg = 10
        ImGuiCol_TitleBgActive = 11
        ImGuiCol_TitleBgCollapsed = 12
        ImGuiCol_MenuBarBg = 13
        ImGuiCol_ScrollbarBg = 14
        ImGuiCol_ScrollbarGrab = 15
        ImGuiCol_ScrollbarGrabHovered = 16
        ImGuiCol_ScrollbarGrabActive = 17
        ImGuiCol_CheckMark = 18
        ImGuiCol_SliderGrab = 19
        ImGuiCol_SliderGrabActive = 20
        ImGuiCol_Button = 21
        ImGuiCol_ButtonHovered = 22
        ImGuiCol_ButtonActive = 23
        ImGuiCol_Header = 24
        ImGuiCol_HeaderHovered = 25
        ImGuiCol_HeaderActive = 26
        ImGuiCol_Separator = 27
        ImGuiCol_SeparatorHovered = 28
        ImGuiCol_SeparatorActive = 29
        ImGuiCol_ResizeGrip = 30
        ImGuiCol_ResizeGripHovered = 31
        ImGuiCol_ResizeGripActive = 32
        ImGuiCol_TabHovered = 33
        ImGuiCol_Tab = 34
        ImGuiCol_TabSelected = 35
        ImGuiCol_TabSelectedOverline = 36
        ImGuiCol_TabDimmed = 37
        ImGuiCol_TabDimmedSelected = 38
        ImGuiCol_TabDimmedSelectedOverline = 39
        ImGuiCol_PlotLines = 40
        ImGuiCol_PlotLinesHovered = 41
        ImGuiCol_PlotHistogram = 42
        ImGuiCol_PlotHistogramHovered = 43
        ImGuiCol_TableHeaderBg = 44
        ImGuiCol_TableBorderStrong = 45
        ImGuiCol_TableBorderLight = 46
        ImGuiCol_TableRowBg = 47
        ImGuiCol_TableRowBgAlt = 48
        ImGuiCol_TextLink = 49
        ImGuiCol_TextSelectedBg = 50
        ImGuiCol_DragDropTarget = 51
        ImGuiCol_NavCursor = 52
        ImGuiCol_NavWindowingHighlight = 53
        ImGuiCol_NavWindowingDimBg = 54
        ImGuiCol_ModalWindowDimBg = 55
        ImGuiCol_COUNT = 56
        ImGuiCol_TabActive = 35
        ImGuiCol_TabUnfocused = 37
        ImGuiCol_TabUnfocusedActive = 38
        ImGuiCol_NavHighlight = 52
    enum ImGuiStyleVar_:
        ImGuiStyleVar_Alpha = 0
        ImGuiStyleVar_DisabledAlpha = 1
        ImGuiStyleVar_WindowPadding = 2
        ImGuiStyleVar_WindowRounding = 3
        ImGuiStyleVar_WindowBorderSize = 4
        ImGuiStyleVar_WindowMinSize = 5
        ImGuiStyleVar_WindowTitleAlign = 6
        ImGuiStyleVar_ChildRounding = 7
        ImGuiStyleVar_ChildBorderSize = 8
        ImGuiStyleVar_PopupRounding = 9
        ImGuiStyleVar_PopupBorderSize = 10
        ImGuiStyleVar_FramePadding = 11
        ImGuiStyleVar_FrameRounding = 12
        ImGuiStyleVar_FrameBorderSize = 13
        ImGuiStyleVar_ItemSpacing = 14
        ImGuiStyleVar_ItemInnerSpacing = 15
        ImGuiStyleVar_IndentSpacing = 16
        ImGuiStyleVar_CellPadding = 17
        ImGuiStyleVar_ScrollbarSize = 18
        ImGuiStyleVar_ScrollbarRounding = 19
        ImGuiStyleVar_GrabMinSize = 20
        ImGuiStyleVar_GrabRounding = 21
        ImGuiStyleVar_ImageBorderSize = 22
        ImGuiStyleVar_TabRounding = 23
        ImGuiStyleVar_TabBorderSize = 24
        ImGuiStyleVar_TabBarBorderSize = 25
        ImGuiStyleVar_TabBarOverlineSize = 26
        ImGuiStyleVar_TableAngledHeadersAngle = 27
        ImGuiStyleVar_TableAngledHeadersTextAlign = 28
        ImGuiStyleVar_ButtonTextAlign = 29
        ImGuiStyleVar_SelectableTextAlign = 30
        ImGuiStyleVar_SeparatorTextBorderSize = 31
        ImGuiStyleVar_SeparatorTextAlign = 32
        ImGuiStyleVar_SeparatorTextPadding = 33
        ImGuiStyleVar_COUNT = 34
    enum ImGuiButtonFlags_:
        ImGuiButtonFlags_None = 0
        ImGuiButtonFlags_MouseButtonLeft = 1
        ImGuiButtonFlags_MouseButtonRight = 2
        ImGuiButtonFlags_MouseButtonMiddle = 4
        ImGuiButtonFlags_MouseButtonMask_ = 7
        ImGuiButtonFlags_EnableNav = 8
    enum ImGuiColorEditFlags_:
        ImGuiColorEditFlags_None = 0
        ImGuiColorEditFlags_NoAlpha = 2
        ImGuiColorEditFlags_NoPicker = 4
        ImGuiColorEditFlags_NoOptions = 8
        ImGuiColorEditFlags_NoSmallPreview = 16
        ImGuiColorEditFlags_NoInputs = 32
        ImGuiColorEditFlags_NoTooltip = 64
        ImGuiColorEditFlags_NoLabel = 128
        ImGuiColorEditFlags_NoSidePreview = 256
        ImGuiColorEditFlags_NoDragDrop = 512
        ImGuiColorEditFlags_NoBorder = 1024
        ImGuiColorEditFlags_AlphaOpaque = 2048
        ImGuiColorEditFlags_AlphaNoBg = 4096
        ImGuiColorEditFlags_AlphaPreviewHalf = 8192
        ImGuiColorEditFlags_AlphaBar = 65536
        ImGuiColorEditFlags_HDR = 524288
        ImGuiColorEditFlags_DisplayRGB = 1048576
        ImGuiColorEditFlags_DisplayHSV = 2097152
        ImGuiColorEditFlags_DisplayHex = 4194304
        ImGuiColorEditFlags_Uint8 = 8388608
        ImGuiColorEditFlags_Float = 16777216
        ImGuiColorEditFlags_PickerHueBar = 33554432
        ImGuiColorEditFlags_PickerHueWheel = 67108864
        ImGuiColorEditFlags_InputRGB = 134217728
        ImGuiColorEditFlags_InputHSV = 268435456
        ImGuiColorEditFlags_DefaultOptions_ = 177209344
        ImGuiColorEditFlags_AlphaMask_ = 14338
        ImGuiColorEditFlags_DisplayMask_ = 7340032
        ImGuiColorEditFlags_DataTypeMask_ = 25165824
        ImGuiColorEditFlags_PickerMask_ = 100663296
        ImGuiColorEditFlags_InputMask_ = 402653184
        ImGuiColorEditFlags_AlphaPreview = 0
    enum ImGuiSliderFlags_:
        ImGuiSliderFlags_None = 0
        ImGuiSliderFlags_Logarithmic = 32
        ImGuiSliderFlags_NoRoundToFormat = 64
        ImGuiSliderFlags_NoInput = 128
        ImGuiSliderFlags_WrapAround = 256
        ImGuiSliderFlags_ClampOnInput = 512
        ImGuiSliderFlags_ClampZeroRange = 1024
        ImGuiSliderFlags_NoSpeedTweaks = 2048
        ImGuiSliderFlags_AlwaysClamp = 1536
        ImGuiSliderFlags_InvalidMask_ = 1879048207
    enum ImGuiMouseButton_:
        ImGuiMouseButton_Left = 0
        ImGuiMouseButton_Right = 1
        ImGuiMouseButton_Middle = 2
        ImGuiMouseButton_COUNT = 5
    enum ImGuiMouseCursor_:
        ImGuiMouseCursor_None = -1
        ImGuiMouseCursor_Arrow = 0
        ImGuiMouseCursor_TextInput = 1
        ImGuiMouseCursor_ResizeAll = 2
        ImGuiMouseCursor_ResizeNS = 3
        ImGuiMouseCursor_ResizeEW = 4
        ImGuiMouseCursor_ResizeNESW = 5
        ImGuiMouseCursor_ResizeNWSE = 6
        ImGuiMouseCursor_Hand = 7
        ImGuiMouseCursor_Wait = 8
        ImGuiMouseCursor_Progress = 9
        ImGuiMouseCursor_NotAllowed = 10
        ImGuiMouseCursor_COUNT = 11
    enum ImGuiMouseSource:
        ImGuiMouseSource_Mouse = 0
        ImGuiMouseSource_TouchScreen = 1
        ImGuiMouseSource_Pen = 2
        ImGuiMouseSource_COUNT = 3
    enum ImGuiCond_:
        ImGuiCond_None = 0
        ImGuiCond_Always = 1
        ImGuiCond_Once = 2
        ImGuiCond_FirstUseEver = 4
        ImGuiCond_Appearing = 8
    enum ImGuiTableFlags_:
        ImGuiTableFlags_None = 0
        ImGuiTableFlags_Resizable = 1
        ImGuiTableFlags_Reorderable = 2
        ImGuiTableFlags_Hideable = 4
        ImGuiTableFlags_Sortable = 8
        ImGuiTableFlags_NoSavedSettings = 16
        ImGuiTableFlags_ContextMenuInBody = 32
        ImGuiTableFlags_RowBg = 64
        ImGuiTableFlags_BordersInnerH = 128
        ImGuiTableFlags_BordersOuterH = 256
        ImGuiTableFlags_BordersInnerV = 512
        ImGuiTableFlags_BordersOuterV = 1024
        ImGuiTableFlags_BordersH = 384
        ImGuiTableFlags_BordersV = 1536
        ImGuiTableFlags_BordersInner = 640
        ImGuiTableFlags_BordersOuter = 1280
        ImGuiTableFlags_Borders = 1920
        ImGuiTableFlags_NoBordersInBody = 2048
        ImGuiTableFlags_NoBordersInBodyUntilResize = 4096
        ImGuiTableFlags_SizingFixedFit = 8192
        ImGuiTableFlags_SizingFixedSame = 16384
        ImGuiTableFlags_SizingStretchProp = 24576
        ImGuiTableFlags_SizingStretchSame = 32768
        ImGuiTableFlags_NoHostExtendX = 65536
        ImGuiTableFlags_NoHostExtendY = 131072
        ImGuiTableFlags_NoKeepColumnsVisible = 262144
        ImGuiTableFlags_PreciseWidths = 524288
        ImGuiTableFlags_NoClip = 1048576
        ImGuiTableFlags_PadOuterX = 2097152
        ImGuiTableFlags_NoPadOuterX = 4194304
        ImGuiTableFlags_NoPadInnerX = 8388608
        ImGuiTableFlags_ScrollX = 16777216
        ImGuiTableFlags_ScrollY = 33554432
        ImGuiTableFlags_SortMulti = 67108864
        ImGuiTableFlags_SortTristate = 134217728
        ImGuiTableFlags_HighlightHoveredColumn = 268435456
        ImGuiTableFlags_SizingMask_ = 57344
    enum ImGuiTableColumnFlags_:
        ImGuiTableColumnFlags_None = 0
        ImGuiTableColumnFlags_Disabled = 1
        ImGuiTableColumnFlags_DefaultHide = 2
        ImGuiTableColumnFlags_DefaultSort = 4
        ImGuiTableColumnFlags_WidthStretch = 8
        ImGuiTableColumnFlags_WidthFixed = 16
        ImGuiTableColumnFlags_NoResize = 32
        ImGuiTableColumnFlags_NoReorder = 64
        ImGuiTableColumnFlags_NoHide = 128
        ImGuiTableColumnFlags_NoClip = 256
        ImGuiTableColumnFlags_NoSort = 512
        ImGuiTableColumnFlags_NoSortAscending = 1024
        ImGuiTableColumnFlags_NoSortDescending = 2048
        ImGuiTableColumnFlags_NoHeaderLabel = 4096
        ImGuiTableColumnFlags_NoHeaderWidth = 8192
        ImGuiTableColumnFlags_PreferSortAscending = 16384
        ImGuiTableColumnFlags_PreferSortDescending = 32768
        ImGuiTableColumnFlags_IndentEnable = 65536
        ImGuiTableColumnFlags_IndentDisable = 131072
        ImGuiTableColumnFlags_AngledHeader = 262144
        ImGuiTableColumnFlags_IsEnabled = 16777216
        ImGuiTableColumnFlags_IsVisible = 33554432
        ImGuiTableColumnFlags_IsSorted = 67108864
        ImGuiTableColumnFlags_IsHovered = 134217728
        ImGuiTableColumnFlags_WidthMask_ = 24
        ImGuiTableColumnFlags_IndentMask_ = 196608
        ImGuiTableColumnFlags_StatusMask_ = 251658240
        ImGuiTableColumnFlags_NoDirectResize_ = 1073741824
    enum ImGuiTableRowFlags_:
        ImGuiTableRowFlags_None = 0
        ImGuiTableRowFlags_Headers = 1
    enum ImGuiTableBgTarget_:
        ImGuiTableBgTarget_None = 0
        ImGuiTableBgTarget_RowBg0 = 1
        ImGuiTableBgTarget_RowBg1 = 2
        ImGuiTableBgTarget_CellBg = 3
    cppclass ImGuiTableSortSpecs:
        ImGuiTableColumnSortSpecs* Specs
        int SpecsCount
        bint SpecsDirty
        ImGuiTableSortSpecs()
    cppclass ImGuiTableColumnSortSpecs:
        ImGuiID ColumnUserID
        ImS16 ColumnIndex
        ImS16 SortOrder
        ImGuiSortDirection SortDirection
        ImGuiTableColumnSortSpecs()
    struct ImNewWrapper:
        pass
    #void* operator new(int, ImNewWrapper, void*)
    #void operator delete(void*, ImNewWrapper, void*)
    void IM_DELETE[T](T*)
    cppclass ImVector[T]:
        int Size
        int Capacity
        T* Data
        ctypedef T value_type
        ctypedef value_type* iterator
        ctypedef value_type* const_iterator
        ImVector()
        ImVector(ImVector[T]&)
        ImVector[T]& operator=(ImVector[T]&)
        void clear()
        void clear_delete()
        void clear_destruct()
        bint empty()
        int size()
        int size_in_bytes()
        int max_size()
        int capacity()
        T& operator[](int)
        const T& operator[](int)
        T* begin()
        const T* begin()
        T* end()
        const T* end()
        T& front()
        const T& front()
        T& back()
        const T& back()
        void swap(ImVector[T]&)
        int _grow_capacity(int)
        void resize(int)
        void resize(int, const T&)
        void shrink(int)
        void reserve(int)
        void reserve_discard(int)
        void push_back(const T&)
        void pop_back()
        void push_front(const T&)
        T* erase(const T*)
        T* erase(const T*, const T*)
        T* erase_unsorted(const T*)
        T* insert(const T*, const T&)
        bint contains(const T&)
        T* find(const T&)
        const T* find(const T&)
        int find_index(const T&)
        bint find_erase(const T&)
        bint find_erase_unsorted(const T&)
        int index_from_ptr(const T*)
    cppclass ImGuiStyle:
        float Alpha
        float DisabledAlpha
        ImVec2 WindowPadding
        float WindowRounding
        float WindowBorderSize
        float WindowBorderHoverPadding
        ImVec2 WindowMinSize
        ImVec2 WindowTitleAlign
        ImGuiDir WindowMenuButtonPosition
        float ChildRounding
        float ChildBorderSize
        float PopupRounding
        float PopupBorderSize
        ImVec2 FramePadding
        float FrameRounding
        float FrameBorderSize
        ImVec2 ItemSpacing
        ImVec2 ItemInnerSpacing
        ImVec2 CellPadding
        ImVec2 TouchExtraPadding
        float IndentSpacing
        float ColumnsMinSpacing
        float ScrollbarSize
        float ScrollbarRounding
        float GrabMinSize
        float GrabRounding
        float LogSliderDeadzone
        float ImageBorderSize
        float TabRounding
        float TabBorderSize
        float TabCloseButtonMinWidthSelected
        float TabCloseButtonMinWidthUnselected
        float TabBarBorderSize
        float TabBarOverlineSize
        float TableAngledHeadersAngle
        ImVec2 TableAngledHeadersTextAlign
        ImGuiDir ColorButtonPosition
        ImVec2 ButtonTextAlign
        ImVec2 SelectableTextAlign
        float SeparatorTextBorderSize
        ImVec2 SeparatorTextAlign
        ImVec2 SeparatorTextPadding
        ImVec2 DisplayWindowPadding
        ImVec2 DisplaySafeAreaPadding
        float MouseCursorScale
        bint AntiAliasedLines
        bint AntiAliasedLinesUseTex
        bint AntiAliasedFill
        float CurveTessellationTol
        float CircleTessellationMaxError
        ImVec4 Colors[56]
        float HoverStationaryDelay
        float HoverDelayShort
        float HoverDelayNormal
        ImGuiHoveredFlags HoverFlagsForTooltipMouse
        ImGuiHoveredFlags HoverFlagsForTooltipNav
        ImGuiStyle()
        void ScaleAllSizes(float)
    struct ImGuiKeyData:
        bint Down
        float DownDuration
        float DownDurationPrev
        float AnalogValue
    #struct ImGuiContext:
    #    pass
    cppclass ImGuiIO:
        ImGuiConfigFlags ConfigFlags
        ImGuiBackendFlags BackendFlags
        ImVec2 DisplaySize
        float DeltaTime
        float IniSavingRate
        const char* IniFilename
        const char* LogFilename
        void* UserData
        ImFontAtlas* Fonts
        float FontGlobalScale
        bint FontAllowUserScaling
        ImFont* FontDefault
        ImVec2 DisplayFramebufferScale
        bint ConfigNavSwapGamepadButtons
        bint ConfigNavMoveSetMousePos
        bint ConfigNavCaptureKeyboard
        bint ConfigNavEscapeClearFocusItem
        bint ConfigNavEscapeClearFocusWindow
        bint ConfigNavCursorVisibleAuto
        bint ConfigNavCursorVisibleAlways
        bint MouseDrawCursor
        bint ConfigMacOSXBehaviors
        bint ConfigInputTrickleEventQueue
        bint ConfigInputTextCursorBlink
        bint ConfigInputTextEnterKeepActive
        bint ConfigDragClickToInputText
        bint ConfigWindowsResizeFromEdges
        bint ConfigWindowsMoveFromTitleBarOnly
        bint ConfigWindowsCopyContentsWithCtrlC
        bint ConfigScrollbarScrollByPage
        float ConfigMemoryCompactTimer
        float MouseDoubleClickTime
        float MouseDoubleClickMaxDist
        float MouseDragThreshold
        float KeyRepeatDelay
        float KeyRepeatRate
        bint ConfigErrorRecovery
        bint ConfigErrorRecoveryEnableAssert
        bint ConfigErrorRecoveryEnableDebugLog
        bint ConfigErrorRecoveryEnableTooltip
        bint ConfigDebugIsDebuggerPresent
        bint ConfigDebugHighlightIdConflicts
        bint ConfigDebugHighlightIdConflictsShowItemPicker
        bint ConfigDebugBeginReturnValueOnce
        bint ConfigDebugBeginReturnValueLoop
        bint ConfigDebugIgnoreFocusLoss
        bint ConfigDebugIniSettings
        const char* BackendPlatformName
        const char* BackendRendererName
        void* BackendPlatformUserData
        void* BackendRendererUserData
        void* BackendLanguageUserData
        void AddKeyEvent(ImGuiKey, bint)
        void AddKeyAnalogEvent(ImGuiKey, bint, float)
        void AddMousePosEvent(float, float)
        void AddMouseButtonEvent(int, bint)
        void AddMouseWheelEvent(float, float)
        void AddMouseSourceEvent(ImGuiMouseSource)
        void AddFocusEvent(bint)
        void AddInputCharacter(unsigned int)
        void AddInputCharacterUTF16(ImWchar16)
        void AddInputCharactersUTF8(const char*)
        void SetKeyEventNativeData(ImGuiKey, int, int, int)
        void SetAppAcceptingEvents(bint)
        void ClearEventsQueue()
        void ClearInputKeys()
        void ClearInputMouse()
        void ClearInputCharacters()
        bint WantCaptureMouse
        bint WantCaptureKeyboard
        bint WantTextInput
        bint WantSetMousePos
        bint WantSaveIniSettings
        bint NavActive
        bint NavVisible
        float Framerate
        int MetricsRenderVertices
        int MetricsRenderIndices
        int MetricsRenderWindows
        int MetricsActiveWindows
        ImVec2 MouseDelta
        ImGuiContext* Ctx
        ImVec2 MousePos
        bint MouseDown[5]
        float MouseWheel
        float MouseWheelH
        ImGuiMouseSource MouseSource
        bint KeyCtrl
        bint KeyShift
        bint KeyAlt
        bint KeySuper
        ImGuiKeyChord KeyMods
        ImGuiKeyData KeysData[155]
        bint WantCaptureMouseUnlessPopupClose
        ImVec2 MousePosPrev
        ImVec2 MouseClickedPos[5]
        double MouseClickedTime[5]
        bint MouseClicked[5]
        bint MouseDoubleClicked[5]
        ImU16 MouseClickedCount[5]
        ImU16 MouseClickedLastCount[5]
        bint MouseReleased[5]
        double MouseReleasedTime[5]
        bint MouseDownOwned[5]
        bint MouseDownOwnedUnlessPopupClose[5]
        bint MouseWheelRequestAxisSwap
        bint MouseCtrlLeftAsRightClick
        float MouseDownDuration[5]
        float MouseDownDurationPrev[5]
        float MouseDragMaxDistanceSqr[5]
        float PenPressure
        bint AppFocusLost
        bint AppAcceptingEvents
        ImWchar16 InputQueueSurrogate
        ImVector[ImWchar] InputQueueCharacters
        const char* (*GetClipboardTextFn)(void*)
        void (*SetClipboardTextFn)(void*, const char*)
        void* ClipboardUserData
        ImGuiIO()
    #struct ImGuiContext:
    #    pass
    cppclass ImGuiInputTextCallbackData:
        ImGuiContext* Ctx
        ImGuiInputTextFlags EventFlag
        ImGuiInputTextFlags Flags
        void* UserData
        ImWchar EventChar
        ImGuiKey EventKey
        char* Buf
        int BufTextLen
        int BufSize
        bint BufDirty
        int CursorPos
        int SelectionStart
        int SelectionEnd
        ImGuiInputTextCallbackData()
        void DeleteChars(int, int)
        void InsertChars(int, const char*)
        void InsertChars(int, const char*, const char*)
        void SelectAll()
        void ClearSelection()
        bint HasSelection()
    struct ImGuiSizeCallbackData:
        void* UserData
        ImVec2 Pos
        ImVec2 CurrentSize
        ImVec2 DesiredSize
    cppclass ImGuiPayload:
        void* Data
        int DataSize
        ImGuiID SourceId
        ImGuiID SourceParentId
        int DataFrameCount
        char DataType[33]
        bint Preview
        bint Delivery
        ImGuiPayload()
        void Clear()
        bint IsDataType(const char*)
        bint IsPreview()
        bint IsDelivery()
    cppclass ImGuiOnceUponAFrame:
        ImGuiOnceUponAFrame()
        int RefFrame
    cppclass ImGuiTextFilter:
        ImGuiTextFilter()
        ImGuiTextFilter(const char*)
        bint Draw()
        bint Draw(const char*)
        bint Draw(const char*, float)
        bint PassFilter(const char*)
        bint PassFilter(const char*, const char*)
        void Build()
        void Clear()
        bint IsActive()
        cppclass ImGuiTextRange:
            const char* b
            const char* e
            ImGuiTextRange()
            ImGuiTextRange(const char*, const char*)
            bint empty()
            void split(char, ImVector[ImGuiTextFilter.ImGuiTextRange]*)
        char InputBuf[256]
        ImVector[ImGuiTextRange] Filters
        int CountGrep
    cppclass ImGuiTextBuffer:
        ImVector[char] Buf
        ImGuiTextBuffer()
        char operator[](int)
        const char* begin()
        const char* end()
        int size()
        bint empty()
        void clear()
        void resize(int)
        void reserve(int)
        const char* c_str()
        void append(const char*)
        void append(const char*, const char*)
        void appendf(const char*)
        void appendfv(const char*, int)
    union pxdgen_anon_ImGuiStoragePair_0:
        int val_i
        float val_f
        void* val_p
    cppclass ImGuiStoragePair:
        ImGuiID key
        ImGuiStoragePair(ImGuiID, int)
        ImGuiStoragePair(ImGuiID, float)
        ImGuiStoragePair(ImGuiID, void*)
    cppclass ImGuiStorage:
        ImVector[ImGuiStoragePair] Data
        void Clear()
        int GetInt(ImGuiID, int)
        void SetInt(ImGuiID, int)
        bint GetBool(ImGuiID, bint)
        void SetBool(ImGuiID, bint)
        float GetFloat(ImGuiID, float)
        void SetFloat(ImGuiID, float)
        void* GetVoidPtr(ImGuiID)
        void SetVoidPtr(ImGuiID, void*)
        int* GetIntRef(ImGuiID, int)
        bint* GetBoolRef(ImGuiID, bint)
        float* GetFloatRef(ImGuiID, float)
        void** GetVoidPtrRef(ImGuiID)
        void** GetVoidPtrRef(ImGuiID, void*)
        void BuildSortByKey()
        void SetAllInt(int)
    #struct ImGuiContext:
    #    pass
    cppclass ImGuiListClipper:
        ImGuiContext* Ctx
        int DisplayStart
        int DisplayEnd
        int ItemsCount
        float ItemsHeight
        float StartPosY
        double StartSeekOffsetY
        void* TempData
        ImGuiListClipper()
        void Begin(int, float)
        void End()
        bint Step()
        void IncludeItemByIndex(int)
        void IncludeItemsByIndex(int, int)
        void SeekCursorForItem(int)
        void IncludeRangeByIndices(int, int)
        void ForceDisplayRangeByIndices(int, int)
    cppclass ImColor:
        ImVec4 Value
        ImColor()
        ImColor(float, float, float, float)
        ImColor(ImVec4&)
        ImColor(int, int, int, int)
        ImColor(ImU32)
        void SetHSV(float, float, float, float)
        @staticmethod
        ImColor HSV(float, float, float, float)
    enum ImGuiMultiSelectFlags_:
        ImGuiMultiSelectFlags_None = 0
        ImGuiMultiSelectFlags_SingleSelect = 1
        ImGuiMultiSelectFlags_NoSelectAll = 2
        ImGuiMultiSelectFlags_NoRangeSelect = 4
        ImGuiMultiSelectFlags_NoAutoSelect = 8
        ImGuiMultiSelectFlags_NoAutoClear = 16
        ImGuiMultiSelectFlags_NoAutoClearOnReselect = 32
        ImGuiMultiSelectFlags_BoxSelect1d = 64
        ImGuiMultiSelectFlags_BoxSelect2d = 128
        ImGuiMultiSelectFlags_BoxSelectNoScroll = 256
        ImGuiMultiSelectFlags_ClearOnEscape = 512
        ImGuiMultiSelectFlags_ClearOnClickVoid = 1024
        ImGuiMultiSelectFlags_ScopeWindow = 2048
        ImGuiMultiSelectFlags_ScopeRect = 4096
        ImGuiMultiSelectFlags_SelectOnClick = 8192
        ImGuiMultiSelectFlags_SelectOnClickRelease = 16384
        ImGuiMultiSelectFlags_NavWrapX = 65536
    struct ImGuiMultiSelectIO:
        ImVector[ImGuiSelectionRequest] Requests
        ImGuiSelectionUserData RangeSrcItem
        ImGuiSelectionUserData NavIdItem
        bint NavIdSelected
        bint RangeSrcReset
        int ItemsCount
    enum ImGuiSelectionRequestType:
        ImGuiSelectionRequestType_None = 0
        ImGuiSelectionRequestType_SetAll = 1
        ImGuiSelectionRequestType_SetRange = 2
    struct ImGuiSelectionRequest:
        ImGuiSelectionRequestType Type
        bint Selected
        ImS8 RangeDirection
        ImGuiSelectionUserData RangeFirstItem
        ImGuiSelectionUserData RangeLastItem
    cppclass ImGuiSelectionBasicStorage:
        int Size
        bint PreserveOrder
        void* UserData
        ImGuiID (*AdapterIndexToStorageId)(ImGuiSelectionBasicStorage*, int)
        int _SelectionOrder
        ImGuiStorage _Storage
        ImGuiSelectionBasicStorage()
        void ApplyRequests(ImGuiMultiSelectIO*)
        bint Contains(ImGuiID)
        void Clear()
        void Swap(ImGuiSelectionBasicStorage&)
        void SetItemSelected(ImGuiID, bint)
        bint GetNextSelectedItem(void**, ImGuiID*)
        ImGuiID GetStorageIdFromIndex(int)
    cppclass ImGuiSelectionExternalStorage:
        void* UserData
        void (*AdapterSetItemSelected)(ImGuiSelectionExternalStorage*, int, bint)
        ImGuiSelectionExternalStorage()
        void ApplyRequests(ImGuiMultiSelectIO*)
    ctypedef unsigned int ImDrawIdx
    ctypedef void (*ImDrawCallback)(ImDrawList*, ImDrawCmd*)
    cppclass ImDrawCmd:
        ImVec4 ClipRect
        ImTextureID TextureId
        unsigned int VtxOffset
        unsigned int IdxOffset
        unsigned int ElemCount
        ImDrawCallback UserCallback
        void* UserCallbackData
        int UserCallbackDataSize
        int UserCallbackDataOffset
        ImDrawCmd()
        ImTextureID GetTexID()
    struct ImDrawVert:
        ImVec2 pos
        ImVec2 uv
        ImU32 col
    struct ImDrawCmdHeader:
        ImVec4 ClipRect
        ImTextureID TextureId
        unsigned int VtxOffset
    struct ImDrawChannel:
        ImVector[ImDrawCmd] _CmdBuffer
        ImVector[ImDrawIdx] _IdxBuffer
    cppclass ImDrawListSplitter:
        int _Current
        int _Count
        ImVector[ImDrawChannel] _Channels
        ImDrawListSplitter()
        void Clear()
        void ClearFreeMemory()
        void Split(ImDrawList*, int)
        void Merge(ImDrawList*)
        void SetCurrentChannel(ImDrawList*, int)
    enum ImDrawFlags_:
        ImDrawFlags_None = 0
        ImDrawFlags_Closed = 1
        ImDrawFlags_RoundCornersTopLeft = 16
        ImDrawFlags_RoundCornersTopRight = 32
        ImDrawFlags_RoundCornersBottomLeft = 64
        ImDrawFlags_RoundCornersBottomRight = 128
        ImDrawFlags_RoundCornersNone = 256
        ImDrawFlags_RoundCornersTop = 48
        ImDrawFlags_RoundCornersBottom = 192
        ImDrawFlags_RoundCornersLeft = 80
        ImDrawFlags_RoundCornersRight = 160
        ImDrawFlags_RoundCornersAll = 240
        ImDrawFlags_RoundCornersDefault_ = 240
        ImDrawFlags_RoundCornersMask_ = 496
    enum ImDrawListFlags_:
        ImDrawListFlags_None = 0
        ImDrawListFlags_AntiAliasedLines = 1
        ImDrawListFlags_AntiAliasedLinesUseTex = 2
        ImDrawListFlags_AntiAliasedFill = 4
        ImDrawListFlags_AllowVtxOffset = 8
    struct ImDrawListSharedData:
        pass
    cppclass ImDrawList:
        ImVector[ImDrawCmd] CmdBuffer
        ImVector[ImDrawIdx] IdxBuffer
        ImVector[ImDrawVert] VtxBuffer
        ImDrawListFlags Flags
        unsigned int _VtxCurrentIdx
        ImDrawListSharedData* _Data
        ImDrawVert* _VtxWritePtr
        ImDrawIdx* _IdxWritePtr
        ImVector[ImVec2] _Path
        ImDrawCmdHeader _CmdHeader
        ImDrawListSplitter _Splitter
        ImVector[ImVec4] _ClipRectStack
        ImVector[ImTextureID] _TextureIdStack
        ImVector[ImU8] _CallbacksDataBuf
        float _FringeScale
        const char* _OwnerName
        ImDrawList(ImDrawListSharedData*)
        void PushClipRect(ImVec2&, ImVec2&, bint)
        void PushClipRectFullScreen()
        void PopClipRect()
        void PushTextureID(ImTextureID)
        void PopTextureID()
        ImVec2 GetClipRectMin()
        ImVec2 GetClipRectMax()
        void AddLine(ImVec2&, ImVec2&, ImU32, float)
        void AddRect(ImVec2&, ImVec2&, ImU32, float, ImDrawFlags, float)
        void AddRectFilled(ImVec2&, ImVec2&, ImU32, float, ImDrawFlags)
        void AddRectFilledMultiColor(ImVec2&, ImVec2&, ImU32, ImU32, ImU32, ImU32)
        void AddQuad(ImVec2&, ImVec2&, ImVec2&, ImVec2&, ImU32, float)
        void AddQuadFilled(ImVec2&, ImVec2&, ImVec2&, ImVec2&, ImU32)
        void AddTriangle(ImVec2&, ImVec2&, ImVec2&, ImU32, float)
        void AddTriangleFilled(ImVec2&, ImVec2&, ImVec2&, ImU32)
        void AddCircle(ImVec2&, float, ImU32, int, float)
        void AddCircleFilled(ImVec2&, float, ImU32, int)
        void AddNgon(ImVec2&, float, ImU32, int, float)
        void AddNgonFilled(ImVec2&, float, ImU32, int)
        void AddEllipse(ImVec2&, ImVec2&, ImU32, float, int, float)
        void AddEllipseFilled(ImVec2&, ImVec2&, ImU32, float, int)
        void AddText(ImVec2&, ImU32, const char*)
        void AddText(ImVec2&, ImU32, const char*, const char*)
        void AddText(ImFont*, float, ImVec2&, ImU32, const char*)
        void AddText(ImFont*, float, ImVec2&, ImU32, const char*, const char*)
        void AddText(ImFont*, float, ImVec2&, ImU32, const char*, const char*, float)
        void AddText(ImFont*, float, ImVec2&, ImU32, const char*, const char*, float, ImVec4*)
        void AddBezierCubic(ImVec2&, ImVec2&, ImVec2&, ImVec2&, ImU32, float, int)
        void AddBezierQuadratic(ImVec2&, ImVec2&, ImVec2&, ImU32, float, int)
        void AddPolyline(ImVec2*, int, ImU32, ImDrawFlags, float)
        void AddConvexPolyFilled(ImVec2*, int, ImU32)
        void AddConcavePolyFilled(ImVec2*, int, ImU32)
        void AddImage(ImTextureID, ImVec2&, ImVec2&)
        void AddImage(ImTextureID, ImVec2&, ImVec2&, ImVec2&)
        void AddImage(ImTextureID, ImVec2&, ImVec2&, ImVec2&, ImVec2&)
        void AddImage(ImTextureID, ImVec2&, ImVec2&, ImVec2&, ImVec2&, ImU32)
        void AddImageQuad(ImTextureID, ImVec2&, ImVec2&, ImVec2&, ImVec2&)
        void AddImageQuad(ImTextureID, ImVec2&, ImVec2&, ImVec2&, ImVec2&, ImVec2&)
        void AddImageQuad(ImTextureID, ImVec2&, ImVec2&, ImVec2&, ImVec2&, ImVec2&, ImVec2&)
        void AddImageQuad(ImTextureID, ImVec2&, ImVec2&, ImVec2&, ImVec2&, ImVec2&, ImVec2&, ImVec2&)
        void AddImageQuad(ImTextureID, ImVec2&, ImVec2&, ImVec2&, ImVec2&, ImVec2&, ImVec2&, ImVec2&, ImVec2&)
        void AddImageQuad(ImTextureID, ImVec2&, ImVec2&, ImVec2&, ImVec2&, ImVec2&, ImVec2&, ImVec2&, ImVec2&, ImU32)
        void AddImageRounded(ImTextureID, ImVec2&, ImVec2&, ImVec2&, ImVec2&, ImU32, float, ImDrawFlags)
        void PathClear()
        void PathLineTo(ImVec2&)
        void PathLineToMergeDuplicate(ImVec2&)
        void PathFillConvex(ImU32)
        void PathFillConcave(ImU32)
        void PathStroke(ImU32, ImDrawFlags, float)
        void PathArcTo(ImVec2&, float, float, float, int)
        void PathArcToFast(ImVec2&, float, int, int)
        void PathEllipticalArcTo(ImVec2&, ImVec2&, float, float, float, int)
        void PathBezierCubicCurveTo(ImVec2&, ImVec2&, ImVec2&, int)
        void PathBezierQuadraticCurveTo(ImVec2&, ImVec2&, int)
        void PathRect(ImVec2&, ImVec2&, float, ImDrawFlags)
        void AddCallback(ImDrawCallback, void*, int)
        void AddDrawCmd()
        ImDrawList* CloneOutput()
        void ChannelsSplit(int)
        void ChannelsMerge()
        void ChannelsSetCurrent(int)
        void PrimReserve(int, int)
        void PrimUnreserve(int, int)
        void PrimRect(ImVec2&, ImVec2&, ImU32)
        void PrimRectUV(ImVec2&, ImVec2&, ImVec2&, ImVec2&, ImU32)
        void PrimQuadUV(ImVec2&, ImVec2&, ImVec2&, ImVec2&, ImVec2&, ImVec2&, ImVec2&, ImVec2&, ImU32)
        void PrimWriteVtx(ImVec2&, ImVec2&, ImU32)
        void PrimWriteIdx(ImDrawIdx)
        void PrimVtx(ImVec2&, ImVec2&, ImU32)
        void _ResetForNewFrame()
        void _ClearFreeMemory()
        void _PopUnusedDrawCmd()
        void _TryMergeDrawCmds()
        void _OnChangedClipRect()
        void _OnChangedTextureID()
        void _OnChangedVtxOffset()
        void _SetTextureID(ImTextureID)
        int _CalcCircleAutoSegmentCount(float)
        void _PathArcToFastEx(ImVec2&, float, int, int, int)
        void _PathArcToN(ImVec2&, float, float, float, int)
    cppclass ImDrawData:
        bint Valid
        int CmdListsCount
        int TotalIdxCount
        int TotalVtxCount
        ImVector[ImDrawList] CmdLists
        ImVec2 DisplayPos
        ImVec2 DisplaySize
        ImVec2 FramebufferScale
        ImGuiViewport* OwnerViewport
        ImDrawData()
        void Clear()
        void AddDrawList(ImDrawList*)
        void DeIndexAllBuffers()
        void ScaleClipRects(ImVec2&)
    cppclass ImFontConfig:
        void* FontData
        int FontDataSize
        bint FontDataOwnedByAtlas
        bint MergeMode
        bint PixelSnapH
        int FontNo
        int OversampleH
        int OversampleV
        float SizePixels
        ImVec2 GlyphOffset
        ImWchar* GlyphRanges
        float GlyphMinAdvanceX
        float GlyphMaxAdvanceX
        float GlyphExtraAdvanceX
        unsigned int FontBuilderFlags
        float RasterizerMultiply
        float RasterizerDensity
        ImWchar EllipsisChar
        char Name[40]
        ImFont* DstFont
        ImFontConfig()
    struct ImFontGlyph:
        unsigned int Colored
        unsigned int Visible
        unsigned int Codepoint
        float AdvanceX
        float X0
        float Y0
        float X1
        float Y1
        float U0
        float V0
        float U1
        float V1
    cppclass ImFontGlyphRangesBuilder:
        ImVector[ImU32] UsedChars
        ImFontGlyphRangesBuilder()
        void Clear()
        bint GetBit(int)
        void SetBit(int)
        void AddChar(ImWchar)
        void AddText(const char*)
        void AddText(const char*, const char*)
        void AddRanges(ImWchar*)
        void BuildRanges(ImVector[ImWchar]*)
    cppclass ImFontAtlasCustomRect:
        unsigned short X
        unsigned short Y
        unsigned short Width
        unsigned short Height
        unsigned int GlyphID
        unsigned int GlyphColored
        float GlyphAdvanceX
        ImVec2 GlyphOffset
        ImFont* Font
        ImFontAtlasCustomRect()
        bint IsPacked()
    enum ImFontAtlasFlags_:
        ImFontAtlasFlags_None = 0
        ImFontAtlasFlags_NoPowerOfTwoHeight = 1
        ImFontAtlasFlags_NoMouseCursors = 2
        ImFontAtlasFlags_NoBakedLines = 4
    struct ImFontBuilderIO:
        pass
    cppclass ImFontAtlas:
        ImFontAtlas()
        ImFont* AddFont(ImFontConfig*)
        ImFont* AddFontDefault()
        ImFont* AddFontDefault(ImFontConfig*)
        ImFont* AddFontFromFileTTF(const char*, float)
        ImFont* AddFontFromFileTTF(const char*, float, ImFontConfig*)
        ImFont* AddFontFromFileTTF(const char*, float, ImFontConfig*, ImWchar*)
        ImFont* AddFontFromMemoryTTF(void*, int, float)
        ImFont* AddFontFromMemoryTTF(void*, int, float, ImFontConfig*)
        ImFont* AddFontFromMemoryTTF(void*, int, float, ImFontConfig*, ImWchar*)
        ImFont* AddFontFromMemoryCompressedTTF(const void*, int, float)
        ImFont* AddFontFromMemoryCompressedTTF(const void*, int, float, ImFontConfig*)
        ImFont* AddFontFromMemoryCompressedTTF(const void*, int, float, ImFontConfig*, ImWchar*)
        ImFont* AddFontFromMemoryCompressedBase85TTF(const char*, float)
        ImFont* AddFontFromMemoryCompressedBase85TTF(const char*, float, ImFontConfig*)
        ImFont* AddFontFromMemoryCompressedBase85TTF(const char*, float, ImFontConfig*, ImWchar*)
        void ClearInputData()
        void ClearFonts()
        void ClearTexData()
        void Clear()
        bint Build()
        void GetTexDataAsAlpha8(unsigned char**, int*, int*)
        void GetTexDataAsAlpha8(unsigned char**, int*, int*, int*)
        void GetTexDataAsRGBA32(unsigned char**, int*, int*)
        void GetTexDataAsRGBA32(unsigned char**, int*, int*, int*)
        bint IsBuilt()
        void SetTexID(ImTextureID)
        ImWchar* GetGlyphRangesDefault()
        ImWchar* GetGlyphRangesGreek()
        ImWchar* GetGlyphRangesKorean()
        ImWchar* GetGlyphRangesJapanese()
        ImWchar* GetGlyphRangesChineseFull()
        ImWchar* GetGlyphRangesChineseSimplifiedCommon()
        ImWchar* GetGlyphRangesCyrillic()
        ImWchar* GetGlyphRangesThai()
        ImWchar* GetGlyphRangesVietnamese()
        int AddCustomRectRegular(int, int)
        int AddCustomRectFontGlyph(ImFont*, ImWchar, int, int, float)
        int AddCustomRectFontGlyph(ImFont*, ImWchar, int, int, float, ImVec2&)
        ImFontAtlasCustomRect* GetCustomRectByIndex(int)
        void CalcCustomRectUV(ImFontAtlasCustomRect*, ImVec2*, ImVec2*)
        ImFontAtlasFlags Flags
        ImTextureID TexID
        int TexDesiredWidth
        int TexGlyphPadding
        void* UserData
        bint Locked
        bint TexReady
        bint TexPixelsUseColors
        unsigned char* TexPixelsAlpha8
        unsigned int* TexPixelsRGBA32
        int TexWidth
        int TexHeight
        ImVec2 TexUvScale
        ImVec2 TexUvWhitePixel
        ImVector[ImFont] Fonts
        ImVector[ImFontAtlasCustomRect] CustomRects
        ImVector[ImFontConfig] Sources
        ImVec4 TexUvLines[33]
        ImFontBuilderIO* FontBuilderIO
        unsigned int FontBuilderFlags
        int PackIdMouseCursors
        int PackIdLines
    cppclass ImFont:
        ImVector[float] IndexAdvanceX
        float FallbackAdvanceX
        float FontSize
        ImVector[ImU16] IndexLookup
        ImVector[ImFontGlyph] Glyphs
        ImFontGlyph* FallbackGlyph
        ImFontAtlas* ContainerAtlas
        ImFontConfig* Sources
        short SourcesCount
        short EllipsisCharCount
        ImWchar EllipsisChar
        ImWchar FallbackChar
        float EllipsisWidth
        float EllipsisCharStep
        float Scale
        float Ascent
        float Descent
        int MetricsTotalSurface
        bint DirtyLookupTables
        ImU8 Used8kPagesMap[1]
        ImFont()
        ImFontGlyph* FindGlyph(ImWchar)
        ImFontGlyph* FindGlyphNoFallback(ImWchar)
        float GetCharAdvance(ImWchar)
        bint IsLoaded()
        const char* GetDebugName()
        ImVec2 CalcTextSizeA(float, float, float, const char*)
        ImVec2 CalcTextSizeA(float, float, float, const char*, const char*)
        ImVec2 CalcTextSizeA(float, float, float, const char*, const char*, const char**)
        const char* CalcWordWrapPositionA(float, const char*, const char*, float)
        void RenderChar(ImDrawList*, float, ImVec2&, ImU32, ImWchar)
        void RenderText(ImDrawList*, float, ImVec2&, ImU32, ImVec4&, const char*, const char*, float, bint)
        void BuildLookupTable()
        void ClearOutputData()
        void GrowIndex(int)
        void AddGlyph(ImFontConfig*, ImWchar, float, float, float, float, float, float, float, float, float)
        void AddRemapChar(ImWchar, ImWchar, bint)
        bint IsGlyphRangeUnused(unsigned int, unsigned int)
    enum ImGuiViewportFlags_:
        ImGuiViewportFlags_None = 0
        ImGuiViewportFlags_IsPlatformWindow = 1
        ImGuiViewportFlags_IsPlatformMonitor = 2
        ImGuiViewportFlags_OwnedByApp = 4
    cppclass ImGuiViewport:
        ImGuiID ID
        ImGuiViewportFlags Flags
        ImVec2 Pos
        ImVec2 Size
        ImVec2 WorkPos
        ImVec2 WorkSize
        void* PlatformHandle
        void* PlatformHandleRaw
        ImGuiViewport()
        ImVec2 GetCenter()
        ImVec2 GetWorkCenter()
    cppclass ImGuiPlatformIO:
        ImGuiPlatformIO()
        const char* (*Platform_GetClipboardTextFn)(ImGuiContext*)
        void (*Platform_SetClipboardTextFn)(ImGuiContext*, const char*)
        void* Platform_ClipboardUserData
        bint (*Platform_OpenInShellFn)(ImGuiContext*, const char*)
        void* Platform_OpenInShellUserData
        void (*Platform_SetImeDataFn)(ImGuiContext*, ImGuiViewport*, ImGuiPlatformImeData*)
        void* Platform_ImeUserData
        ImWchar Platform_LocaleDecimalPoint
        void* Renderer_RenderState
    cppclass ImGuiPlatformImeData:
        bint WantVisible
        ImVec2 InputPos
        float InputLineHeight
        ImGuiPlatformImeData()


cdef extern from "imgui.h" namespace "ImGui" nogil:
    #struct ImGuiContext:
    #    pass
    struct ImDrawListSharedData:
        pass
    ImGuiContext* CreateContext()
    ImGuiContext* CreateContext(ImFontAtlas*)
    void DestroyContext()
    void DestroyContext(ImGuiContext*)
    ImGuiContext* GetCurrentContext()
    void SetCurrentContext(ImGuiContext*)
    ImGuiIO& GetIO()
    ImGuiPlatformIO& GetPlatformIO()
    ImGuiStyle& GetStyle()
    void NewFrame()
    void EndFrame()
    void Render()
    ImDrawData* GetDrawData()
    void ShowDemoWindow()
    void ShowDemoWindow(bint*)
    void ShowMetricsWindow()
    void ShowMetricsWindow(bint*)
    void ShowDebugLogWindow()
    void ShowDebugLogWindow(bint*)
    void ShowIDStackToolWindow()
    void ShowIDStackToolWindow(bint*)
    void ShowAboutWindow()
    void ShowAboutWindow(bint*)
    void ShowStyleEditor()
    void ShowStyleEditor(ImGuiStyle*)
    bint ShowStyleSelector(const char*)
    void ShowFontSelector(const char*)
    void ShowUserGuide()
    const char* GetVersion()
    void StyleColorsDark()
    void StyleColorsDark(ImGuiStyle*)
    void StyleColorsLight()
    void StyleColorsLight(ImGuiStyle*)
    void StyleColorsClassic()
    void StyleColorsClassic(ImGuiStyle*)
    bint Begin(const char*)
    bint Begin(const char*, bint*)
    bint Begin(const char*, bint*, ImGuiWindowFlags)
    void End()
    bint BeginChild(const char*)
    bint BeginChild(const char*, ImVec2&)
    bint BeginChild(const char*, ImVec2&, ImGuiChildFlags)
    bint BeginChild(const char*, ImVec2&, ImGuiChildFlags, ImGuiWindowFlags)
    bint BeginChild(ImGuiID)
    bint BeginChild(ImGuiID, ImVec2&)
    bint BeginChild(ImGuiID, ImVec2&, ImGuiChildFlags)
    bint BeginChild(ImGuiID, ImVec2&, ImGuiChildFlags, ImGuiWindowFlags)
    void EndChild()
    bint IsWindowAppearing()
    bint IsWindowCollapsed()
    bint IsWindowFocused(ImGuiFocusedFlags)
    bint IsWindowHovered(ImGuiHoveredFlags)
    ImDrawList* GetWindowDrawList()
    ImVec2 GetWindowPos()
    ImVec2 GetWindowSize()
    float GetWindowWidth()
    float GetWindowHeight()
    void SetNextWindowPos(ImVec2&, ImGuiCond)
    void SetNextWindowPos(ImVec2&, ImGuiCond, ImVec2&)
    void SetNextWindowSize(ImVec2&, ImGuiCond)
    void SetNextWindowSizeConstraints(ImVec2&, ImVec2&)
    void SetNextWindowSizeConstraints(ImVec2&, ImVec2&, ImGuiSizeCallback)
    void SetNextWindowSizeConstraints(ImVec2&, ImVec2&, ImGuiSizeCallback, void*)
    void SetNextWindowContentSize(ImVec2&)
    void SetNextWindowCollapsed(bint, ImGuiCond)
    void SetNextWindowFocus()
    void SetNextWindowScroll(ImVec2&)
    void SetNextWindowBgAlpha(float)
    void SetWindowPos(ImVec2&, ImGuiCond)
    void SetWindowSize(ImVec2&, ImGuiCond)
    void SetWindowCollapsed(bint, ImGuiCond)
    void SetWindowFocus()
    void SetWindowFontScale(float)
    void SetWindowPos(const char*, ImVec2&, ImGuiCond)
    void SetWindowSize(const char*, ImVec2&, ImGuiCond)
    void SetWindowCollapsed(const char*, bint, ImGuiCond)
    void SetWindowFocus(const char*)
    float GetScrollX()
    float GetScrollY()
    void SetScrollX(float)
    void SetScrollY(float)
    float GetScrollMaxX()
    float GetScrollMaxY()
    void SetScrollHereX(float)
    void SetScrollHereY(float)
    void SetScrollFromPosX(float, float)
    void SetScrollFromPosY(float, float)
    void PushFont(ImFont*)
    void PopFont()
    void PushStyleColor(ImGuiCol, ImU32)
    void PushStyleColor(ImGuiCol, ImVec4&)
    void PopStyleColor(int)
    void PushStyleVar(ImGuiStyleVar, float)
    void PushStyleVar(ImGuiStyleVar, ImVec2&)
    void PushStyleVarX(ImGuiStyleVar, float)
    void PushStyleVarY(ImGuiStyleVar, float)
    void PopStyleVar(int)
    void PushItemFlag(ImGuiItemFlags, bint)
    void PopItemFlag()
    void PushItemWidth(float)
    void PopItemWidth()
    void SetNextItemWidth(float)
    float CalcItemWidth()
    void PushTextWrapPos(float)
    void PopTextWrapPos()
    ImFont* GetFont()
    float GetFontSize()
    ImVec2 GetFontTexUvWhitePixel()
    ImU32 GetColorU32(ImGuiCol, float)
    ImU32 GetColorU32(ImVec4&)
    ImU32 GetColorU32(ImU32, float)
    ImVec4& GetStyleColorVec4(ImGuiCol)
    ImVec2 GetCursorScreenPos()
    void SetCursorScreenPos(ImVec2&)
    ImVec2 GetContentRegionAvail()
    ImVec2 GetCursorPos()
    float GetCursorPosX()
    float GetCursorPosY()
    void SetCursorPos(ImVec2&)
    void SetCursorPosX(float)
    void SetCursorPosY(float)
    ImVec2 GetCursorStartPos()
    void Separator()
    void SameLine(float, float)
    void NewLine()
    void Spacing()
    void Dummy(ImVec2&)
    void Indent(float)
    void Unindent(float)
    void BeginGroup()
    void EndGroup()
    void AlignTextToFramePadding()
    float GetTextLineHeight()
    float GetTextLineHeightWithSpacing()
    float GetFrameHeight()
    float GetFrameHeightWithSpacing()
    void PushID(const char*)
    void PushID(const char*, const char*)
    void PushID(const void*)
    void PushID(int)
    void PopID()
    ImGuiID GetID(const char*)
    ImGuiID GetID(const char*, const char*)
    ImGuiID GetID(const void*)
    ImGuiID GetID(int)
    void TextUnformatted(const char*)
    void TextUnformatted(const char*, const char*)
    void Text(const char*, ...)
    void TextV(const char*, int)
    void TextColored(ImVec4&, const char*)
    void TextColoredV(ImVec4&, const char*, int)
    void TextDisabled(const char*)
    void TextDisabledV(const char*, int)
    void TextWrapped(const char*)
    void TextWrappedV(const char*, int)
    void LabelText(const char*, const char*)
    void LabelTextV(const char*, const char*, int)
    void BulletText(const char*)
    void BulletTextV(const char*, int)
    void SeparatorText(const char*)
    bint Button(const char*)
    bint Button(const char*, ImVec2&)
    bint SmallButton(const char*)
    bint InvisibleButton(const char*, ImVec2&, ImGuiButtonFlags)
    bint ArrowButton(const char*, ImGuiDir)
    bint Checkbox(const char*, bint*)
    bint CheckboxFlags(const char*, int*, int)
    bint CheckboxFlags(const char*, unsigned int*, unsigned int)
    bint RadioButton(const char*, bint)
    bint RadioButton(const char*, int*, int)
    void ProgressBar(float)
    void ProgressBar(float, ImVec2&)
    void ProgressBar(float, ImVec2&, const char*)
    void Bullet()
    bint TextLink(const char*)
    void TextLinkOpenURL(const char*)
    void TextLinkOpenURL(const char*, const char*)
    void Image(ImTextureID, ImVec2&)
    void Image(ImTextureID, ImVec2&, ImVec2&)
    void Image(ImTextureID, ImVec2&, ImVec2&, ImVec2&)
    void ImageWithBg(ImTextureID, ImVec2&)
    void ImageWithBg(ImTextureID, ImVec2&, ImVec2&)
    void ImageWithBg(ImTextureID, ImVec2&, ImVec2&, ImVec2&)
    void ImageWithBg(ImTextureID, ImVec2&, ImVec2&, ImVec2&, ImVec4&)
    void ImageWithBg(ImTextureID, ImVec2&, ImVec2&, ImVec2&, ImVec4&, ImVec4&)
    bint ImageButton(const char*, ImTextureID, ImVec2&)
    bint ImageButton(const char*, ImTextureID, ImVec2&, ImVec2&)
    bint ImageButton(const char*, ImTextureID, ImVec2&, ImVec2&, ImVec2&)
    bint ImageButton(const char*, ImTextureID, ImVec2&, ImVec2&, ImVec2&, ImVec4&)
    bint ImageButton(const char*, ImTextureID, ImVec2&, ImVec2&, ImVec2&, ImVec4&, ImVec4&)
    bint BeginCombo(const char*, const char*, ImGuiComboFlags)
    void EndCombo()
    bint Combo(const char*, int*, const char*[], int, int)
    bint Combo(const char*, int*, const char*, int)
    bint Combo(const char*, int*, const char* (*)(void*, int), void*, int, int)
    bint DragFloat(const char*, float*, float, float, float)
    bint DragFloat(const char*, float*, float, float, float, const char*)
    bint DragFloat(const char*, float*, float, float, float, const char*, ImGuiSliderFlags)
    bint DragFloat2(const char*, float[2], float, float, float)
    bint DragFloat2(const char*, float[2], float, float, float, const char*)
    bint DragFloat2(const char*, float[2], float, float, float, const char*, ImGuiSliderFlags)
    bint DragFloat3(const char*, float[3], float, float, float)
    bint DragFloat3(const char*, float[3], float, float, float, const char*)
    bint DragFloat3(const char*, float[3], float, float, float, const char*, ImGuiSliderFlags)
    bint DragFloat4(const char*, float[4], float, float, float)
    bint DragFloat4(const char*, float[4], float, float, float, const char*)
    bint DragFloat4(const char*, float[4], float, float, float, const char*, ImGuiSliderFlags)
    bint DragFloatRange2(const char*, float*, float*, float, float, float)
    bint DragFloatRange2(const char*, float*, float*, float, float, float, const char*)
    bint DragFloatRange2(const char*, float*, float*, float, float, float, const char*, const char*)
    bint DragFloatRange2(const char*, float*, float*, float, float, float, const char*, const char*, ImGuiSliderFlags)
    bint DragInt(const char*, int*, float, int, int)
    bint DragInt(const char*, int*, float, int, int, const char*)
    bint DragInt(const char*, int*, float, int, int, const char*, ImGuiSliderFlags)
    bint DragInt2(const char*, int[2], float, int, int)
    bint DragInt2(const char*, int[2], float, int, int, const char*)
    bint DragInt2(const char*, int[2], float, int, int, const char*, ImGuiSliderFlags)
    bint DragInt3(const char*, int[3], float, int, int)
    bint DragInt3(const char*, int[3], float, int, int, const char*)
    bint DragInt3(const char*, int[3], float, int, int, const char*, ImGuiSliderFlags)
    bint DragInt4(const char*, int[4], float, int, int)
    bint DragInt4(const char*, int[4], float, int, int, const char*)
    bint DragInt4(const char*, int[4], float, int, int, const char*, ImGuiSliderFlags)
    bint DragIntRange2(const char*, int*, int*, float, int, int)
    bint DragIntRange2(const char*, int*, int*, float, int, int, const char*)
    bint DragIntRange2(const char*, int*, int*, float, int, int, const char*, const char*)
    bint DragIntRange2(const char*, int*, int*, float, int, int, const char*, const char*, ImGuiSliderFlags)
    bint DragScalar(const char*, ImGuiDataType, void*, float)
    bint DragScalar(const char*, ImGuiDataType, void*, float, const void*)
    bint DragScalar(const char*, ImGuiDataType, void*, float, const void*, const void*)
    bint DragScalar(const char*, ImGuiDataType, void*, float, const void*, const void*, const char*)
    bint DragScalar(const char*, ImGuiDataType, void*, float, const void*, const void*, const char*, ImGuiSliderFlags)
    bint DragScalarN(const char*, ImGuiDataType, void*, int, float)
    bint DragScalarN(const char*, ImGuiDataType, void*, int, float, const void*)
    bint DragScalarN(const char*, ImGuiDataType, void*, int, float, const void*, const void*)
    bint DragScalarN(const char*, ImGuiDataType, void*, int, float, const void*, const void*, const char*)
    bint DragScalarN(const char*, ImGuiDataType, void*, int, float, const void*, const void*, const char*, ImGuiSliderFlags)
    bint SliderFloat(const char*, float*, float, float)
    bint SliderFloat(const char*, float*, float, float, const char*)
    bint SliderFloat(const char*, float*, float, float, const char*, ImGuiSliderFlags)
    bint SliderFloat2(const char*, float[2], float, float)
    bint SliderFloat2(const char*, float[2], float, float, const char*)
    bint SliderFloat2(const char*, float[2], float, float, const char*, ImGuiSliderFlags)
    bint SliderFloat3(const char*, float[3], float, float)
    bint SliderFloat3(const char*, float[3], float, float, const char*)
    bint SliderFloat3(const char*, float[3], float, float, const char*, ImGuiSliderFlags)
    bint SliderFloat4(const char*, float[4], float, float)
    bint SliderFloat4(const char*, float[4], float, float, const char*)
    bint SliderFloat4(const char*, float[4], float, float, const char*, ImGuiSliderFlags)
    bint SliderAngle(const char*, float*, float, float)
    bint SliderAngle(const char*, float*, float, float, const char*)
    bint SliderAngle(const char*, float*, float, float, const char*, ImGuiSliderFlags)
    bint SliderInt(const char*, int*, int, int)
    bint SliderInt(const char*, int*, int, int, const char*)
    bint SliderInt(const char*, int*, int, int, const char*, ImGuiSliderFlags)
    bint SliderInt2(const char*, int[2], int, int)
    bint SliderInt2(const char*, int[2], int, int, const char*)
    bint SliderInt2(const char*, int[2], int, int, const char*, ImGuiSliderFlags)
    bint SliderInt3(const char*, int[3], int, int)
    bint SliderInt3(const char*, int[3], int, int, const char*)
    bint SliderInt3(const char*, int[3], int, int, const char*, ImGuiSliderFlags)
    bint SliderInt4(const char*, int[4], int, int)
    bint SliderInt4(const char*, int[4], int, int, const char*)
    bint SliderInt4(const char*, int[4], int, int, const char*, ImGuiSliderFlags)
    bint SliderScalar(const char*, ImGuiDataType, void*, const void*, const void*)
    bint SliderScalar(const char*, ImGuiDataType, void*, const void*, const void*, const char*)
    bint SliderScalar(const char*, ImGuiDataType, void*, const void*, const void*, const char*, ImGuiSliderFlags)
    bint SliderScalarN(const char*, ImGuiDataType, void*, int, const void*, const void*)
    bint SliderScalarN(const char*, ImGuiDataType, void*, int, const void*, const void*, const char*)
    bint SliderScalarN(const char*, ImGuiDataType, void*, int, const void*, const void*, const char*, ImGuiSliderFlags)
    bint VSliderFloat(const char*, ImVec2&, float*, float, float)
    bint VSliderFloat(const char*, ImVec2&, float*, float, float, const char*)
    bint VSliderFloat(const char*, ImVec2&, float*, float, float, const char*, ImGuiSliderFlags)
    bint VSliderInt(const char*, ImVec2&, int*, int, int)
    bint VSliderInt(const char*, ImVec2&, int*, int, int, const char*)
    bint VSliderInt(const char*, ImVec2&, int*, int, int, const char*, ImGuiSliderFlags)
    bint VSliderScalar(const char*, ImVec2&, ImGuiDataType, void*, const void*, const void*)
    bint VSliderScalar(const char*, ImVec2&, ImGuiDataType, void*, const void*, const void*, const char*)
    bint VSliderScalar(const char*, ImVec2&, ImGuiDataType, void*, const void*, const void*, const char*, ImGuiSliderFlags)
    bint InputText(const char*, char*, int, ImGuiInputTextFlags)
    bint InputText(const char*, char*, int, ImGuiInputTextFlags, ImGuiInputTextCallback)
    bint InputText(const char*, char*, int, ImGuiInputTextFlags, ImGuiInputTextCallback, void*)
    bint InputTextMultiline(const char*, char*, int)
    bint InputTextMultiline(const char*, char*, int, ImVec2&)
    bint InputTextMultiline(const char*, char*, int, ImVec2&, ImGuiInputTextFlags)
    bint InputTextMultiline(const char*, char*, int, ImVec2&, ImGuiInputTextFlags, ImGuiInputTextCallback)
    bint InputTextMultiline(const char*, char*, int, ImVec2&, ImGuiInputTextFlags, ImGuiInputTextCallback, void*)
    bint InputTextWithHint(const char*, const char*, char*, int, ImGuiInputTextFlags)
    bint InputTextWithHint(const char*, const char*, char*, int, ImGuiInputTextFlags, ImGuiInputTextCallback)
    bint InputTextWithHint(const char*, const char*, char*, int, ImGuiInputTextFlags, ImGuiInputTextCallback, void*)
    bint InputFloat(const char*, float*, float, float)
    bint InputFloat(const char*, float*, float, float, const char*)
    bint InputFloat(const char*, float*, float, float, const char*, ImGuiInputTextFlags)
    bint InputFloat2(const char*, float[2])
    bint InputFloat2(const char*, float[2], const char*)
    bint InputFloat2(const char*, float[2], const char*, ImGuiInputTextFlags)
    bint InputFloat3(const char*, float[3])
    bint InputFloat3(const char*, float[3], const char*)
    bint InputFloat3(const char*, float[3], const char*, ImGuiInputTextFlags)
    bint InputFloat4(const char*, float[4])
    bint InputFloat4(const char*, float[4], const char*)
    bint InputFloat4(const char*, float[4], const char*, ImGuiInputTextFlags)
    bint InputInt(const char*, int*, int, int, ImGuiInputTextFlags)
    bint InputInt2(const char*, int[2], ImGuiInputTextFlags)
    bint InputInt3(const char*, int[3], ImGuiInputTextFlags)
    bint InputInt4(const char*, int[4], ImGuiInputTextFlags)
    bint InputDouble(const char*, double*, double, double)
    bint InputDouble(const char*, double*, double, double, const char*)
    bint InputDouble(const char*, double*, double, double, const char*, ImGuiInputTextFlags)
    bint InputScalar(const char*, ImGuiDataType, void*)
    bint InputScalar(const char*, ImGuiDataType, void*, const void*)
    bint InputScalar(const char*, ImGuiDataType, void*, const void*, const void*)
    bint InputScalar(const char*, ImGuiDataType, void*, const void*, const void*, const char*)
    bint InputScalar(const char*, ImGuiDataType, void*, const void*, const void*, const char*, ImGuiInputTextFlags)
    bint InputScalarN(const char*, ImGuiDataType, void*, int)
    bint InputScalarN(const char*, ImGuiDataType, void*, int, const void*)
    bint InputScalarN(const char*, ImGuiDataType, void*, int, const void*, const void*)
    bint InputScalarN(const char*, ImGuiDataType, void*, int, const void*, const void*, const char*)
    bint InputScalarN(const char*, ImGuiDataType, void*, int, const void*, const void*, const char*, ImGuiInputTextFlags)
    bint ColorEdit3(const char*, float[3], ImGuiColorEditFlags)
    bint ColorEdit4(const char*, float[4], ImGuiColorEditFlags)
    bint ColorPicker3(const char*, float[3], ImGuiColorEditFlags)
    bint ColorPicker4(const char*, float[4], ImGuiColorEditFlags)
    bint ColorPicker4(const char*, float[4], ImGuiColorEditFlags, const float*)
    bint ColorButton(const char*, ImVec4&, ImGuiColorEditFlags)
    bint ColorButton(const char*, ImVec4&, ImGuiColorEditFlags, ImVec2&)
    void SetColorEditOptions(ImGuiColorEditFlags)
    bint TreeNode(const char*)
    bint TreeNode(const char*, const char*)
    bint TreeNode(const void*, const char*)
    bint TreeNodeV(const char*, const char*, int)
    bint TreeNodeV(const void*, const char*, int)
    bint TreeNodeEx(const char*, ImGuiTreeNodeFlags)
    bint TreeNodeEx(const char*, ImGuiTreeNodeFlags, const char*)
    bint TreeNodeEx(const void*, ImGuiTreeNodeFlags, const char*)
    bint TreeNodeExV(const char*, ImGuiTreeNodeFlags, const char*, int)
    bint TreeNodeExV(const void*, ImGuiTreeNodeFlags, const char*, int)
    void TreePush(const char*)
    void TreePush(const void*)
    void TreePop()
    float GetTreeNodeToLabelSpacing()
    bint CollapsingHeader(const char*, ImGuiTreeNodeFlags)
    bint CollapsingHeader(const char*, bint*, ImGuiTreeNodeFlags)
    void SetNextItemOpen(bint, ImGuiCond)
    void SetNextItemStorageID(ImGuiID)
    bint Selectable(const char*, bint, ImGuiSelectableFlags)
    bint Selectable(const char*, bint, ImGuiSelectableFlags, ImVec2&)
    bint Selectable(const char*, bint*, ImGuiSelectableFlags)
    bint Selectable(const char*, bint*, ImGuiSelectableFlags, ImVec2&)
    ImGuiMultiSelectIO* BeginMultiSelect(ImGuiMultiSelectFlags, int, int)
    ImGuiMultiSelectIO* EndMultiSelect()
    void SetNextItemSelectionUserData(ImGuiSelectionUserData)
    bint IsItemToggledSelection()
    bint BeginListBox(const char*)
    bint BeginListBox(const char*, ImVec2&)
    void EndListBox()
    bint ListBox(const char*, int*, const char*[], int, int)
    bint ListBox(const char*, int*, const char* (*)(void*, int), void*, int, int)
    void PlotLines(const char*, const float*, int, int)
    void PlotLines(const char*, const float*, int, int, const char*)
    void PlotLines(const char*, const float*, int, int, const char*, float)
    void PlotLines(const char*, const float*, int, int, const char*, float, float)
    void PlotLines(const char*, const float*, int, int, const char*, float, float, ImVec2)
    void PlotLines(const char*, const float*, int, int, const char*, float, float, ImVec2, int)
    void PlotLines(const char*, float (*)(void*, int), void*, int, int)
    void PlotLines(const char*, float (*)(void*, int), void*, int, int, const char*)
    void PlotLines(const char*, float (*)(void*, int), void*, int, int, const char*, float)
    void PlotLines(const char*, float (*)(void*, int), void*, int, int, const char*, float, float)
    void PlotLines(const char*, float (*)(void*, int), void*, int, int, const char*, float, float, ImVec2)
    void PlotHistogram(const char*, const float*, int, int)
    void PlotHistogram(const char*, const float*, int, int, const char*)
    void PlotHistogram(const char*, const float*, int, int, const char*, float)
    void PlotHistogram(const char*, const float*, int, int, const char*, float, float)
    void PlotHistogram(const char*, const float*, int, int, const char*, float, float, ImVec2)
    void PlotHistogram(const char*, const float*, int, int, const char*, float, float, ImVec2, int)
    void PlotHistogram(const char*, float (*)(void*, int), void*, int, int)
    void PlotHistogram(const char*, float (*)(void*, int), void*, int, int, const char*)
    void PlotHistogram(const char*, float (*)(void*, int), void*, int, int, const char*, float)
    void PlotHistogram(const char*, float (*)(void*, int), void*, int, int, const char*, float, float)
    void PlotHistogram(const char*, float (*)(void*, int), void*, int, int, const char*, float, float, ImVec2)
    void Value(const char*, bint)
    void Value(const char*, int)
    void Value(const char*, unsigned int)
    void Value(const char*, float)
    void Value(const char*, float, const char*)
    bint BeginMenuBar()
    void EndMenuBar()
    bint BeginMainMenuBar()
    void EndMainMenuBar()
    bint BeginMenu(const char*, bint)
    void EndMenu()
    bint MenuItem(const char*)
    bint MenuItem(const char*, const char*)
    bint MenuItem(const char*, const char*, bint)
    bint MenuItem(const char*, const char*, bint, bint)
    bint MenuItem(const char*, const char*, bint*, bint)
    bint BeginTooltip()
    void EndTooltip()
    void SetTooltip(const char*)
    void SetTooltipV(const char*, int)
    bint BeginItemTooltip()
    void SetItemTooltip(const char*)
    void SetItemTooltipV(const char*, int)
    bint BeginPopup(const char*, ImGuiWindowFlags)
    bint BeginPopupModal(const char*)
    bint BeginPopupModal(const char*, bint*)
    bint BeginPopupModal(const char*, bint*, ImGuiWindowFlags)
    void EndPopup()
    void OpenPopup(const char*, ImGuiPopupFlags)
    void OpenPopup(ImGuiID, ImGuiPopupFlags)
    void OpenPopupOnItemClick()
    void OpenPopupOnItemClick(const char*)
    void OpenPopupOnItemClick(const char*, ImGuiPopupFlags)
    void CloseCurrentPopup()
    bint BeginPopupContextItem()
    bint BeginPopupContextItem(const char*)
    bint BeginPopupContextItem(const char*, ImGuiPopupFlags)
    bint BeginPopupContextWindow()
    bint BeginPopupContextWindow(const char*)
    bint BeginPopupContextWindow(const char*, ImGuiPopupFlags)
    bint BeginPopupContextVoid()
    bint BeginPopupContextVoid(const char*)
    bint BeginPopupContextVoid(const char*, ImGuiPopupFlags)
    bint IsPopupOpen(const char*, ImGuiPopupFlags)
    bint BeginTable(const char*, int, ImGuiTableFlags)
    bint BeginTable(const char*, int, ImGuiTableFlags, ImVec2&)
    bint BeginTable(const char*, int, ImGuiTableFlags, ImVec2&, float)
    void EndTable()
    void TableNextRow(ImGuiTableRowFlags, float)
    bint TableNextColumn()
    bint TableSetColumnIndex(int)
    void TableSetupColumn(const char*, ImGuiTableColumnFlags, float)
    void TableSetupColumn(const char*, ImGuiTableColumnFlags, float, ImGuiID)
    void TableSetupScrollFreeze(int, int)
    void TableHeader(const char*)
    void TableHeadersRow()
    void TableAngledHeadersRow()
    ImGuiTableSortSpecs* TableGetSortSpecs()
    int TableGetColumnCount()
    int TableGetColumnIndex()
    int TableGetRowIndex()
    const char* TableGetColumnName(int)
    ImGuiTableColumnFlags TableGetColumnFlags(int)
    void TableSetColumnEnabled(int, bint)
    int TableGetHoveredColumn()
    void TableSetBgColor(ImGuiTableBgTarget, ImU32, int)
    void Columns(int)
    void Columns(int, const char*)
    void Columns(int, const char*, bint)
    void NextColumn()
    int GetColumnIndex()
    float GetColumnWidth(int)
    void SetColumnWidth(int, float)
    float GetColumnOffset(int)
    void SetColumnOffset(int, float)
    int GetColumnsCount()
    bint BeginTabBar(const char*, ImGuiTabBarFlags)
    void EndTabBar()
    bint BeginTabItem(const char*)
    bint BeginTabItem(const char*, bint*)
    bint BeginTabItem(const char*, bint*, ImGuiTabItemFlags)
    void EndTabItem()
    bint TabItemButton(const char*, ImGuiTabItemFlags)
    void SetTabItemClosed(const char*)
    void LogToTTY(int)
    void LogToFile(int)
    void LogToFile(int, const char*)
    void LogToClipboard(int)
    void LogFinish()
    void LogButtons()
    void LogText(const char*)
    void LogTextV(const char*, int)
    bint BeginDragDropSource(ImGuiDragDropFlags)
    bint SetDragDropPayload(const char*, const void*, int, ImGuiCond)
    void EndDragDropSource()
    bint BeginDragDropTarget()
    ImGuiPayload* AcceptDragDropPayload(const char*, ImGuiDragDropFlags)
    void EndDragDropTarget()
    ImGuiPayload* GetDragDropPayload()
    void BeginDisabled(bint)
    void EndDisabled()
    void PushClipRect(ImVec2&, ImVec2&, bint)
    void PopClipRect()
    void SetItemDefaultFocus()
    void SetKeyboardFocusHere(int)
    void SetNavCursorVisible(bint)
    void SetNextItemAllowOverlap()
    bint IsItemHovered(ImGuiHoveredFlags)
    bint IsItemActive()
    bint IsItemFocused()
    bint IsItemClicked(ImGuiMouseButton)
    bint IsItemVisible()
    bint IsItemEdited()
    bint IsItemActivated()
    bint IsItemDeactivated()
    bint IsItemDeactivatedAfterEdit()
    bint IsItemToggledOpen()
    bint IsAnyItemHovered()
    bint IsAnyItemActive()
    bint IsAnyItemFocused()
    ImGuiID GetItemID()
    ImVec2 GetItemRectMin()
    ImVec2 GetItemRectMax()
    ImVec2 GetItemRectSize()
    ImGuiViewport* GetMainViewport()
    ImDrawList* GetBackgroundDrawList()
    ImDrawList* GetForegroundDrawList()
    bint IsRectVisible(ImVec2&)
    bint IsRectVisible(ImVec2&, ImVec2&)
    double GetTime()
    int GetFrameCount()
    ImDrawListSharedData* GetDrawListSharedData()
    const char* GetStyleColorName(ImGuiCol)
    void SetStateStorage(ImGuiStorage*)
    ImGuiStorage* GetStateStorage()
    ImVec2 CalcTextSize(const char*)
    ImVec2 CalcTextSize(const char*, const char*)
    ImVec2 CalcTextSize(const char*, const char*, bint)
    ImVec2 CalcTextSize(const char*, const char*, bint, float)
    ImVec4 ColorConvertU32ToFloat4(ImU32)
    ImU32 ColorConvertFloat4ToU32(ImVec4&)
    void ColorConvertRGBtoHSV(float, float, float, float&, float&, float&)
    void ColorConvertHSVtoRGB(float, float, float, float&, float&, float&)
    bint IsKeyDown(ImGuiKey)
    bint IsKeyPressed(ImGuiKey, bint)
    bint IsKeyReleased(ImGuiKey)
    bint IsKeyChordPressed(ImGuiKeyChord)
    int GetKeyPressedAmount(ImGuiKey, float, float)
    const char* GetKeyName(ImGuiKey)
    void SetNextFrameWantCaptureKeyboard(bint)
    bint Shortcut(ImGuiKeyChord, ImGuiInputFlags)
    void SetNextItemShortcut(ImGuiKeyChord, ImGuiInputFlags)
    void SetItemKeyOwner(ImGuiKey)
    bint IsMouseDown(ImGuiMouseButton)
    bint IsMouseClicked(ImGuiMouseButton, bint)
    bint IsMouseReleased(ImGuiMouseButton)
    bint IsMouseDoubleClicked(ImGuiMouseButton)
    bint IsMouseReleasedWithDelay(ImGuiMouseButton, float)
    int GetMouseClickedCount(ImGuiMouseButton)
    bint IsMouseHoveringRect(ImVec2&, ImVec2&, bint)
    bint IsMousePosValid()
    bint IsMousePosValid(ImVec2*)
    bint IsAnyMouseDown()
    ImVec2 GetMousePos()
    ImVec2 GetMousePosOnOpeningCurrentPopup()
    bint IsMouseDragging(ImGuiMouseButton, float)
    ImVec2 GetMouseDragDelta(ImGuiMouseButton, float)
    void ResetMouseDragDelta(ImGuiMouseButton)
    ImGuiMouseCursor GetMouseCursor()
    void SetMouseCursor(ImGuiMouseCursor)
    void SetNextFrameWantCaptureMouse(bint)
    const char* GetClipboardText()
    void SetClipboardText(const char*)
    void LoadIniSettingsFromDisk(const char*)
    void LoadIniSettingsFromMemory(const char*, int)
    void SaveIniSettingsToDisk(const char*)
    const char* SaveIniSettingsToMemory()
    const char* SaveIniSettingsToMemory(int*)
    void DebugTextEncoding(const char*)
    void DebugFlashStyleColor(ImGuiCol)
    void DebugStartItemPicker()
    bint DebugCheckVersionAndDataLayout(const char*, int, int, int, int, int, int)
    void DebugLog(const char*)
    void DebugLogV(const char*, int)
    void SetAllocatorFunctions(ImGuiMemAllocFunc, ImGuiMemFreeFunc)
    void SetAllocatorFunctions(ImGuiMemAllocFunc, ImGuiMemFreeFunc, void*)
    void GetAllocatorFunctions(ImGuiMemAllocFunc*, ImGuiMemFreeFunc*, void**)
    void* MemAlloc(int)
    void MemFree(void*)
    void Image(ImTextureID, ImVec2&, ImVec2&, ImVec2&, ImVec4&, ImVec4&)
    void PushButtonRepeat(bint)
    void PopButtonRepeat()
    void PushTabStop(bint)
    void PopTabStop()
    ImVec2 GetContentRegionMax()
    ImVec2 GetWindowContentRegionMin()
    ImVec2 GetWindowContentRegionMax()
    bint BeginChildFrame(ImGuiID, ImVec2&, ImGuiWindowFlags)
    void EndChildFrame()
    void ShowStackToolWindow()
    void ShowStackToolWindow(bint*)
    bint Combo(const char*, int*, bint (*)(void*, int, const char**), void*, int, int)
    bint ListBox(const char*, int*, bint (*)(void*, int, const char**), void*, int, int)
    void SetItemAllowOverlap()
    void PushAllowKeyboardFocus(bint)
    void PopAllowKeyboardFocus()

cdef extern from "imgui_internal.h" namespace "ImGui" nogil:
    ImGuiKeyData* GetKeyData(ImGuiKey)
    ImGuiID GetActiveID()
    ImGuiID GetHoveredID()
    ImGuiID GetFocusID()

cdef extern from "imgui_internal.h" nogil:
    int ImTextCharFromUtf8(unsigned int* out_char, const char* in_text, const char* in_text_end)
    int ImFormatString(char* buf, size_t buf_size, const char* fmt, ...) 
    struct ImGuiContext:
        float MouseStationaryTimer
