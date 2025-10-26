"""
Configuration persistence utility for DearCyGui items.

This module provides functionality to automatically save and restore widget state
to/from a JSON configuration file. It allows DearCyGui applications to maintain
their UI state across sessions.

Example usage:
    ```python
    import dearcygui as dcg
    from dearcygui.utils.config import get_config_manager
    
    # Create a config manager that saves to 'app_config.json'
    with_config = get_config_manager('app_config.json')
    
    # Create a wrapped Window class that auto-saves position and size
    ConfigWindow = with_config(dcg.Window, ('x', 'y', 'width', 'height'))
    
    # Use it like a normal Window, but it will load/save its state
    C = dcg.Context()
    window = ConfigWindow(C, label="My Window", x=100, y=100, width=400, height=300)
    
    # When the program exits, the window's position and size are automatically saved
    # On next run, they will be restored from the config file
    ```
"""

from atexit import register as atexit_register, unregister as atexit_unregister
from collections.abc import Sequence, Callable
from weakref import ref as weakref
from dearcygui import baseSizing
from json import load as json_load, dump as json_dump, JSONDecodeError
from pathlib import Path
from typing import Any, TypeVar
from warnings import warn


T = TypeVar('T')


class ConfigManager:
    """
    Manages configuration persistence for DearCyGui items.
    
    This class handles loading configuration from a JSON file at startup,
    collecting item state when items are destroyed, and writing
    the configuration back to the file on program exit.
    
    Attributes:
        config_file: Path to the JSON configuration file
        config: Dictionary containing the loaded/current configuration
    """
    
    def __init__(self, config_file: Path):
        """
        Initialize the ConfigManager.
        
        Args:
            config_file: Path to the JSON configuration file
        """
        self.config_file = config_file
        self.config: dict[str, dict[str, Any]] = {}
        self._closed = False
        
        # Load existing config if file exists
        if self.config_file.exists():
            try:
                with open(self.config_file, 'r') as f:
                    self.config = json_load(f)
            except (JSONDecodeError, IOError) as e:
                warn(f"Warning: Could not load config from {self.config_file}: {type(e)}({str(e)})")
                self.config = {}
        
        # Register the save function to be called on program exit
        atexit_register(self._save_config)
    
    def _save_config(self) -> None:
        """
        Save configuration to the JSON file.
        
        This is called on program exit via atexit. By this time, all items
        should have already updated their config via update_item_config()
        called from their __del__ methods.
        """
        if self._closed:
            return
            
        try:
            # Ensure directory exists
            self.config_file.parent.mkdir(parents=True, exist_ok=True)
            
            with open(self.config_file, 'w', encoding='utf-8') as f:
                json_dump(self.config, f, indent=2)
        except IOError as e:
            warn(f"Warning: Could not save config to {self.config_file}: {type(e)}({str(e)})")

    def close(self):
        """
        Close the ConfigManager, saving the configuration and preventing further updates.
        
        After calling close(), no further configuration changes will be saved.
        Subsequent calls to close() have no effect.
        
        This is useful for testing or when you want to explicitly control when
        configuration is persisted.
        """
        if not self._closed:
            self._save_config()
            self._closed = True
            atexit_unregister(self._save_config)
    
    def _get_config(self, identifier: str, class_name: str) -> dict[str, Any] | None:
        """
        Retrieve saved configuration for a specific item.
        
        Args:
            uuid: The unique identifier of the item
            class_name: The class name of the item (for validation)
        
        Returns:
            Dictionary of saved attributes, or None if no config exists or class doesn't match.
        """
        if identifier not in self.config:
            return None
        
        entry = self.config[identifier]
        
        # Validate class name matches
        if entry.get('class') != class_name:
            warn(f"Warning: Config for id {identifier} has class '{entry.get('class')}' "
                 f"but expected '{class_name}'. Ignoring saved config.")
            return None

        return entry.get('attributes', {})
    
    def _update_item_config(self, identifier: str, class_name: str, 
                            strong_attrs: tuple[str, ...], weak_attrs: tuple[str, ...], 
                            item: Any) -> None:
        """
        Update configuration for an item.
        
        This is called from __del__ when an item is destroyed to capture its final state.
        Since UUIDs are strictly increasing, we don't need to check if the item
        is being created or destroyed - we just update the config.
        
        Note: strong_attrs and weak_attrs are saved together in the JSON.
        The distinction only matters during item creation based on current with_config() parameters.
        
        Args:
            identifier: The unique identifier of the item
            class_name: The class name of the item
            strong_attrs: Tuple of attribute names with strong persistence
            weak_attrs: Tuple of attribute names with weak persistence
            item: The item instance to read attributes from
        """
        if self._closed:
            return
        
        try:
            config_entry = {
                'class': class_name,
                'attributes': {}
            }
            
            # Save all attributes together (strong and weak)
            all_attrs = set(strong_attrs) | set(weak_attrs)
            for attr in all_attrs:
                try:
                    value = getattr(item, attr)
                    # Convert non-serializable types
                    if isinstance(value, baseSizing):
                        value = value.value
                    if hasattr(value, '__iter__') and not isinstance(value, (str, bytes)):
                        value = list(value)
                    config_entry['attributes'][attr] = value
                except (AttributeError, TypeError) as e:
                    warn(f"Warning: Could not save attribute '{attr}' of {class_name}: {type(e)}({str(e)})")

            self.config[identifier] = config_entry
        except Exception as e:
            warn(f"Warning: Could not save config for {class_name}: {type(e)}({str(e)})")
    
    def create_wrapper(self, item_class: type[T], 
                       strong_attributes: Sequence[str] = (), 
                       weak_attributes: Sequence[str] = (),
                       key_attribute: str = "uuid") -> type[T]:
        """
        Create a wrapped version of an item class that auto-saves/loads configuration.
        
        Args:
            item_class: The DearCyGui item class to wrap
            strong_attributes: Attributes with strong persistence - config always wins,
                               even if explicitly provided in __init__
            weak_attributes: Attributes with weak persistence - config only applied
                             if not explicitly provided in __init__
            key_attribute: The attribute used to uniquely identify the item (default "uuid")
        
        Returns:
            A new class that inherits from item_class with config persistence
        """
        strong_attrs_tuple = tuple(strong_attributes)
        weak_attrs_tuple = tuple(weak_attributes)
        class_name = item_class.__name__
        manager = self
        
        class ConfigurableItem(item_class):  # type: ignore
            """
            Auto-generated wrapper class that adds configuration persistence.
            
            This class automatically loads saved configuration values on initialization
            and saves its final configuration when destroyed (__del__/atexit).
            
            Strong attributes: Always restored from config (override init arguments)
            Weak attributes: Only restored if not explicitly provided in init
            """
            __slots__ = ("__self_identifier")
            
            def __init__(self, *args, **kwargs):
                # Create the item first to get its identifier
                super().__init__(*args, **kwargs)

                # Get the unique identifier
                try:
                    self_identifier = str(getattr(self, key_attribute))
                except Exception as e:
                    raise RuntimeError(f"Unable to use {key_attribute} for config management: {type(e)}({str(e)})")

                self.__self_identifier = self_identifier

                # Get saved config based on uuid
                saved_config = manager._get_config(self_identifier, class_name)  # type: ignore

                if saved_config:
                    # Apply strong attributes - these ALWAYS override, even if in kwargs
                    for attr in strong_attrs_tuple:
                        if attr in saved_config:
                            try:
                                setattr(self, attr, saved_config[attr])
                            except Exception as e:
                                warn(f"Warning: Could not restore strong attribute '{attr}' "
                                              f"of {class_name}: {type(e)}({str(e)})")

                    # Apply weak attributes - only if NOT in kwargs
                    for attr in weak_attrs_tuple:
                        if attr in saved_config and attr not in kwargs:
                            try:
                                setattr(self, attr, saved_config[attr])
                            except Exception as e:
                                warn(f"Warning: Could not restore weak attribute '{attr}' "
                                              f"of {class_name}: {type(e)}({str(e)})")

                # On program exit, save before all items are destroyed
                def save_on_exit(ref):
                    obj = ref()
                    if obj is not None:
                        obj.__save_config()
                atexit_register(save_on_exit, weakref(self))
                # We don't use weakref.finalize because the item is never alive anymore when called
                # There is a leak since we do not call unregister. Are save_on_exit function different
                # instances each time (to be able to unregister)?
                # also note: this atexit is registered after the one of the config manager,
                # so the manager atexit is called after the __save_config calls.

            def __save_config(self) -> None:
                """
                Save the item's current configuration.
                
                This captures the final state of the item, including any changes
                made during execution.
                """
                try:
                    try:
                        self_identifier = self.__self_identifier
                    except AttributeError:
                        return # the item didn't succeed __init__
                    # Update the manager's config with this item's final state
                    manager._update_item_config(
                        self_identifier, class_name,
                        strong_attrs_tuple, weak_attrs_tuple, self)
                except Exception as e:
                    warn(f"Warning: Could not save config for {class_name}: {type(e)}({str(e)})")

            def __del__(self) -> None:
                try:
                    atexit_unregister(self.__save_config)
                    self.__save_config()
                except:
                    pass

                # Call parent __del__ if it exists
                parent_del = getattr(super(), '__del__', None)
                if parent_del is not None:
                    parent_del()

        # Set a better name for the wrapper class
        ConfigurableItem.__name__ = f"Configurable{class_name}"
        ConfigurableItem.__qualname__ = f"Configurable{class_name}"
        
        # Copy over docstring and module
        if item_class.__doc__:
            doc_parts = [f"{item_class.__doc__}\n\n"
                        "This is a configuration-enabled version that automatically saves and restores:"]
            if strong_attrs_tuple:
                doc_parts.append(f"  Strong persistence (always override): {', '.join(strong_attrs_tuple)}")
            if weak_attrs_tuple:
                doc_parts.append(f"  Weak persistence (default only): {', '.join(weak_attrs_tuple)}")
            ConfigurableItem.__doc__ = '\n'.join(doc_parts)
        ConfigurableItem.__module__ = item_class.__module__
        
        return ConfigurableItem  # type: ignore


