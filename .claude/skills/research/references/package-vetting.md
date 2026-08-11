# Package Vetting Checklist

Complete this checklist for every installable package before recommending it. Do not skip it for "obviously popular" packages — typosquatting targets popular names specifically.

## Identity verification
- [ ] Package name exactly matches the official documentation and the canonical source repository — character by character
- [ ] The npm/PyPI/crates.io page links back to the expected GitHub/GitLab org (not a fork or impersonator)
- [ ] Confirm the package is published by the expected maintainer/org (check publisher field on npm)

## Health signals
- [ ] Weekly downloads: [record count] — flag if unusually low for a production recommendation
- [ ] Last publish date: [record date] — flag if >6 months for an actively-maintained library
- [ ] Number of maintainers: [record count] — single-maintainer packages carry higher abandonment risk; note this
- [ ] Open issues vs. closed issues ratio: reasonable responsiveness

## Security
- [ ] No known critical or high CVEs — check via [snyk.io/advisor](https://snyk.io/advisor) or `npm audit` / `pip-audit` after install
- [ ] No recent reports of malicious versions (search `<package name> malware` or `<package name> compromised`)
- [ ] License is compatible with this project's license

## Alternatives
- [ ] At least one alternative was seriously evaluated (not just dismissed)
