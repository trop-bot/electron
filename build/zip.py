#!/usr/bin/env python
import os
import subprocess
import sys
import zipfile

EXTENSIONS_TO_SKIP = [
  '.pdb'
]

PATHS_TO_SKIP = [
  'angledata', #Skipping because it is an output of //ui/gl that we don't need
  './libVkLayer_', #Skipping because these are outputs that we don't need
  './VkLayerLayer_', #Skipping because these are outputs that we don't need

  # //chrome/browser:resources depends on this via
  # //chrome/browser/resources/ssl/ssl_error_assistant, but we don't need to
  # ship it.
  'pyproto',
]

def skip_path(dep, dist_zip, target_cpu):
  should_skip = (
    any(dep.startswith(path) for path in PATHS_TO_SKIP) or
    any(dep.endswith(ext) for ext in EXTENSIONS_TO_SKIP) or
    'arm' in target_cpu and dist_zip == 'mksnapshot.zip' and dep == 'snapshot_blob.bin')
  if should_skip:
    print("Skipping {}".format(dep))
  return should_skip

def execute(argv):
  try:
    output = subprocess.check_output(argv, stderr=subprocess.STDOUT)
    return output
  except subprocess.CalledProcessError as e:
    print e.output
    raise e

def main(argv):
  dist_zip, runtime_deps, target_cpu, target_os = argv
  dist_files = set()
  with open(runtime_deps) as f:
    for dep in f.readlines():
      dep = dep.strip()
      dist_files.add(dep)
  if sys.platform == 'darwin':
    execute(['zip', '-r', '-y', dist_zip] + list(dist_files))
  else:
    with zipfile.ZipFile(dist_zip, 'w', zipfile.ZIP_DEFLATED) as z:
      for dep in dist_files:
        if skip_path(dep, dist_zip, target_cpu):
          continue
        if os.path.isdir(dep):
          for root, dirs, files in os.walk(dep):
            for file in files:
              z.write(os.path.join(root, file))
        else:
          z.write(dep)

if __name__ == '__main__':
  sys.exit(main(sys.argv[1:]))
