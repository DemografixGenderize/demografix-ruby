# Releasing

This gem publishes to RubyGems through OIDC Trusted Publishing. The release
workflow (`.github/workflows/release.yml`) runs on a pushed tag matching
`v*.*.*`, verifies the tag matches the gem version, runs the tests, builds the
gem, pushes it to RubyGems, and creates the GitHub Release. No long-lived API
key lives in the repository.

## One-time setup

A maintainer who owns the gem on RubyGems performs these steps once.

### 1. Own the gem name

The gem is `demografix`. Reserve or publish the first version manually so the
name exists and the maintainer account owns it:

```sh
gem build demografix.gemspec
gem push demografix-0.1.0.gem
```

Confirm the gem owner list includes the maintainer account:

```sh
gem owner demografix
```

### 2. Add the Trusted Publisher

On rubygems.org, open the gem page for `demografix`, go to the Trusted
Publishers settings, and add a GitHub Actions publisher with:

- Repository owner: `DemografixGenderize`
- Repository name: `demografix-ruby`
- Workflow filename: `release.yml`
- Environment: `release`

This authorizes the `release` job to publish over OIDC. No secret is stored for
this path.

### 3. Create the `release` environment

In the repository settings under Environments, create an environment named
`release`. The release job references it. Add reviewers or a tag-based
deployment branch rule here if release approval is wanted.

## Cutting a release

1. Bump `Demografix::VERSION` in `lib/demografix/version.rb` to the new
   `X.Y.Z`.
2. Commit the bump:

   ```sh
   git add lib/demografix/version.rb
   git commit -m "Release vX.Y.Z"
   ```

3. Tag the commit. The tag must be `vX.Y.Z` and match the version in the
   manifest, or the workflow fails the guard:

   ```sh
   git tag vX.Y.Z
   ```

4. Push the commit and the tag:

   ```sh
   git push origin main
   git push origin vX.Y.Z
   ```

The release workflow runs the version guard, runs the tests, builds and pushes
the gem, and creates the GitHub Release.

## API-key fallback

If Trusted Publishing is not available, publish with a stored API key instead.

1. On rubygems.org, create an API key scoped to push `demografix`.
2. Add it to the repository as the secret `RUBYGEMS_API_KEY`.
3. Replace the publish step in `.github/workflows/release.yml` with a manual
   build and push, and drop the `id-token: write` permission:

   ```yaml
   - name: Build and push gem
     env:
       GEM_HOST_API_KEY: ${{ secrets.RUBYGEMS_API_KEY }}
     run: |
       gem build demografix.gemspec
       gem push demografix-*.gem
   ```

Trusted Publishing is preferred because it carries no stored credential and
attaches build provenance to the published gem.
