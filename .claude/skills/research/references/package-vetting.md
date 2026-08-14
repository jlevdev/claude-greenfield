# Package Vetting Checklist

Complete this checklist for every installable package before recommending it. Do not skip it for "obviously popular" packages — typosquatting targets popular names specifically.

## Identity verification
- [ ] Package name exactly matches the official documentation and the canonical source repository — character by character
- [ ] The npm/PyPI/crates.io page links back to the expected GitHub/GitLab org (not a fork or impersonator)
- [ ] Confirm the package is published by the expected maintainer/org (check the publisher/owner field on the registry's package page — npm's "Maintainers" list, PyPI's "Maintainers" section, or crates.io's "Owners" tab)

## Health signals
- [ ] Weekly downloads: [record count] — flag if unusually low for a production recommendation
- [ ] Last publish date: [record date] — flag if >6 months for an actively-maintained library
- [ ] Number of maintainers: [record count] — single-maintainer packages carry higher abandonment risk; note this
- [ ] Open issues vs. closed issues ratio: reasonable responsiveness

## Security
- [ ] No known critical or high CVEs — check via an advisory database before installing anything: [snyk.io/advisor](https://snyk.io/advisor), the [GitHub Advisory Database](https://github.com/advisories), or the registry's own vulnerability listing. Research mode doesn't install packages (see the parent skill's "What research mode is not"); a check that requires `npm audit`/`pip-audit`/`cargo audit` output only applies once the package is actually installed during `implement`, not here.
- [ ] No recent reports of malicious versions (search `<package name> malware` or `<package name> compromised`)
- [ ] License is compatible with this project's license

## Alternatives
- [ ] At least one alternative was seriously evaluated (not just dismissed)
