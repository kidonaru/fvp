
function(fvp_version)
  if(NOT DEFINED CMAKE_CURRENT_FUNCTION_LIST_DIR)
    message(WARNING "CMAKE_CURRENT_FUNCTION_LIST_DIR not defined")
    set(CMAKE_CURRENT_FUNCTION_LIST_DIR ${CMAKE_CURRENT_LIST_DIR})
  endif()
  set(PUBSPEC_FILE "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../pubspec.yaml")
  if(NOT EXISTS ${PUBSPEC_FILE})
    message(FATAL_ERROR "pubspec.yaml not found: ${PUBSPEC_FILE}")
  endif()
  file(READ ${PUBSPEC_FILE} PUBSPEC_CONTENTS)
  string(REGEX MATCH "version:[ \t]*([0-9]+\\.[0-9]+\\.[0-9]+|[0-9]+\\.[0-9]+|[^ \t\n\r]+)" MATCHED_LINE "${PUBSPEC_CONTENTS}")

  if(MATCHED_LINE)
    string(REGEX REPLACE "version:[ \t]*" "" FVP_VERSION "${MATCHED_LINE}")
    message(STATUS "Found fvp version: ${FVP_VERSION}")
    set(VERSION_HEADER_FILE "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../lib/src/version.h")
    file(WRITE ${VERSION_HEADER_FILE} "#pragma once\n#define FVP_VERSION \"${FVP_VERSION}\"\n")
  else()
    message(WARNING "No version line found in file")
  endif()
endfunction(fvp_version)


