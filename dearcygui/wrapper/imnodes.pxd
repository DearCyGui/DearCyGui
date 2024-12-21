# generated with pxdgen thirdparty/imnodes/imnodes.h -x c++ -f defines -f importall -w ImNodes -I thirdparty/imgui/

from dearcygui.wrapper.imgui cimport ImGuiContext, ImVec2

cdef extern from "imnodes.h" nogil:
    struct ImNodesContext:
        pass
    struct ImGuiContext:
        pass
    struct ImNodesEditorContext:
        pass
    struct ImRect:
        pass
    const int IMNODES_NAMESPACE
    ctypedef int ImNodesCol
    ctypedef int ImNodesStyleVar
    ctypedef int ImNodesStyleFlags
    ctypedef int ImNodesPinShape
    ctypedef int ImNodesAttributeFlags
    ctypedef int ImNodesMiniMapLocation
    enum ImNodesCol_:
        ImNodesCol_NodeBackground = 0
        ImNodesCol_NodeBackgroundHovered = 1
        ImNodesCol_NodeBackgroundSelected = 2
        ImNodesCol_NodeOutline = 3
        ImNodesCol_TitleBar = 4
        ImNodesCol_TitleBarHovered = 5
        ImNodesCol_TitleBarSelected = 6
        ImNodesCol_Link = 7
        ImNodesCol_LinkHovered = 8
        ImNodesCol_LinkSelected = 9
        ImNodesCol_Pin = 10
        ImNodesCol_PinHovered = 11
        ImNodesCol_BoxSelector = 12
        ImNodesCol_BoxSelectorOutline = 13
        ImNodesCol_GridBackground = 14
        ImNodesCol_GridLine = 15
        ImNodesCol_GridLinePrimary = 16
        ImNodesCol_MiniMapBackground = 17
        ImNodesCol_MiniMapBackgroundHovered = 18
        ImNodesCol_MiniMapOutline = 19
        ImNodesCol_MiniMapOutlineHovered = 20
        ImNodesCol_MiniMapNodeBackground = 21
        ImNodesCol_MiniMapNodeBackgroundHovered = 22
        ImNodesCol_MiniMapNodeBackgroundSelected = 23
        ImNodesCol_MiniMapNodeOutline = 24
        ImNodesCol_MiniMapLink = 25
        ImNodesCol_MiniMapLinkSelected = 26
        ImNodesCol_MiniMapCanvas = 27
        ImNodesCol_MiniMapCanvasOutline = 28
        ImNodesCol_COUNT = 29
    enum ImNodesStyleVar_:
        ImNodesStyleVar_GridSpacing = 0
        ImNodesStyleVar_NodeCornerRounding = 1
        ImNodesStyleVar_NodePadding = 2
        ImNodesStyleVar_NodeBorderThickness = 3
        ImNodesStyleVar_LinkThickness = 4
        ImNodesStyleVar_LinkLineSegmentsPerLength = 5
        ImNodesStyleVar_LinkHoverDistance = 6
        ImNodesStyleVar_PinCircleRadius = 7
        ImNodesStyleVar_PinQuadSideLength = 8
        ImNodesStyleVar_PinTriangleSideLength = 9
        ImNodesStyleVar_PinLineThickness = 10
        ImNodesStyleVar_PinHoverRadius = 11
        ImNodesStyleVar_PinOffset = 12
        ImNodesStyleVar_MiniMapPadding = 13
        ImNodesStyleVar_MiniMapOffset = 14
        ImNodesStyleVar_COUNT = 15
    enum ImNodesStyleFlags_:
        ImNodesStyleFlags_None = 0
        ImNodesStyleFlags_NodeOutline = 1
        ImNodesStyleFlags_GridLines = 4
        ImNodesStyleFlags_GridLinesPrimary = 8
        ImNodesStyleFlags_GridSnapping = 16
    enum ImNodesPinShape_:
        ImNodesPinShape_Circle = 0
        ImNodesPinShape_CircleFilled = 1
        ImNodesPinShape_Triangle = 2
        ImNodesPinShape_TriangleFilled = 3
        ImNodesPinShape_Quad = 4
        ImNodesPinShape_QuadFilled = 5
    enum ImNodesAttributeFlags_:
        ImNodesAttributeFlags_None = 0
        ImNodesAttributeFlags_EnableLinkDetachWithDragClick = 1
        ImNodesAttributeFlags_EnableLinkCreationOnSnap = 2
    cppclass ImNodesIO:
        cppclass EmulateThreeButtonMouse:
            EmulateThreeButtonMouse()
            const bint* Modifier
        EmulateThreeButtonMouse EmulateThreeButtonMouse
        cppclass LinkDetachWithModifierClick:
            LinkDetachWithModifierClick()
            const bint* Modifier
        LinkDetachWithModifierClick LinkDetachWithModifierClick
        cppclass MultipleSelectModifier:
            MultipleSelectModifier()
            const bint* Modifier
        MultipleSelectModifier MultipleSelectModifier
        int AltMouseButton
        float AutoPanningSpeed
        ImNodesIO()
    cppclass ImNodesStyle:
        float GridSpacing
        float NodeCornerRounding
        ImVec2 NodePadding
        float NodeBorderThickness
        float LinkThickness
        float LinkLineSegmentsPerLength
        float LinkHoverDistance
        float PinCircleRadius
        float PinQuadSideLength
        float PinTriangleSideLength
        float PinLineThickness
        float PinHoverRadius
        float PinOffset
        ImVec2 MiniMapPadding
        ImVec2 MiniMapOffset
        ImNodesStyleFlags Flags
        unsigned int Colors[29]
        ImNodesStyle()
    enum ImNodesMiniMapLocation_:
        ImNodesMiniMapLocation_BottomLeft = 0
        ImNodesMiniMapLocation_BottomRight = 1
        ImNodesMiniMapLocation_TopLeft = 2
        ImNodesMiniMapLocation_TopRight = 3
    ctypedef void (*ImNodesMiniMapNodeHoveringCallback)(int, void*)
    ctypedef void* ImNodesMiniMapNodeHoveringCallbackUserData


