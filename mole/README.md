# Mole in Paradak

Paradak includes [Mole](https://github.com/tw93/Mole) 1.57.0 by tw93, **unmodified**, in
`Paradak.app/Contents/Resources/mole`, and runs it as a separate program. Mole is licensed under the
[GNU General Public License v3.0 or later](LICENSE); Paradak's own [licence](../LICENSE) does not apply to it
and does not limit your rights under the GPL.

## Corresponding source

- Every [release](https://github.com/abragtim/paradak/releases) attaches `mole-1.57.0-source.tar.gz`:
  the Mole 1.57.0 source with all Go modules of `analyze-go` vendored, plus the build script.
- Upstream: https://github.com/tw93/Mole/tree/V1.57.0
  (tarball `V1.57.0.tar.gz`, sha256 `d5bc2b79c985cd539cbe8b78fd19fec7f8da2083eeaaffdb8d8f52b8565113b4`).
- [`build_mole.sh`](build_mole.sh) shows exactly how the bundled copy was made: the shell scripts and
  `lib/` are copied as they are; `bin/analyze-go` is built from `cmd/analyze` for arm64 and x86_64
  (`CGO_ENABLED=0 go build -trimpath -ldflags "-s -w -X main.Version=1.57.0"`) and joined with
  `lipo`; `status-go` is not included.
- Licences of the Go libraries compiled into `analyze-go`: [THIRD_PARTY_NOTICES.txt](THIRD_PARTY_NOTICES.txt).

"Mole" is a trademark of the Mole project. Paradak is a separate project and is not affiliated with or
endorsed by Mole.