macro(fvp_setup_deps)
  fvp_version()
  if(WIN32)
    # v0.37.0 release は vs2026 サフィックス付きの命名のみ提供される
    set(MDK_SDK_PKG mdk-sdk-windows-vs2026.7z)
    if(CMAKE_CXX_COMPILER_ARCHITECTURE_ID MATCHES "[xX]64") # msvc
      set(MDK_SDK_PKG mdk-sdk-windows-x64-vs2026.7z)
    endif()
  elseif(ANDROID)
    set(MDK_SDK_PKG mdk-sdk-android.7z)
  elseif(CMAKE_SYSTEM_NAME MATCHES "OHOS")
    set(MDK_SDK_PKG mdk-sdk-ohos.7z)
  elseif(LINUX OR CMAKE_SYSTEM_NAME MATCHES "Linux")
    set(MDK_SDK_PKG mdk-sdk-linux.tar.xz)
    if(CMAKE_C_COMPILER_ARCHITECTURE_ID MATCHES "[xX].*64")
      set(MDK_SDK_PKG mdk-sdk-linux-x64.tar.xz)
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "[xX].*64" OR CMAKE_SYSTEM_PROCESSOR MATCHES "[aA][mM][dD]64")
      set(MDK_SDK_PKG mdk-sdk-linux-x64.tar.xz)
    endif()
  else()
  endif()
  if("$ENV{FVP_DEPS_URL}" MATCHES "^http") # github release: https://github.com/wang-bin/mdk-sdk/releases/latest/download
    set(FVP_DEPS_URL $ENV{FVP_DEPS_URL}) # TODO: md5
  else()
    # nightly は無固定で 10bit 紫化け等のリグレッションが混入するため、
    # 検証済みの release タグへ固定する（2026-07: nightly b345e19 で実害発生）。
    # Apple 側 (darwin/fvp/Package.swift) の v0.37.0 固定と揃えること。
    set(FVP_DEPS_URL https://github.com/wang-bin/mdk-sdk/releases/download/v0.37.0)
  endif()
  set(MDK_SDK_URL ${FVP_DEPS_URL}/${MDK_SDK_PKG})
  set(MDK_SDK_SAVE "${CMAKE_CURRENT_SOURCE_DIR}/${MDK_SDK_PKG}")

  # 展開済み mdk-sdk がどのパッケージ由来かを記録するマーカー。これが無いと
  # 「FindMDK.cmake の有無」だけでキャッシュ判定してしまい、取得先タグや
  # アーカイブ名を変更しても、別バージョンが展開済みの環境ではダウンロード・
  # 再展開が丸ごとスキップされて古いバイナリを使い続けてしまう
  # （2026-07: nightly 版が残ったまま v0.37.0 固定に切り替わらない事例で判明）。
  set(MDK_SDK_PKG_MARKER "${CMAKE_CURRENT_SOURCE_DIR}/mdk-sdk/.fvp_pkg_name")
  set(MDK_SDK_PKG_STALE ON)
  if(EXISTS ${MDK_SDK_PKG_MARKER})
    file(READ ${MDK_SDK_PKG_MARKER} MDK_SDK_PKG_INSTALLED)
    string(STRIP "${MDK_SDK_PKG_INSTALLED}" MDK_SDK_PKG_INSTALLED)
    if(MDK_SDK_PKG_INSTALLED STREQUAL MDK_SDK_PKG)
      set(MDK_SDK_PKG_STALE OFF)
    endif()
  endif()

  set(DOWNLOAD_MDK_SDK OFF)
  message("FVP_DEPS_LATEST=$ENV{FVP_DEPS_LATEST}")
  # TODO: download from github option FVP_DEPS_LATEST_RELEASE=1
  if($ENV{FVP_DEPS_LATEST})
    if(EXISTS ${MDK_SDK_SAVE})
      message("Downloading latest md5")
      file(DOWNLOAD ${MDK_SDK_URL}.md5 ${MDK_SDK_SAVE}.md5 SHOW_PROGRESS)
      file(READ ${MDK_SDK_SAVE}.md5 MDK_SDK_MD5_LATEST)
      string(STRIP "${MDK_SDK_MD5_LATEST}" MDK_SDK_MD5_LATEST)
      file(MD5 ${MDK_SDK_SAVE} MDK_SDK_MD5_SAVE)
      message("md5 [${MDK_SDK_MD5_SAVE}] => [${MDK_SDK_MD5_LATEST}]")
      if(NOT MDK_SDK_MD5_LATEST STREQUAL MDK_SDK_MD5_SAVE)
        set(DOWNLOAD_MDK_SDK ON)
      endif()
    else()
      set(DOWNLOAD_MDK_SDK ON)
    endif()
  endif()

  if(DOWNLOAD_MDK_SDK OR MDK_SDK_PKG_STALE OR NOT EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/mdk-sdk/lib/cmake/FindMDK.cmake)
    if(DOWNLOAD_MDK_SDK OR MDK_SDK_PKG_STALE OR NOT EXISTS ${MDK_SDK_SAVE})
      message("Downloading mdk-sdk from ${MDK_SDK_URL}")
      file(DOWNLOAD ${MDK_SDK_URL} ${MDK_SDK_SAVE} SHOW_PROGRESS)
      file(MD5 ${MDK_SDK_SAVE} MDK_SDK_MD5_SAVE)
      message("MDK_SDK_MD5_SAVE: ${MDK_SDK_MD5_SAVE}")
    endif()
    # On Flutter Windows, CMAKE_CURRENT_SOURCE_DIR is reached through the
    # generated plugin symlink (.../flutter/ephemeral/.plugin_symlinks/fvp).
    # Newer CMake's `cmake -E tar` extracts with ARCHIVE_EXTRACT_SECURE_SYMLINKS,
    # which refuses to write entries through a symlinked directory
    # ("Cannot extract through symlink"). Resolve the real path so extraction
    # targets a non-symlinked directory. REALPATH (vs file(REAL_PATH)) keeps
    # this compatible with the cmake_minimum_required(3.17) of this plugin.
    get_filename_component(MDK_SDK_EXTRACT_DIR "${CMAKE_CURRENT_SOURCE_DIR}" REALPATH)
    execute_process(
      COMMAND ${CMAKE_COMMAND} -E tar "xvf" "${MDK_SDK_SAVE}" # "--format=7zip"
      WORKING_DIRECTORY "${MDK_SDK_EXTRACT_DIR}"
      OUTPUT_STRIP_TRAILING_WHITESPACE
      RESULT_VARIABLE EXTRACT_RET
    )
    # EXTRACT_RET is 0 even for empty files
    if(NOT EXTRACT_RET EQUAL 0 OR NOT EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/mdk-sdk/lib/cmake/FindMDK.cmake)
      file(REMOVE ${MDK_SDK_SAVE})
      message(FATAL_ERROR "Failed to extract mdk-sdk. You can download manually from ${MDK_SDK_URL} and extract to ${CMAKE_CURRENT_SOURCE_DIR}")
    endif()
    file(WRITE ${MDK_SDK_PKG_MARKER} "${MDK_SDK_PKG}")
  endif()
  include(${CMAKE_CURRENT_SOURCE_DIR}/mdk-sdk/lib/cmake/FindMDK.cmake)
endmacro()
