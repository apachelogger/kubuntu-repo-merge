A script to merge 1 or more origin branches into 1 target branch of all git repositories within a specific subdirectory on git.debian.org

It gets a list of all repos within a sub directory (such as applications or frameworks) via SSH. Host access is requried because of this.

For each repository it then does the following for each origin:
- if origin1 exists:
  - if target exists: merge origin
  - else: branch origin into target
- else if origin2 exists:
  - ... repeated as above

The changes are only pushed after everything has been processed. The user also has approve the changes and explicitly tell the script to continue with pushing.

```
sudo apt install bundler
bundle install
./merge.rb -o kubuntu_stable -o kubuntu_vivid_backports -t kubuntu_wily_archive applications
```
