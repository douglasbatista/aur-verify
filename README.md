# aur-verify

[![ShellCheck](https://github.com/douglasbatista/aur-verify/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/douglasbatista/aur-verify/actions/workflows/shellcheck.yml)

A heuristic safety check for installed AUR packages, built in response to the
2024/2025 AUR supply-chain incidents (malicious PKGBUILDs, orphan takeovers,
and swapped upstream release binaries).

**What this does NOT do:** prove a PKGBUILD is safe. The AUR has no vetting —
that's the actual threat model. A clean report means "no red flags found by
these checks," not "guaranteed safe." Anything flagged deserves an actual
look; anything not flagged is a judgment call you're choosing to accept
automatically.

## What it checks

**AUR metadata** (one batched RPC call)
- Votes, popularity, orphan status, out-of-date flag, package age.
- **Maintainer changes** since your last run — account takeover and
  adoption-then-poisoning of orphaned packages is a classic AUR vector.

**Full repo scan** (clones the whole AUR git repo, not just PKGBUILD)
- Every file scanned for known malicious-shell patterns, split into two
  tiers: high-confidence (curl\|bash, `/dev/tcp` reverse shells, Discord/
  Telegram webhook exfiltration, shell-rc persistence, `${IFS}` obfuscation)
  marks the package **SUSPICIOUS**; context-dependent (base64 decode,
  `crontab`, setuid chmod, `eval`) marks it **WATCH** with the matching
  line shown so you can judge it yourself.
- Binary blobs committed straight into the AUR repo.
- Suspiciously long base64-like lines (possible obfuscated payloads).
- `SKIP` checksums on packages that aren't VCS (`-git`/`-svn`/`-hg`/`-bzr`).
- New source/URL domains since your last verified run.

**Diff-against-baseline**
- The full repo tree is diffed against your last *verified* run, so you
  only ever look at what changed. A package that comes back **SUSPICIOUS**
  never has its baseline updated — a re-run can't launder a flagged change
  into "no change."
- `aur-verify --diff <pkgbase>` shows exactly what changed.

**Helper cross-check**
- Compares the verified commit against your AUR helper's cached clone
  (`paru`/`yay`), so you know if the helper would actually build something
  other than what you just verified (a TOCTOU gap).

**Upstream artifact checks** — catching a malicious binary behind a
legitimate-looking URL is the hardest part of this problem; these are
the practical, automatable pieces of it:
- **Silent artifact swap**: if `pkgver` and the `source` array are
  unchanged since last run but the checksums differ, the file behind an
  unchanged URL was replaced — flagged **SUSPICIOUS**.
- **GitHub post-release tampering**: for `github.com/.../releases/download/...`
  sources, flags any release asset modified more than a few minutes after
  it was created (the classic post-publish binary swap).
- **Cooling-off window**: warns when the upstream artifact is younger than
  `AUR_VERIFY_COOLOFF_HOURS` (default 48h) — most swapped binaries are
  caught and pulled within a day or two, so simply not being the earliest
  adopter defeats a lot of this class of attack.
- **Homepage/source mismatch**: flags a source domain that matches neither
  the project's homepage nor well-known hosting (GitHub, GitLab,
  SourceForge, PyPI, crates.io, ...), reported once per new domain.

## Install

```sh
git clone https://github.com/douglasbatista/aur-verify.git
cd aur-verify
./install.sh
```

This copies `bin/aur-verify` to `~/.local/bin/aur-verify`. Make sure that
directory is on your `PATH`.

### Dependencies

`bash`, `curl`, `jq`, `git`, `vercmp` (from `pacman-contrib`), `timeout`.

## Usage

```sh
aur-verify                     # check every foreign (AUR) package installed
aur-verify pkg1 pkg2            # check specific packages
aur-verify -u                   # only check packages with an available update
aur-verify --diff <pkgbase>     # show what changed since the last verified run
```

Gate your upgrades on a clean result:

```sh
aur-verify -u && paru -Sua
```

Exit status is `0` if nothing was flagged suspicious, `1` otherwise.

### Environment variables

| Variable                     | Default                | Purpose                                              |
|-------------------------------|-------------------------|-------------------------------------------------------|
| `AUR_VERIFY_CACHE`            | `~/.cache/aur-verify`   | Where baselines and metadata are stored               |
| `AUR_VERIFY_COOLOFF_HOURS`    | `48`                    | Warn on upstream artifacts younger than this          |
| `GITHUB_TOKEN`                | unset                   | Raises the GitHub API rate limit (60/hour without it) |

## Status levels

- **OK** — nothing flagged.
- **WATCH** — a context-dependent pattern, metadata risk signal (low votes,
  orphaned, fresh release, etc.), or an upstream mismatch was found. Worth
  a glance, not necessarily a problem.
- **SUSPICIOUS** — a high-confidence malicious pattern or a silent artifact
  swap was found. Exit code is `1`. Do not upgrade without manually
  reviewing the PKGBUILD and the diff.
- **FETCH FAILED** — the AUR repo couldn't be cloned. Treated as *not
  verified*, never as OK.

## Limitations

This cannot catch a malicious upstream binary hidden behind a URL that has
never changed and was compromised at the source (e.g. a maintainer's build
pipeline or a build server itself). For `-bin` packages of critical
software, your real defenses are: the diff-against-baseline, the new-domain
and swap checks here, and — where it matters enough — building from source
in an isolated environment instead of trusting a prebuilt binary.

## License

MIT — see [LICENSE](LICENSE).
