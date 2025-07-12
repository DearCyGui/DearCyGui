import copy
import dearcygui as dcg
import enum
import inspect
import functools

level1 = "    "
level2 = level1 + level1
level3 = level2 + level1

# Class info cache to avoid redundant extraction
CLASS_INFO_CACHE = {}

def is_cython_default_docstring(docstring: str | None) -> bool:
    """
    Check if a docstring matches the pattern of Cython default special methods
    """
    if docstring is None or len(docstring) < 2:
        return False
    
    # Must be a single line
    if '\n' in docstring:
        return False

    # Contains 'self', 'Default', 'memory'
    if "self" in docstring or "Default" in docstring or "memory" in docstring or "Helper" in docstring:
        return True
    return False

# New helper function to extract class properties and methods info
def extract_class_info(object_class, instance):
    """
    Extract properties and methods information for a class.
    Returns a dict with:
    - disabled_properties: list of properties that can't be accessed
    - read_only_properties: list of properties that can't be written to
    - writable_properties: list of properties that can be written to
    - dynamic_properties: list of properties that are dynamic
    - methods: list of method objects
    - default_values: dict of default values for properties
    - docs: dict of docstrings for properties and methods
    """
    # Check if we already have this class info cached
    if object_class in CLASS_INFO_CACHE:
        return CLASS_INFO_CACHE[object_class]
        
    class_attributes = [v[0] for v in inspect.getmembers(object_class)]
    try:
        attributes = dir(instance)
    except:
        attributes = class_attributes
        
    dynamic_attributes = set(attributes).difference(set(class_attributes))
    disabled_properties = []
    read_only_properties = []
    writable_properties = []
    dynamic_properties = []
    methods = []
    properties = set()
    default_values = dict()
    docs = dict()

    whitelist_special_methods = [
        "__setitem__", "__getitem__", "__delitem__",
        "__call__",
        "__str__", "__repr__", "__len__",
        "__contains__", "__iter__", "__next__",
        "__add__", "__sub__", "__mul__",
        "__truediv__", "__floordiv__", "__mod__",
        "__pow__", "__lshift__", "__rshift__",
        "__and__", "__or__", "__xor__",
        "__lt__", "__le__", "__eq__",
        "__ne__", "__gt__", "__ge__",
        "__hash__", "__bool__", "__getattr__",
        "__setattr__", "__delattr__", "__dir__",
        "__getattribute__", "__reduce__", "__reduce_ex__",
        "__sizeof__", "__copy__", "__deepcopy__"
    ]
    
    for attr in sorted(attributes):
        if attr.startswith("_"):
            if attr not in whitelist_special_methods:
                continue
            # We must filter out the "default" implementations
            # that Cython provides.
            attr_inst = getattr(object_class, attr, None)
            doc = getattr(attr_inst, '__doc__', None)
            if is_cython_default_docstring(doc):
                continue

        attr_inst = getattr(object_class, attr, None)
        if attr_inst is not None and inspect.isbuiltin(attr_inst):
            continue
        is_dynamic = attr in dynamic_attributes
        docs[attr] = remove_jumps_start_and_end(getattr(attr_inst, '__doc__', None))
        default_value = None
        is_accessible = False
        is_writable = False
        is_property = inspect.isdatadescriptor(attr_inst)
        is_class_method = inspect.ismethoddescriptor(attr_inst) or callable(attr_inst)
        try:
            if instance is None:
                raise ValueError
            default_value = getattr(instance, attr)
            is_accessible = True
            setattr(instance, attr, default_value)
            is_writable = True
        except (AttributeError, RuntimeError):
            pass
        except (TypeError, ValueError, OverflowError):
            is_writable = True
            pass
        if is_property:
            if is_writable:
                writable_properties.append(attr)
                properties.add(attr)
                default_values[attr] = default_value
            elif is_accessible:
                read_only_properties.append(attr)
                properties.add(attr)
                default_values[attr] = default_value
            else:
                disabled_properties.append(attr)
        elif is_dynamic and is_accessible:
            dynamic_properties.append(attr)
            properties.add(attr)
            default_values[attr] = default_value
        elif is_class_method:
            methods.append(attr_inst)
    
    result = {
        'disabled_properties': disabled_properties,
        'read_only_properties': read_only_properties,
        'writable_properties': writable_properties,
        'dynamic_properties': dynamic_properties,
        'methods': methods,
        'properties': properties,
        'default_values': default_values,
        'docs': docs
    }
    
    # Cache the result
    CLASS_INFO_CACHE[object_class] = result
    return result

def is_method_same_as_parent(method, parent_methods, parent_class):
    """Check if method is identical to parent class method"""
    if method.__name__ not in [m.__name__ for m in parent_methods]:
        return False
        
    parent_method = getattr(parent_class, method.__name__, None)
    if parent_method is None:
        return False
        
    # Compare docstrings
    method_doc = remove_jumps_start_and_end(getattr(method, '__doc__', None))
    parent_doc = remove_jumps_start_and_end(getattr(parent_method, '__doc__', None))
    
    # If docstrings are different, methods are different
    if method_doc != parent_doc:
        return False
    
    # Try to compare signatures, but skip if an error occurs
    try:
        method_sig = inspect.signature(method)
        parent_sig = inspect.signature(parent_method)
        if method_sig != parent_sig:
            return False
    except:
        pass
        
    return True

