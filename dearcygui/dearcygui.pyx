#cython: freethreading_compatible=True

# from https://stackoverflow.com/questions/30157363/collapse-multiple-submodules-to-one-cython-extension/52729181#52729181
import sys
import importlib
import importlib.abc
import importlib.machinery
import importlib.util

# Chooses the right init function     
class CythonPackageMetaPathFinder(importlib.abc.MetaPathFinder):
    def __init__(self, name_filter):
        super(CythonPackageMetaPathFinder, self).__init__()
        self.name_filter = name_filter

    def find_spec(self, fullname, path, target=None):
        if fullname.startswith(self.name_filter):
            # use this extension-file but PyInit-function of another module:
            loader = importlib.machinery.ExtensionFileLoader(fullname, __file__)
            return importlib.util.spec_from_loader(fullname, loader)
    
# injecting custom finder/loaders into sys.meta_path:
def bootstrap_cython_submodules():
    sys.meta_path.append(CythonPackageMetaPathFinder('dearcygui.')) 