# Global cache of ConfigManager instances by resolved config file path
_config_managers: dict[Path, ConfigManager] = {}


def get_config_manager(config_file: str | Path) -> Callable[..., type]:
    """
    Get or create a configuration manager that returns a wrapper function for adding
    config persistence to DearCyGui item classes.
    
    This is the main entry point for using the configuration system. It returns a
    singleton ConfigManager instance for the given file path, ensuring multiple calls
    with the same path reuse the same manager (avoiding write conflicts).
    
    Args:
        config_file: Path to the JSON file where configuration will be saved/loaded.
                    The file will be created if it doesn't exist. Multiple calls with
                    the same resolved path return the same ConfigManager instance.
    
    Returns:
        A function that takes an item class and attribute names, returning a wrapped
        class with automatic configuration persistence.

    Definition:
        strong attribute: The previous value from the saved config always takes precedence
                          over values passed as parameters during item creation.
        weak attribute: The saved config value is only applied if no value is provided
                        during item creation.
        key attribute: The attribute used to uniquely identify the item instance. "uuid" by default.
                       Note the item is initialized with the parameters passed in the __init__ method
                       before loading any saved config, thus it is possible to pass parameters that
                       will be used for the key attribute.
    
    Example:
        ```python
        import dearcygui as dcg
        from dearcygui.utils.config import get_config_manager
        
        # Get the config manager (or reuse existing one for this path)
        with_config = get_config_manager('my_app_config.json')
        
        # Single parameter - treated as strong attributes
        ConfigWindow = with_config(dcg.Window, ('x', 'y', 'width', 'height'))

        # Using label instead of uuid as key attribute
        ConfigWindow = with_config(dcg.Window, ('x', 'y', 'width', 'height'), key_attribute='label')
        
        # Explicit weak attributes (strong by default)
        ConfigWindow = with_config(dcg.Window, weak_attributes=('x', 'y', 'width', 'height'))
        
        # Strong + weak persistence
        ConfigWindow = with_config(dcg.Window, 
                                   strong_attributes=('x', 'y'),  # Always use saved
                                   weak_attributes=('width', 'height'))  # Only if not specified
        
        # Use them like normal widgets
        C = dcg.Context()
        window = ConfigWindow(C, label="Settings", x=100, y=100)  # x, y ignored if in the saved config (strong)
        
        # In another module, calling get_config_manager with same path
        # returns the same manager instance
        with_config2 = get_config_manager('my_app_config.json')  # Same manager!
        ```
    
    Notes:
        - Multiple calls with the same config file path return the same manager
        - Item state is captured when items are destroyed
        - Configuration is written to file on program exit (via atexit handler)
        - Call manager.close() to explicitly save and stop tracking changes
        - Items are identified by default by their UUID, which is stable across program runs
          as long as items are created in the same order. Since UUIDs are strictly increasing,
          there's no conflict when items are created/destroyed during execution.
        - The class name is stored to prevent loading config from a different item type
        - Strong attributes: Config always wins, even if explicitly provided in init
        - Weak attributes: Config only applied if not explicitly provided in init
        - Non-JSON-serializable values will be converted (e.g., tuples to lists)
    """
    # Resolve the path to handle relative paths and normalize
    resolved_path = Path(config_file).resolve()
    
    # Return existing manager if already created for this path
    if resolved_path in _config_managers:
        manager = _config_managers[resolved_path]
    else:
        # Create new manager and cache it
        manager = ConfigManager(resolved_path)
        _config_managers[resolved_path] = manager
    
    def with_config(item_class: type[T], 
                    strong_attributes: Sequence[str] | None = None, 
                    weak_attributes: Sequence[str] | None = None,
                    key_attribute: str = "uuid") -> type[T]:
        """
        Wrap an item class to add configuration persistence.
        
        Args:
            item_class: The DearCyGui item class to wrap (e.g., dcg.Window)
            strong_attributes: Attributes that always use saved config (override init args).
                             If provided as the only parameter (positional), treated as strong.
            weak_attributes: Attributes that use saved config only if not in init args
        
        Returns:
            A wrapped class that automatically saves and restores the specified attributes
            
        Examples:
            # Single parameter - treated as strong_attributes
            ConfigWindow = with_config(dcg.Window, ('x', 'y', 'width', 'height'))
            
            # Explicit strong attributes
            ConfigWindow = with_config(dcg.Window, strong_attributes=('x', 'y', 'width', 'height'))
            
            # Strong + weak
            ConfigWindow = with_config(dcg.Window, 
                                      strong_attributes=('x', 'y'),
                                      weak_attributes=('width', 'height'))
            
            # Weak only (pass empty tuple for strong)
            ConfigCheckbox = with_config(dcg.Checkbox, 
                                        strong_attributes=(),
                                        weak_attributes=('value',))
        """
        # If only strong_attributes provided (not weak), use it as-is
        # This makes single-parameter calls default to strong persistence
        strong_attrs = strong_attributes if strong_attributes is not None else ()
        weak_attrs = weak_attributes if weak_attributes is not None else ()
        
        return manager.create_wrapper(item_class, strong_attrs, weak_attrs, key_attribute)
    
    # Attach the manager to the function so users can access it
    with_config.manager = manager  # type: ignore
    
    return with_config