def is_property_same_as_parent(prop_name, class_info, parent_class_info, object_class, parent_class, instance, parent_instance):
    """Check if property is identical to parent class property"""
    parent_properties = parent_class_info['properties']
    if prop_name not in parent_properties:
        return False
        
    # Check if property has same read/write state
    is_read_only = prop_name in class_info['read_only_properties']
    is_parent_read_only = prop_name in parent_class_info['read_only_properties']
    
    if is_read_only != is_parent_read_only:
        return False
        
    # Compare docstrings
    docs = class_info['docs'].get(prop_name)
    parent_docs = parent_class_info['docs'].get(prop_name)
    
    if docs != parent_docs:
        return False

    # Compare types
    try:
        child_value = class_info['default_values'].get(prop_name)
        parent_value = parent_class_info['default_values'].get(prop_name)
        
        child_type = typename(object_class, instance, prop_name, child_value)
        parent_type = typename(parent_class, parent_instance, prop_name, parent_value)
        
        if child_type != parent_type:
            return False
    except Exception as e:
        # If we can't determine types, default to including the property
        return False

    return True

def is_staticmethod(cls, method_name):
    """Check if a method is a staticmethod."""
    # Get the method descriptor from the class
    method = getattr(cls, method_name, None)
    if method is None:
        return False
    
    # Direct check for staticmethod
    if isinstance(method, staticmethod):
        return True
    
    # For Cython extension methods, use signature inspection
    sig = inspect.signature(method)
    # Static methods don't have 'self' or 'cls' as first parameter
    params = list(sig.parameters.values())
    if len(params) == 0 or (params[0].name != 'self' and params[0].name != 'cls'):
        return True
    return False

def is_classmethod(cls, method_name):
    """Check if a method is a classmethod."""
    # Get the method descriptor from the class
    method = getattr(cls, method_name, None)
    if method is None:
        return False
    
    # Direct check for classmethod
    if isinstance(method, classmethod):
        return True
    
    # For Cython extension methods, use signature inspection
    sig = inspect.signature(method)
    # Class methods typically have 'cls' as first parameter
    params = list(sig.parameters.values())
    if len(params) > 0 and params[0].name == 'cls':
        return True
    
    return False


def remove_jumps_start_and_end(s : str | None):
    if s is None:
        return None
    if len(s) < 2:
        return s
    if s[0] == '\n':
        s = s[1:]
    if s[-1] == '\n':
        s = s[:-1]
    return s

def get_short_docstring(s : str | None):
    if s is None:
        return None
    s = remove_jumps_start_and_end(s)
    if s is None:
        return None
    s = s.split("\n")
    if len(s) == 0:
        return None
    return s[0]

def indent(s: list[str] | str, trim_start=False, short=False):
    was_str = isinstance(s, str)
    if was_str:
        s = s.split("\n")
    if trim_start and s[0] == "":
        s = s[1:]
    if short:
        for i in range(len(s)):
            if s[i] == "":
                s = s[:i]
                break
    while len(s) > 0 and (s[-1] == "" or s[-1] == level1 or s[-1] == level2):
        s = s[:-1]
    s = [level1 + sub_s for sub_s in s]
    if trim_start:
        if len(s) == 0:
            return ""
        s0 = s[0].split(" ")
        s0 = [sub_s0 for sub_s0 in s0 if len(sub_s0) > 0]
        s[0] = " ".join(s0)
    if was_str:
        s = "\n".join(s)
    return s

def is_dcg_enum(value: object, v_type: str) -> bool:
    """Check if v is a DCG enum type."""
    return value is not None and hasattr(dcg, v_type)\
        and isinstance(value, int) and issubclass(getattr(dcg, v_type), enum.Enum)

hardcoded = {
    "parent": "'baseItem' | None",
    "pos_policy": "tuple['Positioning', 'Positioning']",
    "font": "'baseFont' | None",
    "fonts": "Sequence['Font']",
    "children": "Sequence['baseItem']",
    "previous_sibling": "'baseItem' | None",
    "next_sibling": "'baseItem' | None",
    "callback": "DCGCallable | None",
    "callbacks" : "Sequence[DCGCallable]",
    "color" : "Color",
    "fill" : "Color",
    "texture" : "'Texture' | None",
    "pattern" : "'Pattern' | None",
    "width": "float | str | 'baseSizing'",
    "height": "float | str | 'baseSizing'",
    "x": "float | str | 'baseSizing'",
    "y": "float | str | 'baseSizing'",
    "handlers": "Sequence['baseHandler'] | 'baseHandler' | None",
    "legend_handlers": "Sequence['baseHandler'] | 'baseHandler' | None",
    "recent_scales": "Sequence[float]",
    "queue": "TaskSubmitter",
}


