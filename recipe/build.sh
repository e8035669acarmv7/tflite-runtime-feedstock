#!/bin/bash

set -x

export TENSORFLOW_DIR=${SRC_DIR}
export TENSORFLOW_LITE_DIR="${TENSORFLOW_DIR}/tensorflow/lite"
export TENSORFLOW_VERSION=$(grep "_VERSION = " "${TENSORFLOW_DIR}/tensorflow/tools/pip_package/setup.py" | cut -d= -f2 | sed "s/[ '-]//g")
export PACKAGE_VERSION="${TENSORFLOW_VERSION}"
export PROJECT_NAME="tflite_runtime"

BUILD_DIR="${TENSORFLOW_LITE_DIR}/gen/tflite_pip/python3"

PYTHON_INCLUDE=$(${PYTHON} -c "from sysconfig import get_paths as gp; print(gp()['include'])")
PYBIND11_INCLUDE=$(${PYTHON} -c "import pybind11; print (pybind11.get_include())")
NUMPY_INCLUDE=$(${PYTHON} -c "import numpy; print (numpy.get_include())")

rm -rf "${BUILD_DIR}" && mkdir -p "${BUILD_DIR}/tflite_runtime"
cp -r "${TENSORFLOW_LITE_DIR}/tools/pip_package/debian" \
      "${TENSORFLOW_LITE_DIR}/tools/pip_package/MANIFEST.in" \
      "${TENSORFLOW_LITE_DIR}/python/interpreter_wrapper" \
      "${BUILD_DIR}"
cp  "${TENSORFLOW_LITE_DIR}/tools/pip_package/setup_with_binary.py" "${BUILD_DIR}/setup.py"
cp "${TENSORFLOW_LITE_DIR}/python/interpreter.py" \
   "${TENSORFLOW_LITE_DIR}/python/metrics/metrics_interface.py" \
   "${TENSORFLOW_LITE_DIR}/python/metrics/metrics_portable.py" \
   "${BUILD_DIR}/tflite_runtime"
echo "__version__ = '${PACKAGE_VERSION}'" >> "${BUILD_DIR}/tflite_runtime/__init__.py"
# echo "__git_version__ = '$(git -C "${TENSORFLOW_DIR}" describe)'" >> "${BUILD_DIR}/tflite_runtime/__init__.py"

# Build python interpreter_wrapper.
mkdir -p "${BUILD_DIR}/cmake_build"
cd "${BUILD_DIR}/cmake_build"

BUILD_FLAGS=${BUILD_FLAGS:-" -I${PYTHON_INCLUDE} -I${PYBIND11_INCLUDE} -I${NUMPY_INCLUDE}"}

export CFLAGS="${CFLAGS} ${BUILD_FLAGS}"
export CXXFLAGS="${CXXFLAGS} ${BUILD_FLAGS}"

cmake ${CMAKE_ARGS} -G "Ninja"  \
  -D CMAKE_C_COMPILER=${GCC}    \
  -D CMAKE_CXX_COMPILER=${GXX}  \
  "${TENSORFLOW_LITE_DIR}"

cmake --build . --verbose -j ${CPU_COUNT} -t _pywrap_tensorflow_interpreter_wrapper

cd "${BUILD_DIR}"

LIBRARY_EXTENSION=".so"

cp "${BUILD_DIR}/cmake_build/_pywrap_tensorflow_interpreter_wrapper${LIBRARY_EXTENSION}" \
   "${BUILD_DIR}/tflite_runtime"
chmod u+w "${BUILD_DIR}/tflite_runtime/_pywrap_tensorflow_interpreter_wrapper${LIBRARY_EXTENSION}"

cd "${BUILD_DIR}"

$PYTHON -m pip install --no-deps --ignore-installed -v .

