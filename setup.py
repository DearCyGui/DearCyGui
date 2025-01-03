from setuptools import setup, find_packages, Distribution
from setuptools.command import build_py
from setuptools.extension import Extension
from Cython.Build import cythonize
import distutils.cmd
from codecs import open
import os
from os import path
import sys
from glob import glob
import numpy as np
import shutil
import subprocess

wip_version = "0.0.5"

def version_number():
    return wip_version

def get_platform():
    platforms = {
        'linux': 'Linux',
        'linux1': 'Linux', 
        'linux2': 'Linux',
        'darwin': 'OS X'
    }
    if sys.platform == 'darwin':
        return 'OS X'
    if "win" in sys.platform:
        return "Windows"
    if sys.platform not in platforms:
        return sys.platform
    return platforms[sys.platform]

def build_SDL3():
    src_path = os.path.dirname(os.path.abspath(__file__))
    cmake_config_args = [
        '-DCMAKE_BUILD_TYPE=Release',
        '-DSDL_SHARED=OFF',
        '-DSDL_STATIC=ON',
        '-DSDL_EXAMPLES=OFF',
        '-DSDL_TESTS=OFF',
        '-DSDL_TEST_LIBRARY=OFF',
        '-DSDL_DISABLE_INSTALL=ON',
        '-DSDL_DISABLE_INSTALL_DOCS=ON',
        '-DCMAKE_POSITION_INDEPENDENT_CODE=ON'
    ]
    if get_platform() == "Windows":
        cmake_config_args += ["-DSDL_JOYSTICK=OFF -DSDL_HAPTIC=OFF"] # without fails to compile on github windows
    command = 'cmake -S thirdparty/SDL/ -B build_SDL ' + ' '.join(cmake_config_args)
    subprocess.check_call(command, shell=True)
    command = 'cmake --build build_SDL --config Release'
    subprocess.check_call(command, shell=True)
    if get_platform() == "Windows":
        return os.path.abspath(os.path.join("build_SDL", "Release/SDL3-static.lib"))
    return os.path.abspath(os.path.join("build_SDL", "libSDL3.a"))

def build_FREETYPE():
    src_path = os.path.dirname(os.path.abspath(__file__))
    cmake_config_args = [
        '-DCMAKE_BUILD_TYPE=Release',
        '-DCMAKE_POSITION_INDEPENDENT_CODE=ON',
        '-D FT_DISABLE_ZLIB=TRUE',
        '-D FT_DISABLE_BZIP2=TRUE',
        '-D FT_DISABLE_PNG=TRUE',
        '-D FT_DISABLE_HARFBUZZ=TRUE',
        '-D FT_DISABLE_BROTLI=TRUE'
    ]
    command = 'cmake -S thirdparty/freetype/ -B build_FT ' + ' '.join(cmake_config_args)
    subprocess.check_call(command, shell=True)
    command = 'cmake --build build_FT --config Release'
    subprocess.check_call(command, shell=True)
    if get_platform() == "Windows":
        return os.path.abspath(os.path.join("build_FT", "Release/freetype.lib"))
    return os.path.abspath(os.path.join("build_FT", "libfreetype.a"))

