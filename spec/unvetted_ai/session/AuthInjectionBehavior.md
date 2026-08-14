<!--[>] 🤖🤖 -->
Feature: Session auth injection

Scenario: a session gets its full identity while only one secret ever crosses the host boundary
  Status: todo
  Given the host reads only the sandbox SA key from `op://SandboxProgrammaticAccess/sandbox-gcp-sa/keys/sa_key`
  When `session-create` (or `session-attach`) execs into the pod
  Then only `GCP_SA_KEY` rides the exec and becomes the pod's ADC
  And no ssh key, gitlab token, or op credential is read on the host or passed in

Scenario: the pod bootstraps its working identity itself, so a host compromise leaks nothing extra
  Status: todo
  Given the pod holds ADC from the injected SA key
  When the sandbox-runtime profile runs at creation
  Then the gitlab token and both ssh keypairs are fetched in-pod from GCP Secrets Manager via that ADC
  And in-pod glab auth resolves the token from `$GITLAB_TOKEN_SECRET_PATH` (gcp://) on first use

Scenario: a session never starts half-authenticated
  Status: todo
  Given the SA key is absent from op and `GCP_SA_KEY` is unset
  When `session-create` or `session-attach` runs
  Then it exits non-zero naming the missing op path before any exec into the pod
<!--[<] 🤖🤖 -->
