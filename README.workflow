An example workflow
===================

(For community developer)

0. Prepare
    $ git config --global user.name "Your Name"
    $ git config --global user.email your@email
    $ gpg --keyserver wwwkeys.pgp.net --recv-keys 0x517D0F0E

1. Git clone from SmartQ kernel git repo;

2. Cook the patch, using quilt:
    $ ./scripts/install-git-hooks
    $ ./scripts/sequence-patch.sh --quilt
    $ cd tmp/linux-$version-$branch
    $ quilt new fix-foo-and-bar.patch
    $ quilt edit some/file.c
    $ ./refresh_patch.sh
    $ quilt header -e

    (This is optional, since it will be forced when you attempt to git check in)
    $ ./scripts/check_patch fix-foo-and-bar.patch

3. Now you have the patch fix-foo-and-bar.patch, please test-compile the
   kernel or even test-build the kernel package through OBS. (Follow "Before
   You Commit -- Things To Check" section in README to test-compile; use
   script obs_build.sh to test-build kernel rpm package through OBS.)


