An example workflow
===================

(For community developer)

0. Prepare
    $ git config --global user.name "Your Name"
    $ git config --global user.email your@email

1. Git clone from SmartQ kernel git repo;

2. Hack on a brand new kernel (eg: upgrade from 2.6.29 to 2.6.30):

    $ cd patches/(smartqv|s3c)
    $ cp -R linux-2.6.29 linux-2.6.30
    $ cd ../../tmp
    $ tar -jxvf ~/Downloads/linux-2.6.30.tar.bz2
    $ cd linux-2.6.30
    $ ln -s ../../patches/(smartqv|s3c)/linux-2.6.30 patches
    $ ln -s ../../patches/(smartqv|s3c)/linux-2.6.30/series series
    $ quilt push -a (until a patch fails)
    $ //hack on files to fix patch
    $ //make sure kernel compiles
    $ quilt refresh  //updates the patch

    (This is optional, since it will be forced when you attempt to git check in)
    $ ./scripts/check_patch fix-foo-and-bar.patch

3. Now you have the patch fix-foo-and-bar.patch, please test-compile the
   kernel.  Just because a patch applies to the sources doesn't mean it
   will produce a working kernel.