cdef extern from "imnodes.h" namespace "ImNodes" nogil:
    struct ImNodesContext:
        pass
    struct ImNodesEditorContext:
        pass
    struct ImRect:
        pass
    void SetImGuiContext(ImGuiContext*)
    ImNodesContext* CreateContext()
    void DestroyContext()
    void DestroyContext(ImNodesContext*)
    ImNodesContext* GetCurrentContext()
    void SetCurrentContext(ImNodesContext*)
    ImNodesEditorContext* EditorContextCreate()
    void EditorContextFree(ImNodesEditorContext*)
    void EditorContextSet(ImNodesEditorContext*)
    ImRect mvEditorGetSize()
    ImVec2 EditorContextGetPanning()
    void EditorContextResetPanning(ImVec2&)
    void EditorContextMoveToNode(const int)
    ImNodesIO& GetIO()
    ImNodesStyle& GetStyle()
    void StyleColorsDark()
    void StyleColorsDark(ImNodesStyle*)
    void StyleColorsClassic()
    void StyleColorsClassic(ImNodesStyle*)
    void StyleColorsLight()
    void StyleColorsLight(ImNodesStyle*)
    void BeginNodeEditor()
    void EndNodeEditor()
    void MiniMap(const float)
    void MiniMap(const float, ImNodesMiniMapLocation)
    void MiniMap(const float, ImNodesMiniMapLocation, ImNodesMiniMapNodeHoveringCallback)
    void MiniMap(const float, ImNodesMiniMapLocation, ImNodesMiniMapNodeHoveringCallback, ImNodesMiniMapNodeHoveringCallbackUserData)
    void PushColorStyle(ImNodesCol, unsigned int)
    void PopColorStyle()
    void PushStyleVar(ImNodesStyleVar, float)
    void PushStyleVar(ImNodesStyleVar, ImVec2&)
    void PopStyleVar(int)
    void BeginNode(int)
    void EndNode()
    ImVec2 GetNodeDimensions(int)
    void BeginNodeTitleBar()
    void EndNodeTitleBar()
    void BeginInputAttribute(int)
    void BeginInputAttribute(int, ImNodesPinShape)
    void EndInputAttribute()
    void BeginOutputAttribute(int)
    void BeginOutputAttribute(int, ImNodesPinShape)
    void EndOutputAttribute()
    void BeginStaticAttribute(int)
    void EndStaticAttribute()
    void PushAttributeFlag(ImNodesAttributeFlags)
    void PopAttributeFlag()
    void Link(int, int, int)
    void SetNodeDraggable(int, const bint)
    void SetNodeScreenSpacePos(int, ImVec2&)
    void SetNodeEditorSpacePos(int, ImVec2&)
    void SetNodeGridSpacePos(int, ImVec2&)
    ImVec2 GetNodeScreenSpacePos(const int)
    ImVec2 GetNodeEditorSpacePos(const int)
    ImVec2 GetNodeGridSpacePos(const int)
    void SnapNodeToGrid(int)
    bint IsEditorHovered()
    bint IsNodeHovered(int*)
    bint IsLinkHovered(int*)
    bint IsPinHovered(int*)
    int NumSelectedNodes()
    int NumSelectedLinks()
    void GetSelectedNodes(int*)
    void GetSelectedLinks(int*)
    void ClearNodeSelection()
    void ClearLinkSelection()
    void SelectNode(int)
    void ClearNodeSelection(int)
    bint IsNodeSelected(int)
    void SelectLink(int)
    void ClearLinkSelection(int)
    bint IsLinkSelected(int)
    bint IsAttributeActive()
    bint IsAnyAttributeActive()
    bint IsAnyAttributeActive(int*)
    bint IsLinkStarted(int*)
    bint IsLinkDropped()
    bint IsLinkDropped(int*)
    bint IsLinkDropped(int*, bint)
    bint IsLinkCreated(int*, int*)
    bint IsLinkCreated(int*, int*, bint*)
    bint IsLinkCreated(int*, int*, int*, int*)
    bint IsLinkCreated(int*, int*, int*, int*, bint*)
    bint IsLinkDestroyed(int*)
    const char* SaveCurrentEditorStateToIniString()
    const char* SaveCurrentEditorStateToIniString(size_t*)
    const char* SaveEditorStateToIniString(ImNodesEditorContext*)
    const char* SaveEditorStateToIniString(ImNodesEditorContext*, size_t*)
    void LoadCurrentEditorStateFromIniString(const char*, size_t)
    void LoadEditorStateFromIniString(ImNodesEditorContext*, const char*, size_t)
    void SaveCurrentEditorStateToIniFile(const char*)
    void SaveEditorStateToIniFile(ImNodesEditorContext*, const char*)
    void LoadCurrentEditorStateFromIniFile(const char*)
    void LoadEditorStateFromIniFile(ImNodesEditorContext*, const char*)


