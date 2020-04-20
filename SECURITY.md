GoCardless looks forward to working with the security community to find security vulnerabilities in order to keep our businesses and customers safe.

We really appreciate your help in uncovering any security issues and look forward to your findings. If anything is unclear or you have any questions, please reach out to tpm-sl@hackerone.com.

# Response Targets
GoCardless will make a best effort to meet the following response targets for hackers participating in our program:

* Time to first response (from report submit) - 2 business days
* Time to triage (from report submit) - 2 business days
* Time to bounty (from triage) - 10 business days

We’ll try to keep you informed about our progress throughout the process.

# Program Rules
* Social engineering (e.g. phishing, vishing, smishing) is prohibited.
* Follow HackerOne's disclosure guidelines.
* Please provide detailed reports with reproducible steps. If the report is not detailed enough to reproduce the issue, the issue will not be eligible for a reward.
* Submit one vulnerability per report, unless you need to chain vulnerabilities to provide impact.
* Any activity that could lead to the disruption of our service (DoS) is prohibited.
* When duplicates occur, we only award the first report that was received (provided that it can be fully reproduced).
* Multiple vulnerabilities caused by one underlying issue will be awarded one bounty.
* Amounts below are the minimum and maximum bounties we will pay per bug based on severity. We aim to be fair; all reward amounts are at our discretion.

# Scope
All scope is listed below in the structured scope section

# Out of Scope
Third party services are out of scope for this program, even if they are accessible under an in scope URL. This would typically include services such as Zendesk or externally hosted forms.

If you are unsure, please email tpm-sl@hackerone.com

# Out of scope vulnerabilities
When reporting vulnerabilities, please consider (1) attack scenario / exploitability, and (2) security impact of the bug. The following issues are considered out of scope:
* Clickjacking
* Unauthenticated/logout/login CSRF.
* Attacks requiring MITM or physical access to a user's device.
* Previously known vulnerable libraries without a working Proof of Concept.
* Comma Separated Values (CSV) injection without demonstrating a vulnerability.
* Missing best practices in SSL/TLS configuration.
* Missing best practices in Content Security Policy.
* Missing cookie flags
* Email best practices (Invalid, incomplete or missing SPF/DKIM/DMARC records, etc.)
* Vulnerabilities only affecting users of outdated or unpatched browsers and platforms
* Software version disclosure / Banner identification issues / Descriptive error messages or headers (e.g. stack-traces, application or server errors).
* Rate limiting issues that lead to spam.
* Content spoofing and text injection issues without showing an attack vector/without being able to modify HTML/CSS
* CSRF on non-sensitive pages
* CORS headers misconfiguration without demonstrating impact
* Email enumeration

# Safe Harbor
Any activities conducted in a manner consistent with this policy will be considered authorized conduct and we will not initiate legal action against you. If legal action is initiated by a third party against you in connection with activities conducted under this policy, we will take steps to make it known that your actions were conducted in compliance with this policy.

# Test Plan

Where appropriate, hackers can create their own accounts using their HackerOne email alias, by signing up with YOURHANDLE@wearehackerone.com (e.g. hacker123@wearehackerone.com) to use in testing applications/services.

See more here: https://docs.hackerone.com/hackers/hacker-email-alias.html
