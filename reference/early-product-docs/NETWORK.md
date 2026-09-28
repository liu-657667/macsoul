# Network Feature Specification

## Goals
Give a developer a quick, truthful answer to:
- what is my current public IP?
- is a proxy configured?
- do I appear to have a tunnel/VPN interface?
- can I reach the services I use?

This is not a security scanner or fingerprinting product.

## Providers
Keep public-IP and metadata lookup behind interfaces so endpoints can be replaced.

Suggested separation:
- `PublicIPProvider` — IPv4/IPv6 only
- `IPMetadataProvider` — optional country/region/ASN/ISP enrichment
- `ProxyInspector` — local configuration only
- `ConnectivityProbe` — HTTP/TCP reachability timing

Do not send local process/path data to IP providers.

## Public IP behavior
- Cache successful result.
- Refresh on app start, network-path change, manual refresh, and approximately every 5 minutes.
- A provider error keeps the last-known value visibly marked stale.
- Consider provider fallback only when it does not create excessive third-party requests.

## Proxy inspection
Represent sources separately:
- environment proxy
- macOS system proxy
- tunnel interfaces

Example:
```text
Shell HTTPS proxy: 127.0.0.1:7890
System HTTPS proxy: On · 127.0.0.1:7890
Tunnel: utun3 detected
```

Do not label `utun3` as a specific VPN brand without reliable evidence.

## Connectivity
Probe targets should be configurable constants and lightweight.
Display `Healthy`, `Slow`, or `Timeout` as probe observations only.
Do not infer a global outage from one local timeout.

## Privacy
Network-history persistence is off by default. Current public IP can be displayed without saving history.
