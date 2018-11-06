#!/usr/bin/env python

import os
import re
import subprocess


def read_patch(patch_dir, patch_filename):
  """Read a patch from |patch_dir/filename| and amend the commit message with
  metadata about the patch file it came from."""
  ret = []
  with open(os.path.join(patch_dir, patch_filename)) as f:
    for l in f.readlines():
      if l.startswith('diff -'):
        ret.append('Patch-Filename: {}\n'.format(patch_filename))
      ret.append(l)
  return ''.join(ret)


def patch_from_dir(patch_dir):
  """Read a directory of patches into a format suitable for passing to
  'git am'"""
  with open(os.path.join(patch_dir, ".patches")) as f:
    patch_list = [l.rstrip('\n') for l in f.readlines()]

  return ''.join([
    read_patch(patch_dir, patch_filename)
    for patch_filename in patch_list
  ])


def format_patch(repo, since):
  args = [
    'git',
    '-C',
    repo,
    'format-patch',
    '--keep-subject',
    '--no-stat',
    '--stdout',

    # Per RFC 3676 the signature is separated from the body by a line with
    # '-- ' on it. If the signature option is omitted the signature defaults
    # to the Git version number.
    '--no-signature',

    # The name of the parent commit object isn't useful information in this
    # context, so zero it out to avoid needless patch-file churn.
    '--zero-commit',

    # Some versions of git print out different numbers of characters in the
    # 'index' line of patches, so pass --full-index to get consistent
    # behaviour.
    '--full-index',
    since
  ]
  return subprocess.check_output(args)


def get_patch_subject(patch_lines):
  for line in patch_lines:
    if line.startswith('Subject: '):
      return line[len('Subject: '):]


def munge_subject_to_filename(subject):
  """Derive a suitable filename from a commit's subject"""
  if subject.endswith('.patch'):
    subject = subject[:-6]
  return re.sub(r'[^A-Za-z0-9-]+', '_', subject).strip('_').lower() + '.patch'
