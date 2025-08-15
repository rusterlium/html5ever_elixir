# Release checklist

In order to release a new version to Hex.pm we first need to:

1. write the changes in the `CHANGELOG.md` file
2. update the `README.md`, `CHANGELOG.md` and `mix.exs` with the new version
3. commit and create a tag for that version
4. push the changes to the repository with: `git push origin master --tags`
5. wait the CI to build all release files
6. run `HTML5EVER_BUILD=1 mix rustler_precompiled.download Html5ever.Native --all --print`
7. copy the output of the mix task and add to the release notes
8. make sure the `target` directory is removed with
   `rm -rf native/html5ever_elixir/target`
9. run `mix hex.publish` and **make sure the checksum file is present**
   in the list of files to be published.
   The checksum file is named `checksum-Elixir.Html5ever.Native.exs`.
10. after releasing, change the mix package version to include a `-dev`
    suffix, so precompilation is ignored for development. You need
    to commit and push this change.

It's important to ensure that we publish the checksum file with the
package because otherwise the users won't be able to use the lib
with precompiled files. They will need to always enforce compilation.