def typename(object_class, instance, name, value):
    if name == "children":
        if issubclass(object_class, dcg.DrawInWindow) or \
           issubclass(object_class, dcg.DrawInPlot) or \
           issubclass(object_class, dcg.ViewportDrawList) or \
           issubclass(object_class, dcg.DrawInvisibleButton):
            return "Sequence['drawingItem']"
        if issubclass(object_class, dcg.Plot):
            return "Sequence['plotElement']"
        if issubclass(object_class, dcg.Window):
            return "Sequence['uiItem' | 'MenuBar']"
        if issubclass(object_class, dcg.WindowLayout):
            return "Sequence['Window' | 'WindowLayout']"
        if issubclass(object_class, dcg.ChildWindow):
            return "Sequence['uiItem' | 'MenuBar']"
        if issubclass(object_class, dcg.Viewport):
            return "Sequence['Window' | 'WindowLayout' | 'ViewportDrawList' | 'MenuBar']"
        if issubclass(object_class, dcg.drawingItem):
            try:
                instance.children = [dcg.DrawLine(instance.context)]
                return "Sequence['drawingItem']"
            except:
                return "list[Never]"
        if issubclass(object_class, dcg.uiItem) or \
           issubclass(object_class, dcg.plotElement):
            try:
                instance.children = [dcg.Button(instance.context)]
                return "Sequence['uiItem']"
            except:
                return "list[Never]"
        if issubclass(object_class, dcg.baseHandler):
            try:
                instance.children = [dcg.HandlerList(instance.context)]
                return "Sequence['baseHandler']"
            except:
                return "list[Never]"
        if issubclass(object_class, dcg.baseTheme):
            try:
                instance.children = [dcg.ThemeColorImGui(instance.context)]
                return "Sequence['baseTheme']"
            except:
                return "list[Never]"
        if issubclass(object_class, dcg.SharedValue):
            return "list[Never]"
        try:
            children = ""
            children_types = instance.children_types
            if children_types & dcg.ChildType.DRAWING:
                children += "drawingItem | "
            if children_types & dcg.ChildType.HANDLER:
                children += "baseHandler | "
            if children_types & dcg.ChildType.MENUBAR:
                children += "MenuBar | "
            if children_types & dcg.ChildType.PLOTELEMENT:
                children += "plotElement | "
            if children_types & dcg.ChildType.TAB:
                children += "Tab | TabButton | "
            if children_types & dcg.ChildType.THEME:
                children += "baseTheme | "
            if children_types & dcg.ChildType.VIEWPORTDRAWLIST:
                children += "ViewportDrawList | "
            if children_types & dcg.ChildType.WIDGET:
                children += "uiItem | "
            if children_types & dcg.ChildType.WINDOW:
                children += "Window | "
            if children_types & dcg.ChildType.AXISTAG:
                children += "AxisTag | "
            if children == "":
                return "list[Never]"
            children = children[:-3]  # Remove the last " | "
            return f"Sequence[{children}]"
        except:
            pass


    if name == "parent":
        if issubclass(object_class, dcg.Window) or issubclass(object_class, dcg.WindowLayout):
            return "'Viewport' | 'WindowLayout' | None"
        if issubclass(object_class, dcg.MenuBar):
            return "'Viewport' | 'Window' | 'ChildWindow' | None"
        if issubclass(object_class, dcg.ViewportDrawList):
            return "'Viewport' | None"
        if issubclass(object_class, dcg.drawingItem):
            return "'DrawInWindow' | 'DrawInPlot' | 'ViewportDrawList' | 'drawingItem' | None"
        if issubclass(object_class, dcg.Tab) or \
           issubclass(object_class, dcg.TabButton):
            return "'TabBar' | None"
        if issubclass(object_class, dcg.uiItem):
            return "'uiItem' | 'plotElement' | None"
        if issubclass(object_class, dcg.plotElement):
            return "'Plot' | None"
        if issubclass(object_class, dcg.baseHandler):
            return "'baseHandler' | None"
        if issubclass(object_class, dcg.baseTheme):
            return "'baseTheme' | None"

    if name.endswith("sibling") or name == "before":
        try:
            item_type = instance.item_type
            if item_type == dcg.ChildType.DRAWING:
                return "'drawingItem' | None"
            if item_type == dcg.ChildType.HANDLER:
                return "'baseHandler' | None"
            if item_type == dcg.ChildType.MENUBAR:
                return "'MenuBar' | None"
            if item_type == dcg.ChildType.PLOTELEMENT:
                return "'plotElement' | None"
            if item_type == dcg.ChildType.TAB:
                return "'Tab' | 'TabButton' | None"
            if item_type == dcg.ChildType.THEME:
                return "'baseTheme' | None"
            if item_type == dcg.ChildType.VIEWPORTDRAWLIST:
                return "'ViewportDrawList' | None"
            if item_type == dcg.ChildType.WIDGET:
                return "'uiItem' | None"
            if item_type == dcg.ChildType.WINDOW:
                return "'Window' | None"
        except:
            pass

    if issubclass(object_class, dcg.plotElement) and type(value).__name__ == "_memoryviewslice":
        return "Array"

    if name == "shareable_value":
        if issubclass(object_class, dcg.DrawValue) or issubclass(object_class, dcg.TextValue):
            return "'SharedValue'"

    if name.startswith("uv") and isinstance(value, list) and len(value) == 2:
        return "Sequence[float] | tuple[float, float]"

    if name == "value":
        if issubclass(object_class, dcg.SharedColor) or \
           issubclass(object_class, dcg.ColorPicker) or \
           issubclass(object_class, dcg.ColorEdit) or \
           issubclass(object_class, dcg.ColorButton):
                return "Color"
        if object_class.__name__ == "SharedFloatVect":
            return "Array"
        #if issubclass(object_class, dcg.InputValue) or \
        #   issubclass(object_class, dcg.Slider):
        #    return "float | int | Sequence[float] | Sequence[int]"

    if name == "items" and issubclass(object_class, dcg.uiItem):
        return "Sequence[str]"

    if name == "positions" and issubclass(object_class, dcg.Layout):
        return "Sequence[int] | Sequence[float]"

    if name == "axes":
        if issubclass(object_class, dcg.Plot):
            return "Sequence['PlotAxisConfig']"
        if issubclass(object_class, dcg.plotElement):
            return "tuple['Axis', 'Axis']"

    default = None if value is None else type(value).__name__
    if isinstance(value, list):
        # if list is accepted, a sequence is accepted
        if len(value) == 0:
            default = "Sequence[Any]"
        else:
            if isinstance(value[0], str):
                default = "Sequence[str]"
            elif isinstance(value[0], int):
                default = "Sequence[int]"
            elif isinstance(value[0], float):
                default = "Sequence[float]"
            #elif isinstance(value[0], dcg.Coord):
            #    default = "Sequence[float] | tuple[float, float] | Coord"
            else:
                default = "Sequence[Any]"
    default = hardcoded.get(name, default)
    if issubclass(object_class, dcg.baseTheme) and default is None or name in ['fill']:
        if issubclass(object_class, dcg.baseThemeColor):
            return hardcoded["color"] + "| None"
        if issubclass(object_class, dcg.baseThemeStyle):
            try:
                instance[name] = (1.4, 1.4)
                return "tuple[float, float] | None"
            except:
                pass
            try:
                instance[name] = (1, 1)
                return "tuple[int, int] | None"
            except:
                pass
            try:
                instance[name] = 1.4
                return "float | None"
            except:
                pass
            try:
                instance[name] = 1
                return "int | None"
            except:
                pass
    if isinstance(value, dcg.Coord):
        return "Sequence[float] | tuple[float, float] | 'Coord'"
    if isinstance(value, dcg.Rect):
        return "Sequence[float] | tuple[float, float] | 'Rect'"
    if issubclass(object_class, dcg.Texture):
        if name == "width" or name == "height":
            return "int"
    if issubclass(object_class, dcg.PlotAxisConfig):
        if name == "labels":
            return "Sequence[str] | None"
        if name == "labels_coord":
            return "Array | None"
    if issubclass(object_class, dcg.plotElement) or issubclass(object_class, dcg.Subplots):
        if "ratios" in name:
            return "Array"
    if issubclass(object_class, dcg.drawingItem):
        if name == "points":
            return "Sequence['Coord'] | Array"
    if issubclass(object_class, dcg.Font):
        if name == "texture":
            return "'FontTexture'"
    return default


