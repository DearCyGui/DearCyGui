#cython: freethreading_compatible=True

# from https://stackoverflow.com/questions/30157363/collapse-multiple-submodules-to-one-cython-extension/52729181#52729181
from sys import meta_path
from importlib.abc import MetaPathFinder
from importlib.machinery import ExtensionFileLoader
from importlib.util import spec_from_loader

# Chooses the right init function     
class CythonPackageMetaPathFinder(MetaPathFinder):
    def __init__(self, name_filter):
        super(CythonPackageMetaPathFinder, self).__init__()
        self.name_filter = name_filter

    def find_spec(self, fullname, path, target=None):
        if fullname.startswith(self.name_filter):
            # use this extension-file but PyInit-function of another module:
            loader = ExtensionFileLoader(fullname, __file__)
            return spec_from_loader(fullname, loader)
    
# injecting custom finder/loaders into sys.meta_path:
def bootstrap_cython_submodules():
    meta_path.append(CythonPackageMetaPathFinder('dearcygui.')) 