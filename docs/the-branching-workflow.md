# The Branching Workflow

Only three branches are maintained at any one time; these are `master` the current, and the former Server release series. Any change to the documentation is made in a branch based off of `master` with the exception.
Once the branch's PR is approved and merged, the PR is backported to the branch for the **current** Server release and the **former** release, but only if it applies to it.

When a new ownCloud major or minor version is released, a new branch is created to track the changes for that release, and the branch for the previous release is no longer maintained.
That said, changes for patches and bugfixes to _some_ earlier versions are backported.

[the current ownCloud release]: https://github.com/owncloud/core/wiki/Maintenance-and-Release-Schedule