def generate_docstring_for_class(object_class, instance):
    # Get parent class info if exists
    parent_class_info = None
    try:
        parent_class = object_class.__bases__[0]
        if parent_class != object:
            # Only try to get info if we have an instance to work with
            parent_instance = None
            if instance is not None:
                try:
                    if hasattr(instance, 'context'):
                        context = instance.context
                        parent_instance = parent_class(context, attach=False)
                    else:
                        # Try a typical constructor pattern
                        parent_instance = parent_class()
                except:
                    pass
                    
            if parent_instance is not None:
                parent_class_info = extract_class_info(parent_class, parent_instance)
    except:
        pass
        
    # Get current class info
    class_info = extract_class_info(object_class, instance)
    
    disabled_properties = class_info['disabled_properties']
    read_only_properties = class_info['read_only_properties']
    writable_properties = class_info['writable_properties']
    dynamic_properties = class_info['dynamic_properties']
    methods = class_info['methods']
    properties = class_info['properties']
    default_values = class_info['default_values']
    docs = class_info['docs']

    result = []
    try:
        parent_class = object_class.__bases__[0]
        result += [
            f"class {object_class.__name__}({parent_class.__name__}):"
        ]
    except:
        result += [
            f"class {object_class.__name__}:"
        ]
    docstring = getattr(object_class, '__doc__', None)
    docstring = remove_jumps_start_and_end(docstring)
    if docstring is not None:
        result += [
            level1 + '"""',
            docstring,
            level1 + '"""'
        ]
        
    # Process methods
    all_methods = [object_class.__init__] + methods
    
    for method in all_methods:
        # Skip if method is identical to parent
        if parent_class_info and method.__name__ not in ["__init__", "configure"] and is_method_same_as_parent(method, parent_class_info['methods'], parent_class):
            continue
            
        try:
            call_sig = inspect.signature(method)
        except:
            # Manual handling of a few failure cases:
            if object_class.__name__ == "Context" and method.__name__ == "__init__":
                result.append(
                    level1 + f"def __init__(self, queue: TaskSubmitter | None = None) -> None:"
                )
                result.append(level2 + '"""Initialize the Context with an optional TaskSubmitter"""')
                result.append(level2 + "...")
            if object_class.__name__ == "baseTable":
                if method.__name__ == "__getitem__":
                    result.append(
                        level1 + f"def __getitem__(self, key: tuple[int, int]) -> 'TableElement':"
                    )
                    result.append(level2 + '"""Get an element by index"""')
                    result.append(level2 + "...")
                    continue
                elif method.__name__ == "__setitem__":
                    result.append(
                        level1 + f"def __setitem__(self, key: tuple[int, int], value: TableValue) -> None:"
                    )
                    result.append(level2 + '"""Set an element by index"""')
                    result.append(level2 + "...")
                    continue
                elif method.__name__ == "__delitem__":
                    result.append(
                        level1 + f"def __delitem__(self, key: tuple[int, int]) -> None:"
                    )
                    result.append(level2 + '"""Delete an element by inqqdex"""')
                    result.append(level2 + "...")
                    continue
                elif method.__name__ == "__iter__":
                    result.append(
                        level1 + f"def __iter__(self) -> Iterator[tuple[int, int]]:"
                    )
                    result.append(level2 + '"""Iterate over the keys of the table"""')
                    result.append(level2 + "...")
                    continue
                elif method.__name__ == "__len__":
                    result.append(
                        level1 + f"def __len__(self) -> int:"
                    )
                    result.append(level2 + '"""Get the number of elements in the table"""')
                    result.append(level2 + "...")
                    continue
                elif method.__name__ == "__contains__":
                    result.append(
                        level1 + f"def __contains__(self, key: tuple[int, int]) -> bool:"
                    )
                    result.append(level2 + '"""Check if the table contains an element by index"""')
                    result.append(level2 + "...")
                    continue
            if object_class.__name__ == "baseThemeColor":
                if method.__name__ == "__getitem__":
                    result.append(
                        level1 + f"def __getitem__(self, key: str | int) -> Color:"
                    )
                    result.append(level2 + '"""Get a color by name or index"""')
                    result.append(level2 + "...")
                    continue
                elif method.__name__ == "__setitem__":
                    result.append(
                        level1 + f"def __setitem__(self, key: str | int, value: Color) -> None:"
                    )
                    result.append(level2 + '"""Set a color by name or index"""')
                    result.append(level2 + "...")
                    continue
                elif method.__name__ == "__iter__":
                    result.append(
                        level1 + f"def __iter__(self) -> Iterator[tuple[str | int, Color]]:"
                    )
                    result.append(level2 + '"""Iterate over (color_name, color_value) pairs in the theme"""')
                    result.append(level2 + "...")
                    continue
            if object_class.__name__ == "baseThemeStyle":
                if method.__name__ == "__getitem__":
                    result.append(
                        level1 + f"def __getitem__(self, key: str | int) -> tuple[float, float] | float | int:"
                    )
                    result.append(level2 + '"""Get a style value by name or index"""')
                    result.append(level2 + "...")
                    continue
                elif method.__name__ == "__setitem__":
                    result.append(
                        level1 + f"def __setitem__(self, key: str | int, value: tuple[float, float] | float | int) -> None:"
                    )
                    result.append(level2 + '"""Set a style value by name or index"""')
                    result.append(level2 + "...")
                    continue
                elif method.__name__ == "__iter__":
                    result.append(
                        level1 + f"def __iter__(self) -> Iterator[tuple[str | int, tuple[float, float] | float | int]]:"
                    )
                    result.append(level2 + '"""Iterate over (style_name, style_value) pairs in the theme"""')
                    result.append(level2 + "...")
            if object_class.__name__ == "FontTexture":
                if method.__name__ == "__getitem__":
                    result.append(
                        level1 + f"def __getitem__(self, key: int) -> 'Font':"
                    )
                    result.append(level2 + '"""Get a built Font object by index"""')
                    result.append(level2 + "...")
                    continue
                elif method.__name__ == "__len__":
                    result.append(
                        level1 + f"def __len__(self) -> int:"
                    )
                    result.append(level2 + '"""The number of fonts in the texture"""')
                    result.append(level2 + "...")
                    continue
            continue
            
        additional_properties = copy.deepcopy(properties)
        additional_properties = [p for p in additional_properties if p not in read_only_properties]
        call_str = level1 + "def " + method.__name__ + "("
        # Check for special decorations (staticmethod, classmethod)
        if is_staticmethod(object_class, method.__name__):
            call_str = level1 + "@staticmethod\n" + call_str
        elif is_classmethod(object_class, method.__name__):
            call_str = level1 + "@classmethod\n" + call_str

        params_str = []
        params_str_kw = []
        kwargs_docs = []
        for (_, param) in call_sig.parameters.items():
            if method.__name__ not in ["__init__", "configure", "initialize"]:
                type_hint = f" : {param.annotation}" if param.annotation != inspect.Parameter.empty else ""
                value = f" = {param.default}" if param.default != inspect.Parameter.empty else ""
                param_str = f"{param.name}{type_hint}{value}"
                if param.kind == inspect.Parameter.VAR_POSITIONAL:
                    param_str = f"*{param_str}"
                elif param.kind == inspect.Parameter.VAR_KEYWORD:
                    param_str = f"**{param_str}"
                params_str.append(param_str)
                continue
            try:
                additional_properties.remove(param.name) 
            except:
                pass
            if param.name == 'args' and method.__name__ == "__init__":
                # Annotation seems incorrect for cython generated __init__
                if issubclass(object_class, dcg.Callback):
                    params_str.append("callback : DCGCallable")
                    continue
                params_str.append("context : Context")
                if object_class.__name__ == "Texture":
                    params_str.append("content: Array | None = None")
                if object_class.__name__ == "AutoFont":
                    params_str.append("base_size: float = 17.0")
                    params_str.append("font_creator: Callable[Concatenate[float, ...], 'GlyphSet'] | None = None")
                continue
            if param.name == 'kwargs':
                if "callbacks" in additional_properties and "callback" in additional_properties:
                    default_values["callback"] = None # callback is an alias for callbacks, but with different type hint
                if not(isinstance(object_class, dcg.Viewport)) and \
                   issubclass(object_class, dcg.baseItem) and \
                   method.__name__ == "__init__":
                    additional_properties.append("attach")
                    docs["attach"] = "Whether to attach the item to a parent. Default is None (auto)"
                    default_values["attach"] = None
                    additional_properties.append("before")
                    docs["before"] = "Attach the item just before the target item. Default is None (disabled)"
                    default_values["before"] = None
                for prop in sorted(additional_properties):
                    if docs[prop] is not None:
                        doc = docs[prop]
                        doc = get_short_docstring(doc)
                        doc = indent(doc, trim_start=True, short=True)
                        kwargs_docs.append(f"{level2}- {prop}: {doc}")
                    v = default_values[prop]
                    if isinstance(v, dcg.baseSizing):
                        v = float(v)
                    v_type = typename(object_class, instance, prop, v)
                    if v_type is None:
                        v_type = "Any"
                        v = "..."
                    elif is_dcg_enum(v, v_type):
                        v = getattr(dcg, v_type)(v)
                        # Retrieve the enum name
                        v = f"{v_type}.{v.name}"
                    elif prop == "axes" and isinstance(v, tuple) and len(v) == 2 and \
                            all(isinstance(axis, dcg.Axis) for axis in v):
                        v = f"(Axis.{v[0].name}, Axis.{v[1].name})"
                    elif v is not None and '<' in str(v): # default is a class
                        v = "..."
                    elif v_type == "NoneType": # Likely a class
                        v_type = "Any"
                        v = "..."
                    elif isinstance(v, str):
                        v = f'"{v}"'
                    if issubclass(object_class, dcg.SharedValue) and method.__name__ == "__init__":
                        params_str_kw.append(f"{prop} : {v_type}")
                    else:
                        params_str_kw.append(f"{prop} : {v_type} = {v}")
            else:
                params_str.append(str(param))
        if len(params_str_kw) > 0:
            # kwargs parameters are keyword-only
            # workaround issue to investigate:
            if issubclass(object_class, dcg.SharedValue):
                params_str = params_str + params_str_kw
            else:
                params_str = params_str + ["*"] + params_str_kw
        call_str += ", ".join(params_str) + ')'
        if call_sig.return_annotation == inspect.Signature.empty:
            call_str += ':'
        else:
            call_str += f' -> {call_sig.return_annotation}:'
        result.append(call_str)
        docstring = remove_jumps_start_and_end(getattr(method, '__doc__', None))
        if len(kwargs_docs) > 0:
            kwargs_docs = [f"{level2}Parameters", f"{level2}----------"] + kwargs_docs
            kwargs_docs = "\n".join(kwargs_docs)
            if docstring is None or "help(type(self))" in docstring:
                docstring = kwargs_docs
            else:
                docstring += "\n" + kwargs_docs
        elif docstring is not None and "help(type(self))" in docstring:
            docstring = None
        if docstring is not None:
            result += [
                level2 + '"""',
                docstring,
                level2 + '"""'
            ]
        result.append(level2 + "...")
        result.append("\n")

    # Only include __enter__ and __exit__ if they're not identical to parent class
    if hasattr(object_class, "__enter__"):
        include_enter = True

        if parent_class_info and hasattr(parent_class, "__enter__"):
            # Simple check - assume identical implementation if both have it
            # Could be improved with more detailed comparison if needed
            parent_enter = getattr(parent_class, "__enter__", None)
            current_enter = getattr(object_class, "__enter__", None)
            if parent_enter.__doc__ == current_enter.__doc__:
                include_enter = False
        
        if include_enter:        
            result.append(f"{level1}def __enter__(self) -> Self:")  #{object_class.__name__}:")
            result.append(f"{level2}...")
            result.append("\n")

    if hasattr(object_class, "__exit__"):
        include_exit = True
        if parent_class_info and hasattr(parent_class, "__exit__"):
            # Simple check - assume identical implementation if both have it
            parent_exit = getattr(parent_class, "__exit__", None)
            current_exit = getattr(object_class, "__exit__", None)
            if parent_exit.__doc__ == current_exit.__doc__:
                include_exit = False
        
        if include_exit:
            result.append(f"{level1}def __exit__(self, exc_type : Any, exc_value : Any, traceback : Any) -> Literal[False]:")
            result.append(f"{level2}...")
            result.append("\n")

    # Process properties
    for property in sorted(properties):
        # Skip if property is identical to parent
        if parent_class_info and is_property_same_as_parent(
            property, class_info, parent_class_info,
            object_class, parent_class, instance, parent_instance):
            continue
            
        result.append(level1 + "@property")
        definition = f"def {property}(self)"
        default_value = default_values.get(property, None)
        tname = typename(object_class, instance, property, default_value)
        if tname is None:
            result.append(f"{level1}{definition}:")
        else:
            tname_read = tname
            if isinstance(default_value, dcg.Coord):
                # property read is always Coord 
                tname_read = "'Coord'"
            elif isinstance(default_value, dcg.Rect):
                tname_read = "'Rect'"
            elif isinstance(default_value, dcg.baseRefSizing):
                # property read is always baseRefSizing
                tname_read = "'baseRefSizing'"
            elif property == "handlers" or property == "legend_handlers":
                # handlers is always list of 'baseHandler'
                tname_read = "list['baseHandler']"
            elif property == "children":
                # replace Sequence with list
                tname_read = tname.replace("Sequence[", "list[")
            elif property == "callbacks" or property == "callback":
                # callbacks is always list of DCGCallable3
                tname_read = "list[Callback]"
            elif property.startswith("uv") and isinstance(default_value, list) and len(default_value) == 2:
                # uv properties are always list of float
                tname_read = "list[float]"

            result.append(f"{level1}{definition} -> {tname_read}:")
        docstring = docs[property]
        if docstring is not None:
            if property in read_only_properties:
                docstring_prefix = "(Read-only) "
            else:
                docstring_prefix = ""
            if docstring[0] == " ":
                # Count leading spaces
                leading_spaces_count = len(docstring) - len(docstring.lstrip())
                leading_spaces = docstring[:leading_spaces_count]
                result += [
                    level2 + '"""',
                    leading_spaces + docstring_prefix + docstring[leading_spaces_count:],
                    level2 + '"""'
                ]
            else:
                result += [
                    level2 + '"""' + docstring_prefix + docstring,
                    level2 + '"""'
                ]
        result.append(level2 + "...")
        result.append("\n")
        if property in read_only_properties:
            continue

        result.append(f"{level1}@{property}.setter")
        if tname is None:
            result.append(f"{level1}def {property}(self, value):")
        else:
            result.append(f"{level1}def {property}(self, value : {tname}):")
        result.append(level2 + "...")
        result.append("\n")

    if object_class is dcg.Viewport:
        # Properties that need initialization
        other_properties = [("display", "Display"), ("displays", "list[Display]")]
        for (prop, tname) in other_properties:
            docstring = docs.get(prop, None)
            if docstring is not None:
                if docstring[0] == " ":
                    # Count leading spaces
                    leading_spaces_count = len(docstring) - len(docstring.lstrip())
                    leading_spaces = docstring[:leading_spaces_count]
                    result += [
                        level1 + f"def {prop}(self) -> {tname}:",
                        level2 + '"""',
                        leading_spaces + docstring[leading_spaces_count:],
                        level2 + '"""'
                    ]
                else:
                    result += [
                        level1 + f"def {prop}(self) -> {tname}:",
                        level2 + '"""' + docstring,
                        level2 + '"""'
                    ]
            else:
                result.append(level1 + f"def {prop}(self) -> {tname}:")
            result.append(level2 + "...")
            result.append("\n")



    # Strip trailing spaces
    for i in range(len(result)):
        result[i] = "\n".join([row.rstrip() for row in result[i].split("\n")])

    return result







