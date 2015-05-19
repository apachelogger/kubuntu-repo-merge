A script to merge 1 or more origin branches into 1 target branch of all git repositories within a specific subdirectory on git.debian.org.

It gets a list of all repos within a subdirectory (such as applications or frameworks) via SSH. Host access is required because of this. This script works on pristine clones (i.e. it makes new temporary clones) to prevent pushing something that isn't supposed to be pushed yet.

For each repository it then does
- if origin1 exists:
  - if target exists: merge origin
  - else: create target from origin
- else if origin2 exists:
  - ... repeated as above
- else continues until out of origins

Merge errors do abort in a fatal fashion. To resolve the merge go to your regular git clone, do the merge manually, push, run the script again.

The changes the script makes are only pushed after everything has been processed. The user also has to approve the changes and explicitly tell the script to continue with pushing.

To install dependencies run:
```
sudo apt install bundler
bundle install
```

To actually run it use something like this. Remember to change the arguments!
```
bundle exec ./merge.rb -o kubuntu_stable -o kubuntu_vivid_backports -t kubuntu_wily_archive applications
```

Do note that bundle exec isn't absolutely necessary but a good idea to use. It basically ensures that the Ruby environment is exactly what is tested against.
