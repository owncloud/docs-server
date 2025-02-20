# The Branching Workflow

Only three branches are maintained for this repo at any one time; these are `master` which is referenced with `next` on the web, the current, and the former product release, but only for major and minor versions. Any change to the documentation is made in a branch based off of `master` with only a view exceptions.

Any documentation changes for a version is created in master and backported to the version it applies to. This keeps the content consistent.

When a new major or minor version is released, a new branch is created to track the changes for that release, and the branch for the previous release is technically no longer maintained. That said, changes for patches and bugfixes to _some_ earlier versions are backported if reasonable.