def get_pyi_for_classes(C):
    def is_item_sub_class(name, targets):
        try:
            item = getattr(dcg, name)
            for target in targets:
                if issubclass(item, target):
                    return True
        except Exception:
            return False
    parent_classes = [dcg.Context, dcg.baseItem, dcg.SharedValue, dcg.Callback]
    dcg_items = sorted(dir(dcg))
    # remove items not starting with an upper case,
    # which are mainly for internal use, or items finishing by _
    #dcg_items = [i for i in dcg_items if i[0].isupper() and i[-1] != '_']
    #remove items that are not subclasses of the target.
    dcg_items = [i for i in dcg_items if is_item_sub_class(i, parent_classes)]

    # Custom sorting by: lowercase first, MRO length, alphabetical
    # This should help typing tools as it gets closer to a topological sort
    def custom_sort_key(name):
        obj = getattr(dcg, name)
        # 0 for lowercase (to sort first), 1 for uppercase
        case_priority = 0 if name[0].islower() else 1
        # Get MRO length (inheritance depth)
        mro_length = len(obj.__mro__)
        return (case_priority, mro_length, name)
    
    dcg_items.sort(key=custom_sort_key)

    result = []
    for name in dcg_items:
        object_class = getattr(dcg, name)
        if name == "Viewport":
            instance = C.viewport
        elif name == "Context":
            instance = C
        elif "Callback" in name:
            if name == "Callback": # custom stub for Callback
                continue
            instance = object_class(lambda : 0)
        elif issubclass(object_class, dcg.SharedValue):
            instance = None
            for val in [0, (0, 0, 0, 0), 0., "", None]:
                try:
                    instance = object_class(C, val)
                    break
                except:
                    pass
        elif issubclass(object_class, dcg.baseFont):
            instance = object_class(C)
        else:
            try:
                instance = object_class(C, attach=False)
            except:
                print(f"Could not create instance for {name}")
                continue
        result += generate_docstring_for_class(object_class, instance)
    return "\n".join(result)

