#!/usr/bin/env python

from apply_patches import apply_patches


patch_dirs = {
  'src/electron/patches/common/chromium':
    'src',

  'src/electron/patches/common/boringssl':
    'src/third_party/boringssl/src',

  'src/electron/patches/common/ffmpeg':
    'src/third_party/ffmpeg',

  'src/electron/patches/common/skia':
    'src/third_party/skia',

  'src/electron/patches/common/v8':
    'src/v8',
}


if __name__ == '__main__':
  apply_patches(patch_dirs,
                committer_name="Electron Scripts",
                committer_email="scripts@electron")