def setup_package():

    src_path = os.path.dirname(os.path.abspath(__file__))
    old_path = os.getcwd()
    os.chdir(src_path)
    sys.path.insert(0, src_path)

    # Build dependencies
    sdl3_lib = build_SDL3()
    FT_lib = build_FREETYPE()

    # import readme content
    with open("./README.md", encoding='utf-8') as f:
        long_description = f.read()

    include_dirs = ["dearcygui",
                    "dearcygui/backends",
                    "thirdparty/imgui",
                    "thirdparty/imgui/backends",
                    "thirdparty/imnodes",
                    "thirdparty/implot",
                    "thirdparty/gl3w",
                    "thirdparty/freetype/include",
                    "thirdparty/SDL/include"]
    include_dirs += [np.get_include()]

    cpp_sources = [
        "dearcygui/backends/sdl3_gl3_backend.cpp",
        "thirdparty/imnodes/imnodes.cpp",
        "thirdparty/implot/implot.cpp",
        "thirdparty/implot/implot_items.cpp",
        "thirdparty/implot/implot_demo.cpp",
        "thirdparty/imgui/misc/cpp/imgui_stdlib.cpp",
        "thirdparty/imgui/imgui.cpp",
        "thirdparty/imgui/imgui_demo.cpp",
        "thirdparty/imgui/imgui_draw.cpp",
        "thirdparty/imgui/imgui_widgets.cpp",
        "thirdparty/imgui/imgui_tables.cpp",
        "dearcygui/backends/imgui_impl_sdl3.cpp",
        "thirdparty/imgui/backends/imgui_impl_opengl3.cpp",
        "thirdparty/imgui/misc/freetype/imgui_freetype.cpp",
        "thirdparty/gl3w/GL/gl3w.cpp"
    ]

    compile_args = ["-D_CRT_SECURE_NO_WARNINGS",
                    "-D_USE_MATH_DEFINES",
                    "-DIMGUI_IMPL_OPENGL_LOADER_SDL3",
                    "-DIMGUI_USER_CONFIG=\"imgui_config.h\""]
    linking_args = ['-O3']

    if get_platform() == "Linux":
        compile_args += ["-DNDEBUG", "-fwrapv", "-O3", "-DUNIX", "-DLINUX", "-g1"]
        libraries = ["crypt", "pthread", "dl", "util", "m", "GL"]
    elif get_platform() == "OS X":
        compile_args += [
            "-fobjc-arc", "-fno-common", "-dynamic", "-DNDEBUG",
            "-fwrapv", "-O3", "-DAPPLE", "-arch", "x86_64", "-std=c++14"
        ]
        libraries = []
        # Link against MacOS frameworks
        linking_args += [
            "-framework", "Cocoa",
            "-framework", "IOKit", 
            "-framework", "CoreFoundation",
            "-framework", "CoreVideo",
            "-framework", "OpenGL",
            "-arch", "x86_64"
        ]
    elif get_platform() == "Windows":
        compile_args += ["/O2", "/DNDEBUG", "/D_WINDOWS", "/D_UNICODE", "/DWIN32_LEAN_AND_MEAN"]
        libraries = ["user32", "gdi32", "shell32", "advapi32", "ole32", "oleaut32", "uuid", "opengl32", \
                     "setupapi", "cfgmgr32", "version", "winmm"]
        linking_args += ["/MACHINE:X64"]
    else:
        # Please test and tell us what changes are needed to the build
        raise ValueError("Unsupported platform")
    cython_sources = [
        "dearcygui/core.pyx",
        "dearcygui/constants.pyx",
        "dearcygui/draw.pyx",
        "dearcygui/font.pyx",
        "dearcygui/handler.pyx",
        "dearcygui/imgui.pyx",
        "dearcygui/imgui_types.pyx",
        "dearcygui/layout.pyx",
        "dearcygui/os.pyx",
        "dearcygui/plot.pyx",
        "dearcygui/theme.pyx",
        "dearcygui/types.pyx",
        "dearcygui/widget.pyx",
    ]

    # We compile in a single extension because we want
    # to link to the same static libraries

    extensions = [
        Extension(
            "dearcygui.dearcygui",
            ["dearcygui/dearcygui.pyx"] + cython_sources + cpp_sources,
            language="c++",
            include_dirs=include_dirs,
            extra_compile_args=compile_args,
            libraries=libraries,
            extra_link_args=linking_args,
            extra_objects=[sdl3_lib, FT_lib]
        )
    ]

    shutil.copy("thirdparty/latin-modern-roman/lmsans17-regular.otf", "dearcygui/")
    shutil.copy("thirdparty/latin-modern-roman/lmromanslant17-regular.otf", "dearcygui/")
    shutil.copy("thirdparty/latin-modern-roman/lmsans10-bold.otf", "dearcygui/")
    shutil.copy("thirdparty/latin-modern-roman/lmromandemi10-oblique.otf", "dearcygui/")


    metadata = dict(
        name='dearcygui',                                      # Required
        version=version_number(),                              # Required
        author="Axel Davy",                                    # Optional
        description='DearCyGui: A simple and customizable Python GUI Toolkit coded in Cython',  # Required
        long_description=long_description,                     # Optional
        long_description_content_type='text/markdown',         # Optional
        url='https://github.com/axeldavy/DearCyGui',          # Optional
        license = 'MIT',
        python_requires='>=3.10',
        classifiers=[
                'Development Status :: 2 - Pre-Alpha',
                'Intended Audience :: Education',
                'Intended Audience :: Developers',
                'Intended Audience :: Science/Research',
                'License :: OSI Approved :: MIT License',
                'Operating System :: MacOS',
                'Operating System :: Microsoft :: Windows :: Windows 10',
                'Operating System :: POSIX',
                'Operating System :: Unix',
                'Programming Language :: Cython',
                'Programming Language :: Python :: 3',
                'Topic :: Software Development :: User Interfaces',
                'Topic :: Software Development :: Libraries :: Python Modules',
            ],
        packages=['dearcygui', 'dearcygui.docs', 'dearcygui.utils', 'dearcygui.backends', 'dearcygui.wrapper'],
        install_requires=[
          'numpy',
          'freetype-py',
          'scipy'
        ],
        ext_modules = cythonize(extensions, compiler_directives={'language_level' : "3"}, nthreads=4)
    )
    metadata["package_data"] = {}
    metadata["package_data"]['dearcygui'] = ['*.pxd', '*.py', '*.pyi', '*ttf', '*otf', '*typed']
    metadata["package_data"]['dearcygui.docs'] = ['*.py', '*.md']
    metadata["package_data"]['dearcygui.utils'] = ['*.pxd', '*.py', '*.pyi', '*ttf', '*otf', '*typed']
    metadata["package_data"]['dearcygui.backends'] = ['*.pxd', '*.py', '*.pyi', '*ttf', '*otf', '*typed']
    metadata["package_data"]['dearcygui.wrapper'] = ['*.pxd', '*.py', '*.pyi', '*ttf', '*otf', '*typed']

    if "--force" in sys.argv:
        sys.argv.remove('--force')

    try:
        setup(**metadata)
    finally:
        del sys.path[0]
        os.chdir(old_path)
    return


if __name__ == '__main__':
    setup_package()
