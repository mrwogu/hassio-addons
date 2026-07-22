# Security policy

## Reporting

Do not open public issues for vulnerabilities.

Use GitHub private vulnerability reporting for `mrwogu/hassio-addons`. Include affected add-on version, Home Assistant version, architecture, impact, and reproduction steps.

Report vulnerabilities in Gluetun, Bonds, Stirling-PDF, or authentik directly to their upstream maintainers when the issue is not caused by this packaging.

## Supported versions

Only latest published add-on version receives security updates. Previous versioned images remain available for rollback but are unsupported.

## Scanner exceptions

Trivy exceptions must be scoped to an upstream binary, explain the reason, and expire within 30 days. Repository validation rejects expired or broader exceptions. A fixed upstream release must replace the exception.

## Secrets

Remove VPN credentials, tokens, private keys, cookies, and personal data from logs and attachments before submission.
