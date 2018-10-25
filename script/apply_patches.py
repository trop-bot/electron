#!/usr/bin/env python

import argparse

from lib import git
from lib.patches import patch_from_dir


def apply_patches(dirs, threeway=False, committer_name=None,
    committer_email=None):
  for patch_dir, repo in dirs.iteritems():
    git.am(repo=repo, patch_data=patch_from_dir(patch_dir),
           threeway=threeway, committer_name=committer_name,
           committer_email=committer_email)


class ParsePatchDirs(argparse.Action):
  def __call__(self, parser, namespace, values, option_string=None):
    dirs = dict([v.split(':') for v in values])
    setattr(namespace, self.dest, dirs)


def parse_args():
  parser = argparse.ArgumentParser(description='Apply patches')
  parser.add_argument('patch_dirs', nargs='+',
                      action=ParsePatchDirs, help='patch_dir:repo format')
  return parser.parse_args()


def main():
  args = parse_args()
  apply_patches(args.patch_dirs)


if __name__ == '__main__':
  main()
