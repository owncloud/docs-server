# Create a New Version Branch

When doing a new release of this product documentation, a new version branch must be created based on `master`. It is necessary to do this in steps. Keep in mind that we only process master (version `next`) and the latest two named versions. Patch versions are excluded from this process and can be added in the product repo at any time without further notice. For patch versions, only content changes need to be added if any.

Note that the `latest` version pointer mentioned below is virtual and not part of Antora but created by the webserver and redirects to the latest versioned product automatically.

**Step 1: Update github branch protection rules to allow pushing a new branch**

Enable pushing a new branch.

1.  Go to the github settings of this repository and check/change the protection of the branch list in a way that
    the upcoming `x.y` branch can get pushed.

**Step 2: Create and configure the new `x.y` branch properly**

This step creates the branch locally, necessary for content changes and for the repo building process. 

1.  Create a new `x.y` branch based on latest `origin/master`
1.  In `.drone.star` set `latest_version` to `x.y` (on top in section `def main(ctx)`).
1.  Check in `site.yml` in section `content.sources` that the following value is set: `- url: .` and in `content.sources.url` the following value is set: `- HEAD`.
1.  In `antora.yml`, set the `version:` key on top to the same as the branch name like `x.y`. Each branch must have it's unique version!
1.  In `antora.yml`, in section `asciidoc.attributes`, DO NOT adjust relevant `-version` keys. They are required for local building.
1.  In `site.yml`, in section `asciidoc.attributes`, DO NOT adjust relevant `-version` keys. They are used for local building and will be correctly set in the docs repo when doing a full build. NOTE: any attribute values defined here overwrite any attributes included via the `load-global-site-attributes.js` extension. 
1.  Run a build by entering `npm run antora-local`. No build errors should occur.
1.  Commit the changes and push the new `x.y` branch. This makes the branch available for futher processing. DO NOT CREATE A PR!

**Step 3: Protect the new branch**

The branch has been pushed, add it to the rule set for protected version branches.

1. Go to the github settings of this repository and change the protection of the branch list so that
    the `x.y` branch just pushed before now gets included in the branch protection like the other active branches do.

**Step 4: Configure the master branch to use the new `x.y` branch**

This step is necessary to update the building process for content changes in this repo. 

1. Create a new `changes_necessary_for_x.y` branch based on latest `origin/master`.
1. In `.drone.star` set `latest_version` to `x.y` (on top in section `def main(ctx)`).
1. In `antora.yml`, check if the `version:` key is set to `next`.
1. In `site.yml` and in `antora.yml`, DO NOT adjust relevant `-version` keys.
1. Run a build by entering `npm run antora-local`. No build errors or warnings should occur.
1. Commit changes and push them. (Check the branch protection rules upfront so that the push passes.)
1. Create a Pull Request `Changes necessary for x.y`, see the [text suggestion](#text-suggestion-for-step-4) below. When CI is green, all is done correctly, merge the PR when approved. This merge does NOT add the version to the main building process. You can now add at any time content changes to this version.

**Step 5: Changes in the docs repo (main assembling repo)**

This step finally sets the versions (branches) to be built. The new x.y version branch will be added and the oldest branch of the product will be removed from building. Note that after merging the PR, the new version is live and the former version is removed. You should therefore merge _close before_ publishing the relevant product release. If this step is omitted or not timed well, the `latest` pointer from the webserver, which generates the redirect based on the latest tag of the product repo automatically, will generate a 404 instead pointing to the latest release!

1. In the [docs](https://github.com/owncloud/docs/blob/master/site.yml) repo, create a new `enable_<product>_x.y` branch based on latest `origin/master`, where `<product>` is the placeholder for the product this version is added for like `ocis`, or `desktop` etc.
1. In file `site.yml`, adjust the versions of the respective content source to the correct versions. Add the new one and remove the oldest one.
1. In file `global-attributes.yml` adjust all `-version` keys related to this repo according the new and former releases. Note that the values MUST NOT contain the trailing `@`. (The trailing @ character allows the value to be overwritten like from the corresponding `antora.yml` file which is only necessary for local building the corresponding docs-xxx repo.)
1. In file `global-attributes.yml` adjust all attributes that need an update relevant for that branch like compile timestamp etc.
1. Create a Pull Request `Enable <product> x.y`, see the [text suggestion](#text-suggestion-for-step-5) below.

**Step 6: Archive the dropped branch**

This step _mandatory_ needs the doc PR described before to be merged!

1. Unprotect the `x.z` branch which was dropped from the building process and rename it to `x_archived_x.z`. There are already branch protection rules for archived versions in place. Note that this step can be postponed if needed but it must not be processed before merging x.y in docs. Note that after renaming, also local building cant be done anymore without extra efforts - which is on purpose.

## **Text Suggestion for Step 4**

The following text is a copy/paste suggestion for the PR, replace the branch numbers accordingly:

```
These are the changes necessary to finalize the creation of the x.y branch.

* The x.y branch is already pushed, prepared and is included in the branch protection rules.

* Note that this PR can be merged at any time but:
  * must be merged **before** applying content changes and
  * **before** merging the docs PR to include this version.

* Post merging this, we need to backport all relevant changes created in master to x.y

@mmattel @phil-davis
```

## **Text Suggestion for Step 5**

The following text is a copy/paste suggestion for the PR, replace the branch numbers accordingly:

```
Referencing: https://github.com/owncloud/docs-xxx/pull/yyy (Changes necessary for x.y)

This PR enables the documentation for <product> x.y and drops version x.z

Currently on draft to avoid accidentally merging before x.y is finally out.

Only merge close before the product tag gets released.

When this PR is merged, the dropped branch can be archived.
For more details see the `Create a New Version Branch` section in the README.md of the respective docs-xxx repo repo.

The `latest` pointer on the web will be set automatically when the tag in the product repo is set.

Tested, a local build runs fine.

@mmattel @phil-davis
```
