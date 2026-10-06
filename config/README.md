# pCP/N1 configuration notes

v0.3.1 does not pass a small fragment through `kernel_config`.

ophub documents `kernel_config` as a path containing complete, versioned
configuration templates such as `config-6.12`. A fragment is therefore not
used here.

The workflow selects `config_flavor: stable`, which uses ophub/kernel's
maintained 6.12 configuration template. pCP-specific changes will only be
introduced later after validating the generated `.config` against the
actual pCP 11.1.0 requirements.