def get_pyi_for_toplevel_functions(module):
    """Generate type stubs for top-level functions in the DearCyGui module."""
    result = []

    # already handled in the imported pyi files
    blacklist = [
        "parse_size"
    ]
    
    # Get all top-level items
    for name in sorted(dir(module)):
        if name in blacklist:
            continue
        # Skip private items and items that aren't functions
        item = getattr(module, name)
        
        # Check if it's a function (callable) but not a class
        if callable(item) and not inspect.isclass(item) and not name.startswith('_'):
            try:
                # Get signature
                sig = inspect.signature(item)
                
                # Build function definition with parameters
                params = []
                for param_name, param in sig.parameters.items():
                    type_hint = f": {param.annotation}" if param.annotation != inspect.Parameter.empty else ""
                    if name.startswith("color_") and param_name == "val":
                        type_hint = ": Color"
                    default = f" = {param.default}" if param.default != inspect.Parameter.empty else ""
                    
                    if param.kind == inspect.Parameter.VAR_POSITIONAL:
                        params.append(f"*{param_name}{type_hint}")
                    elif param.kind == inspect.Parameter.VAR_KEYWORD:
                        params.append(f"**{param_name}{type_hint}")
                    else:
                        params.append(f"{param_name}{type_hint}{default}")
                
                # Return type annotation
                return_annotation = f" -> {sig.return_annotation}" if sig.return_annotation != inspect.Parameter.empty else ""
                
                # Build the full function definition
                func_def = f"def {name}({', '.join(params)}){return_annotation}:"
                
                # Add docstring if available
                docstring = remove_jumps_start_and_end(getattr(item, '__doc__', None))
                if docstring:
                    result.extend([
                        func_def,
                        '    """',
                        docstring,
                        '    """',
                        "    ...",
                        "\n"
                    ])
                else:
                    result.extend([
                        func_def,
                        "    ...",
                        "\n"
                    ])
            except Exception as e:
                # If we can't process the function, add a placeholder
                result.extend([
                    f"def {name}(*args, **kwargs): # Error: {str(e)}",
                    "    ...",
                    "\n"
                ])
    
    return "\n".join(result)

with open("../dearcygui/core.pyi", "w") as f:
    with open("custom.pyi", "r") as f2:
        f.write(f2.read())
    f.write("\n")
    with open("types.pyi", "r") as f2:
        f.write(f2.read())
    f.write("\n")
    with open("imgui_types.pyi", "r") as f2:
        f.write(f2.read())
    f.write("\n")
    with open("state.pyi", "r") as f2:
        f.write(f2.read())
    f.write("\n")
    with open("sizing.pyi", "r") as f2:
        f.write(f2.read())
    f.write("\n")
    with open("font.pyi", "r") as f2:
        f.write(f2.read())
    f.write("\n")
    with open("table.pyi", "r") as f2:
        f.write(f2.read())
    f.write("\n")
    f.write(get_pyi_for_classes(dcg.Context()))
    f.write("\n")
    # Add toplevel functions
    f.write(get_pyi_for_toplevel_functions(dcg))
