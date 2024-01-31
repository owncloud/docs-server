# Create a New Version Branch

When doing a new release of ownCloud Server like `10.x`, a new version branch must be created based on `master`. It is necessary to do this in steps. Keep in mind that we only process master and the latest two versions. For older versions we only keep the pdf files statically - if possible.

**Step 1: This will create and configure the new `10.x` branch properly**

1.  Go to the settings of this repository and check/change the protection of the branch list so that
    the upcoming `10.x` branch can get pushed.
2.  Create a new `10.x` branch based on latest `origin/master`
3.  Copy the `.drone.star` file from the _former_ `10.x-1` branch
    (it contains the correct branch specific setup rules and replaces the current one coming from master)
4.  In `.drone.star` set `latest_version` to `10.x` (on top in section `def main(ctx)`).
5.  Check in `site.yml` in section `content.sources`: that the following value is set: `- url: .` and in `content.sources.url` the following value is set: `- HEAD`.
6.  In `antora.yml`, set the `version:` key on top to the same as the branch name like `10.x`
7.  In `antora.yml`, in section `asciidoc.attributes`, DO NOT adjust relevant `-version` keys. They are only used for local building.
8.  In `site.yml`, in section `asciidoc.attributes`, DO NOT adjust relevant `-version` keys. They are only used for local building and will be correctly set in the docs repo when doing a full build.
9.  Run a build by entering `yarn antora-local`. No build errors should occur.
10.  Commit the changes and push the new `10.x` branch. This makes the branch available for futher processing. DO NOT CREATE A PR!

**Step 2: This will configure the master branch properly to use the new `10.x` branch**

11. Create new `changes_necessary_for_10.x` branch based on latest `origin/master`.
12. In `.drone.star` set `latest_version` to `10.x` (on top in section `def main(ctx)`).
13. In `antora.yml`, check if the `version:` key is set to `next`.
14. In `site.yml` and in `antora.yml`, DO NOT adjust relevant `-version` keys.
15. Run a build by entering `yarn antora`. No build errors or warnings should occur.
16. Commit changes and push them. (Check the branch protection rules upfront so that the push passes.)
17. Create a Pull Request and see the text suggestion at the bottom. When CI is green, all is done correctly. Merge the PR to master when the 10.x branch is close to be released.

**Step 3: Protection and Renaming**

18. Go to the settings of this repository and change the protection of the branch list so that
    the `10.x` branch gets protected.
19. Unprotect the `10.x-2` branch and rename it to `x_archived_10.x-2`. Note that this step can be postponed if needed. Note that after renaming, local building cant be done anymore.

**Step 4: Changes in the Docs Repo**

20. In `site.yml` of the [docs](https://github.com/owncloud/docs/blob/master/site.yml) repo, adjust all `-version` keys in section `attributes` related to this repo according the new and former releases. Note that the values MUST NOT contain the trailing `@`. (The trailing @ character allows the value to be overwritten like from the corresponding `antora.yml` file which is only necessary for local building the corresponding docs-xxx repo.) Note that merging that PR should be _close before_ publishing the relevant code release.

**Step 5: Set URI `latest` Path Part to 10.x**

21. Nothing needs to be done there. The moment when the new server release gets tagged - which is part of the release process - `latest` will be automatically set to the tagged release number. This works automatically up to version 10.20. After that, backend admins need to be informed to updated the underlying process.

**Text Suggestion for Step 2**

The following text is a copy/paste suggestion for the PR in step 2, replace the branch numbers accordingly:
```
These are the changes necessary to finalize the creation of the 10.x branch.

* The 10.x branch is already pushed and prepared and is included in the branch protection rules.

* When 10.x (core) is finally out, the 10.x-2 branch can be archived, see step 3 in [Create a New Version Branch](https://github.com/owncloud/docs-server/blob/master/docs/new-version-branch.md)

* Note, that the 10.x branch in this repo is already created, but the `latest` pointer on the web will be set to it automatically when the tag in core is set. This means, that in the docs homepage, `latest` will point to 10.x-1 until the tag in core is set accordingly. When merging this PR, 10.x-2 will be dropped from the web.

* Note that this PR must be merged **before** the 10.x tag in core is set to avoid a 404 for `latest`.

* Note before merging this PR, we should take care that 10.x-2 has all necessary changes merged.

@pmaier1 @jnweiger fyi

@mmattel @EParzefall @phil-davis
Post merging this, we need to backport all relevant changes to 10.x
```
